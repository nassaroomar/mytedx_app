import 'dart:convert';

import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/cognito_config.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.idToken,
    this.refreshToken,
    this.accessTokenExpiration,
    this.email,
    this.sub,
  });

  final String accessToken;
  final String idToken;
  final String? refreshToken;
  final DateTime? accessTokenExpiration;
  final String? email;
  final String? sub;

  bool get isExpired {
    final exp = accessTokenExpiration;
    if (exp != null) {
      return DateTime.now().isAfter(exp.subtract(const Duration(minutes: 1)));
    }
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return false;
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['exp'] != null) {
        final seconds = int.tryParse(decoded['exp'].toString());
        if (seconds == null) return false;
        final idExp = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        return DateTime.now()
            .isAfter(idExp.subtract(const Duration(minutes: 1)));
      }
    } catch (_) {}
    return false;
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'idToken': idToken,
        'refreshToken': refreshToken,
        'accessTokenExpiration': accessTokenExpiration?.toIso8601String(),
        'email': email,
        'sub': sub,
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken']?.toString() ?? '',
      idToken: json['idToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString(),
      accessTokenExpiration: DateTime.tryParse(
        json['accessTokenExpiration']?.toString() ?? '',
      ),
      email: json['email']?.toString(),
      sub: json['sub']?.toString(),
    );
  }
}

class UserNotConfirmedAuthException implements Exception {
  UserNotConfirmedAuthException(this.email);
  final String email;

  @override
  String toString() => 'UserNotConfirmedAuthException($email)';
}

/// Native Cognito email/password auth (no browser / Hosted UI).
class AuthService {
  AuthService({
    CognitoUserPool? userPool,
    FlutterSecureStorage? secureStorage,
  })  : _userPool = userPool ??
            CognitoUserPool(
              CognitoConfig.userPoolId,
              CognitoConfig.clientId,
            ),
        _storage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _sessionKey = 'cognito_auth_session_v1';

  final CognitoUserPool _userPool;
  final FlutterSecureStorage _storage;
  AuthSession? _cachedSession;
  CognitoUser? _cognitoUser;

  AuthSession? get currentSession => _cachedSession;

  Future<AuthSession?> restoreSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      _cachedSession = null;
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      var session =
          AuthSession.fromJson(Map<String, dynamic>.from(decoded));
      if (session.accessToken.isEmpty || session.idToken.isEmpty) {
        _cachedSession = null;
        return null;
      }
      if (session.isExpired &&
          session.refreshToken != null &&
          session.refreshToken!.isNotEmpty) {
        session = await refreshSession(session) ?? session;
        if (session.isExpired) {
          await clearLocalSession();
          return null;
        }
      }
      _cachedSession = session;
      return session;
    } catch (_) {
      _cachedSession = null;
      return null;
    }
  }

  Future<String?> getApiAuthorizationToken({bool useAccessToken = false}) async {
    var session = _cachedSession;
    session ??= await restoreSession();
    if (session == null) return null;

    if (session.isExpired &&
        session.refreshToken != null &&
        session.refreshToken!.isNotEmpty) {
      session = await refreshSession(session) ?? session;
    }

    if (useAccessToken) {
      return session.accessToken.isEmpty ? null : session.accessToken;
    }
    if (session.idToken.isEmpty) return null;
    return session.idToken;
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final username = email.trim();
    _cognitoUser = CognitoUser(username, _userPool);
    final details = AuthenticationDetails(
      username: username,
      password: password,
    );

    try {
      final cognitoSession = await _cognitoUser!.authenticateUser(details);
      if (cognitoSession == null || !cognitoSession.isValid()) {
        throw Exception('Sign-in failed. Invalid session.');
      }
      final session = _sessionFromCognito(cognitoSession, fallbackEmail: username);
      await _persist(session);
      return session;
    } on CognitoClientException catch (error) {
      if (error.code == 'UserNotConfirmedException') {
        throw UserNotConfirmedAuthException(username);
      }
      rethrow;
    }
  }

  /// Returns true when Cognito already confirmed the user (no code needed).
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    final username = email.trim();
    final result = await _userPool.signUp(
      username,
      password,
      userAttributes: [
        AttributeArg(name: 'email', value: username),
      ],
    );
    return result.userConfirmed ?? false;
  }

  Future<void> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    final username = email.trim();
    final user = CognitoUser(username, _userPool);
    final ok = await user.confirmRegistration(confirmationCode.trim());
    if (!ok) {
      throw Exception('Confirmation failed. Check the code and try again.');
    }
  }

  Future<void> resendConfirmationCode(String email) async {
    final user = CognitoUser(email.trim(), _userPool);
    await user.resendConfirmationCode();
  }

  Future<AuthSession?> refreshSession(AuthSession current) async {
    final refresh = current.refreshToken;
    if (refresh == null || refresh.isEmpty) return current;

    try {
      final username = (current.email ?? current.sub ?? '').trim();
      if (username.isEmpty) return current;

      _cognitoUser ??= CognitoUser(username, _userPool);
      final cognitoSession = await _cognitoUser!.refreshSession(
        CognitoRefreshToken(refresh),
      );
      if (cognitoSession == null || !cognitoSession.isValid()) {
        return current;
      }
      final session = _sessionFromCognito(
        cognitoSession,
        fallbackEmail: current.email,
        fallbackRefreshToken: refresh,
        fallbackSub: current.sub,
      );
      await _persist(session);
      return session;
    } catch (_) {
      _cachedSession = current;
      return current;
    }
  }

  /// Local sign-out only — no Cognito Hosted UI / browser.
  Future<void> signOut({String? idTokenHint}) async {
    try {
      await _cognitoUser?.signOut();
    } catch (_) {
      // Ignore remote/local Cognito errors; clear app session anyway.
    } finally {
      _cognitoUser = null;
      await clearLocalSession();
    }
  }

  Future<void> clearLocalSession() async {
    _cachedSession = null;
    await _storage.delete(key: _sessionKey);
  }

  AuthSession _sessionFromCognito(
    CognitoUserSession cognitoSession, {
    String? fallbackEmail,
    String? fallbackRefreshToken,
    String? fallbackSub,
  }) {
    final access = cognitoSession.getAccessToken().getJwtToken() ?? '';
    final idToken = cognitoSession.getIdToken().getJwtToken() ?? '';
    if (access.isEmpty || idToken.isEmpty) {
      throw Exception('Cognito did not return access/id tokens.');
    }

    final claims = _decodeJwtPayload(idToken);
    final expSeconds = cognitoSession.getAccessToken().getExpiration();
    final accessExp =
        DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);

    return AuthSession(
      accessToken: access,
      idToken: idToken,
      refreshToken:
          cognitoSession.getRefreshToken()?.getToken() ?? fallbackRefreshToken,
      accessTokenExpiration: accessExp,
      email: claims['email']?.toString() ?? fallbackEmail,
      sub: claims['sub']?.toString() ?? fallbackSub,
    );
  }

  Map<String, dynamic> _decodeJwtPayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return {};
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  Future<void> _persist(AuthSession session) async {
    _cachedSession = session;
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }
}
