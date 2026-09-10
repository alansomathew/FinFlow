import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

/// Whether the current device is on the Pro tier. This is a local-only flag
/// with no real billing behind it yet (Phase 11 wires up in_app_purchase and
/// makes this the write side of a verified purchase instead of a manual
/// toggle) -- introduced now so every free/Pro gate from here on has a real
/// field to read instead of being invented ad hoc per phase.
final isProProvider = StreamProvider<bool>((ref) {
  return AppDatabase.instance.watchLocalSettings().map((row) => row.isPro);
});

Future<void> setProTierForTesting(bool isPro) {
  return AppDatabase.instance.setPro(isPro);
}
