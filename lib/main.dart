import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guest mode works fully offline against the local database, so a failed
  // Firebase init (no network on first launch, etc.) shouldn't block startup
  // — but it's a real failure now that the project is actually configured,
  // not the "no credentials yet" case this used to silently paper over.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("Firebase successfully initialized.");
  } catch (e) {
    debugPrint("Firebase initialization failed, continuing in offline/guest mode: $e");
  }

  runApp(const ProviderScope(child: FinFlowApp()));
}
