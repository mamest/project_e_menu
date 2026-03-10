import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { customer, restaurantOwner }

class AuthService {
  // ── Singleton ─────────────────────────────────────────────
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal() {
    if (!kIsWeb) {
      _initializeGoogleSignIn();
    }
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  GoogleSignIn? _googleSignIn;

  // ── Profile cache ─────────────────────────────────────────
  UserRole? _cachedRole;
  String? _cachedSubscriptionStatus;
  DateTime? _cachedSubscriptionEnd;

  // ── Role & subscription getters ───────────────────────────
  UserRole get userRole => _cachedRole ?? UserRole.customer;
  bool get isRestaurantOwner => userRole == UserRole.restaurantOwner;

  /// True only when the user is a restaurant_owner with an active/trialing sub.
  bool get isSubscriptionActive {
    if (!isRestaurantOwner) return false;
    return _cachedSubscriptionStatus == 'active' ||
        _cachedSubscriptionStatus == 'trialing';
  }

  String? get subscriptionStatus => _cachedSubscriptionStatus;
  DateTime? get subscriptionEnd => _cachedSubscriptionEnd;

  // ── Profile loading ───────────────────────────────────────

  /// Fetches the profile row for the current user and caches role/subscription.
  Future<void> loadProfile() async {
    final user = currentUser;
    if (user == null) {
      _clearProfile();
      return;
    }
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        final roleStr = response['role'] as String? ?? 'customer';
        _cachedRole = roleStr == 'restaurant_owner'
            ? UserRole.restaurantOwner
            : UserRole.customer;
        _cachedSubscriptionStatus =
            response['subscription_status'] as String?;
        final endStr =
            response['subscription_current_period_end'] as String?;
        _cachedSubscriptionEnd =
            endStr != null ? DateTime.tryParse(endStr) : null;
      } else {
        await _upsertProfile(user.id);
      }
    } catch (e) {
      debugPrint('AuthService.loadProfile error: $e');
    }
  }

  Future<void> _upsertProfile(String userId) async {
    try {
      await _supabase.from('profiles').upsert({'id': userId, 'role': 'customer'});
      _cachedRole = UserRole.customer;
    } catch (e) {
      debugPrint('AuthService._upsertProfile error: $e');
    }
  }

  /// Upgrades the current user's role to restaurant_owner.
  Future<void> upgradeToRestaurantOwner() async {
    final user = currentUser;
    if (user == null) return;
    await _supabase
        .from('profiles')
        .update({'role': 'restaurant_owner', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', user.id);
    _cachedRole = UserRole.restaurantOwner;
  }

  /// Demo helper – activates a 30-day subscription without Stripe.
  Future<void> activateDemoSubscription() async {
    final user = currentUser;
    if (user == null) return;
    final end = DateTime.now().add(const Duration(days: 30));
    await _supabase.from('profiles').update({
      'role': 'restaurant_owner',
      'subscription_status': 'active',
      'subscription_current_period_end': end.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
    _cachedRole = UserRole.restaurantOwner;
    _cachedSubscriptionStatus = 'active';
    _cachedSubscriptionEnd = end;
  }

  void _clearProfile() {
    _cachedRole = null;
    _cachedSubscriptionStatus = null;
    _cachedSubscriptionEnd = null;
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

  // ── Auth getters ──────────────────────────────────────────
  User? get currentUser => _supabase.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
  String? get userEmail => currentUser?.email;
  String? get userName => currentUser?.userMetadata?['full_name'];
  String? get userAvatarUrl => currentUser?.userMetadata?['avatar_url'];

  // ── Auth actions ──────────────────────────────────────────
  Future<bool> signInWithGoogle() async {
    try {
      // For web, use Supabase's native OAuth (redirect flow)
      if (kIsWeb) {
        // Use only the origin (scheme + host + port) so the redirect URL
        // matches exactly what is registered in Supabase's allowlist,
        // regardless of any current path or hash fragment.
        final redirectTo = Uri.base.origin;
        await _supabase.auth.signInWithOAuth(
          Provider.google,
          redirectTo: redirectTo,
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

      final response = await _supabase.auth.signInWithIdToken(
        provider: Provider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user != null) {
        await loadProfile();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _clearProfile();
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }
}
