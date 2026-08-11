import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_screen.dart';
import 'main_screen.dart';

/// Shows splash while restoring Cognito session, then Login or Main.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, auth, _) {
        if (auth.isBootstrapping) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MyTEDx',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(color: AppTheme.tedRed),
                ],
              ),
            ),
          );
        }

        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

        return const MainScreen();
      },
    );
  }
}
