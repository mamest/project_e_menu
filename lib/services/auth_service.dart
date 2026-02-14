import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  GoogleSignIn? _googleSignIn;

  AuthService() {
    if (!kIsWeb) {
      _initializeGoogleSignIn();
    }
  }

  void _initializeGoogleSignIn() {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];

    if (webClientId != null && webClientId.isNotEmpty) {
      // For web, don't use serverClientId (not supported)
      _googleSignIn = GoogleSignIn(
        clientId: webClientId,
      );
    } else if (iosClientId != null && iosClientId.isNotEmpty) {
      _googleSignIn = GoogleSignIn(
        clientId: iosClientId,
      );
    } else {
      _googleSignIn = GoogleSignIn();
    }
  }

  /// Get the current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Get auth state stream
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      // For web, use Supabase's native OAuth (redirect flow)
      if (kIsWeb) {
        await _supabase.auth.signInWithOAuth(
          Provider.google,
          redirectTo: kIsWeb ? Uri.base.toString() : null,
        );
        // On web, this will redirect, so we return true
        return true;
      }

      // For mobile, use the google_sign_in package
      if (_googleSignIn == null) {
        throw Exception('Google Sign-In not properly configured');
      }

      // Start the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return false;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        throw Exception('Failed to get Google credentials');
      }

      // Sign in to Supabase with the Google credentials
      final response = await _supabase.auth.signInWithIdToken(
        provider: Provider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return response.user != null;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from Google
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      // Sign out from Supabase
      await _supabase.auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  /// Get user profile data
  String? get userEmail => currentUser?.email;
  String? get userName => currentUser?.userMetadata?['full_name'];
  String? get userAvatarUrl => currentUser?.userMetadata?['avatar_url'];
}
