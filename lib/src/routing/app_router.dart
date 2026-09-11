import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/dashboard/presentation/home_screen.dart';

/// Bridges [authProvider] to go_router's `refreshListenable` so GoRouter
/// re-evaluates `redirect` whenever auth state changes, without making
/// `routerProvider` itself depend on (and rebuild from) `authProvider`.
///
/// The previous version did `ref.watch(authProvider)` in the provider body
/// and `ref.read(authProvider)` inside the `redirect` closure. That closure
/// is captured once and can fire again later (GoRouter invokes it
/// asynchronously on navigation), so if `authProvider` changed a second
/// time in between, the closure's `ref` pointed at a `routerProvider`
/// element already mid-invalidation -- reading through it then hits
/// Riverpod's "Cannot use ref functions after the dependency of a provider
/// changed but before the provider rebuilt" assertion. Reading the cached
/// `user` field below instead means `redirect` never touches `ref` at all,
/// so a stale closure can't observe an inconsistent provider state.
class _AuthRefreshNotifier extends ChangeNotifier {
  UserProfile? user;

  _AuthRefreshNotifier(Ref ref) {
    user = ref.read(authProvider);
    ref.listen<UserProfile?>(authProvider, (previous, next) {
      user = next;
      notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final user = authRefresh.user;
      final loggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';

      if (user == null) {
        if (!loggingIn && !isSplash) return '/login';
      } else {
        if (loggingIn || isSplash) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    ],
  );
});
