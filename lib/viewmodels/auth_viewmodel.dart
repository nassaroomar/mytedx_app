import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

enum AuthFormMode { signIn, signUp, confirm }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthService? authService})
      : _auth = authService ?? AuthService();

  final AuthService _auth;

  AuthSession? _session;
  bool _bootstrapping = true;
  bool _busy = false;
  String? _errorMessage;
  String? _infoMessage;
  AuthFormMode _mode = AuthFormMode.signIn;
  String _pendingEmail = '';

  AuthSession? get session => _session;
  bool get isAuthenticated => _session != null;
  bool get isBootstrapping => _bootstrapping;
  bool get isBusy => _busy;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  String? get email => _session?.email;
  AuthFormMode get mode => _mode;
  String get pendingEmail => _pendingEmail;

  Future<void> bootstrap() async {
    _bootstrapping = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _session = await _auth.restoreSession();
    } catch (_) {
      _session = null;
    } finally {
      _bootstrapping = false;
      notifyListeners();
    }
  }

  void setMode(AuthFormMode mode, {String? email}) {
    _mode = mode;
    if (email != null) _pendingEmail = email.trim();
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (_busy) return false;
    _busy = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
    try {
      _session = await _auth.signIn(email: email, password: password);
      _mode = AuthFormMode.signIn;
      return true;
    } on UserNotConfirmedAuthException catch (error) {
      _pendingEmail = error.email;
      _mode = AuthFormMode.confirm;
      _infoMessage = 'Confirm your email with the code we sent you.';
      return false;
    } catch (error) {
      _errorMessage = _readableError(error);
      debugPrint('Cognito sign-in error: $error');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    if (_busy) return false;
    _busy = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
    try {
      final alreadyConfirmed = await _auth.signUp(
        email: email,
        password: password,
      );
      _pendingEmail = email.trim();
      if (alreadyConfirmed) {
        _mode = AuthFormMode.signIn;
        _infoMessage = 'Account created. You can sign in now.';
        return false;
      }
      _mode = AuthFormMode.confirm;
      _infoMessage = 'We sent a confirmation code to your email.';
      return false;
    } catch (error) {
      _errorMessage = _readableError(error);
      debugPrint('Cognito sign-up error: $error');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> confirmSignUp({
    required String email,
    required String code,
    String? password,
  }) async {
    if (_busy) return false;
    _busy = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
    try {
      await _auth.confirmSignUp(email: email, confirmationCode: code);
      if (password != null && password.isNotEmpty) {
        _session = await _auth.signIn(email: email, password: password);
        _mode = AuthFormMode.signIn;
        return true;
      }
      _mode = AuthFormMode.signIn;
      _infoMessage = 'Email confirmed. Please sign in.';
      return false;
    } catch (error) {
      _errorMessage = _readableError(error);
      debugPrint('Cognito confirm error: $error');
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> resendCode(String email) async {
    if (_busy) return;
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _auth.resendConfirmationCode(email);
      _infoMessage = 'A new confirmation code was sent.';
    } catch (error) {
      _errorMessage = _readableError(error);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await _auth.signOut();
      _session = null;
      _errorMessage = null;
      _infoMessage = null;
      _mode = AuthFormMode.signIn;
    } catch (error) {
      await _auth.clearLocalSession();
      _session = null;
      debugPrint('Cognito sign-out error: $error');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    if (_errorMessage == null && _infoMessage == null) return;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  String _readableError(Object error) {
    if (error is CognitoClientException) {
      final message = error.message?.trim();
      switch (error.code) {
        case 'NotAuthorizedException':
          return 'Incorrect email or password.';
        case 'UserNotFoundException':
          return 'No account found for this email.';
        case 'UsernameExistsException':
          return 'An account with this email already exists.';
        case 'InvalidPasswordException':
          return 'Password does not meet Cognito requirements.';
        case 'InvalidParameterException':
          return 'Please check your email and password.';
        case 'CodeMismatchException':
          return 'Invalid confirmation code.';
        case 'ExpiredCodeException':
          return 'Confirmation code expired. Request a new one.';
        case 'LimitExceededException':
          return 'Too many attempts. Please try again later.';
        default:
          if (message != null && message.isNotEmpty) return message;
      }
    }
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Network')) {
      return 'Network error. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}
