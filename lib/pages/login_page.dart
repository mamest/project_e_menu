import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await _authService.signInWithGoogle();

      // On web, the user will be redirected, so we won't reach here
      // On mobile, we check the success status
      if (!kIsWeb) {
        if (success) {
          // Successfully signed in
          if (mounted) {
            Navigator.of(context).pop(true); // Return true to indicate success
          }
        } else {
          // User canceled the sign-in
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = AppLocalizations.of(context)!.signInFailed(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF7C3AED),
        foregroundColor: Colors.white,
        flexibleSpace: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Text(
                      l10n.signIn,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Icon/Logo
              Icon(
                Icons.restaurant_menu,
                size: 80,
                color: const Color(0xFF7C3AED),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                l10n.welcomeTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5B21B6),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                l10n.signInSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Google Sign-In Button
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _handleGoogleSignIn,
                  icon: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.g_mobiledata,
                      size: 32,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  label: Text(
                    l10n.signInWithGoogle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Error message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[800]),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 32),

              // Continue without sign-in option
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  l10n.continueWithoutSignIn,
                  style: const TextStyle(
                    color: Colors.grey,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Info text
              Text(
                kIsWeb ? l10n.signInNoteWeb : l10n.signInNoteMobile,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
