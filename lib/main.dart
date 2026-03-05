import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cricket_admin/provider/admin_auth_provider.dart';
import 'package:cricket_admin/screens/auth/admin_login.dart';
import 'package:cricket_admin/screens/dashboard/dash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCtsEoJsaoskgBjAMSl4FLqr9kq_K__jfA",
      authDomain: "circketnoti.firebaseapp.com",
      projectId: "circketnoti",
      storageBucket: "circketnoti.firebasestorage.app",
      messagingSenderId: "752963174826",
      appId: "1:752963174826:web:ee9f4360be1a3b7c562bd3",
      measurementId: "G-ZVLBC6R412",
    ),
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    sslEnabled: true,
  );

  print("Firebase Initialized ✅");

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
