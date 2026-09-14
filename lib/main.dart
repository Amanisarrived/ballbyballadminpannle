import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/provider/admin_auth_provider.dart';
import 'package:cricket_admin/screens/auth/admin_login.dart';
import 'package:cricket_admin/screens/dashboard/dash_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    // Android/iOS: the google-services plugin has already created [DEFAULT]
    // natively from google-services.json before Dart runs. Passing the web
    // options below would conflict with it and throw duplicate-app, so attach
    // to the native app instead. Its database URL comes from firebase_url.
    await Firebase.initializeApp();
  } else if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCtsEoJsaoskgBjAMSl4FLqr9kq_K__jfA",
        authDomain: "circketnoti.firebaseapp.com",
        projectId: "circketnoti",
        storageBucket: "circketnoti.firebasestorage.app",
        messagingSenderId: "752963174826",
        appId: "1:752963174826:web:ee9f4360be1a3b7c562bd3",
        measurementId: "G-ZVLBC6R412",
        databaseURL: "https://circketnoti-default-rtdb.firebaseio.com",
      ),
    );
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    sslEnabled: true,
  );

  // await FirebaseAppCheck.instance.activate(
  //   webProvider:
  //       ReCaptchaV3Provider('6LeMioQsAAAAAJ9g9s0p5iJD39LrKsYwg6p6yq3v'),
  // );

  print("Firebase Initialized ✅");

  // Release builds render a blank grey box for any widget that throws, which
  // makes a broken screen impossible to diagnose from the deployed site.
  // Show the actual error instead.
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: const Color(0xFF0A0A0A),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFCC0000), size: 32),
                const SizedBox(height: 12),
                const Text('This screen failed to render',
                    style: TextStyle(
                        color: Color(0xFFE8E8E8),
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                SelectableText(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminAuthProvider()),
      ],
      child: const CricketAdminApp(),
    ),
  );
}

class CricketAdminApp extends StatelessWidget {
  const CricketAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cricket Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E0E0E),
        primaryColor: Colors.orangeAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.orangeAccent,
          secondary: Colors.redAccent,
        ),
      ),
      home: const AuthGate(), // 👈 changed
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Check persisted session on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminAuthProvider>().checkExistingSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    return auth.isAdmin ? const DashScreen() : const AdminLogin();
  }
}
