import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Failsafe Firebase Initialization
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase successfully initialized.");
  } catch (e) {
    debugPrint(
      "Firebase initialization bypassed (No credentials found/Offline Mode): $e",
    );
    // SQLite databases are fully operational for offline Guest Mode operations
  }

  runApp(const ProviderScope(child: FinFlowApp()));
}
