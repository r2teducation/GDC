import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gt/login.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyAPGf92bzIDo0xnLRk92UkZbc3b3SkP66U",
        authDomain: "globaldentalclinic-a1b4b.firebaseapp.com",
        projectId: "globaldentalclinic-a1b4b",
        storageBucket: "globaldentalclinic-a1b4b.firebasestorage.app",
        messagingSenderId: "18297162424",
        appId: "1:18297162424:web:59ec6ad8603cd844d8024d",
        measurementId: "G-NVTS4W0Q3J"),
  );
  await ensureAuth();
  runApp(
    ChangeNotifierProvider(
      create: (context) => GlobalData(),
      child: const MainWidget(),
    ),
  );
}

Future<void> ensureAuth() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }
}

class MainWidget extends StatelessWidget {
  const MainWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MaterialApp(
        theme: ThemeData(
          textTheme: GoogleFonts.outfitTextTheme(textTheme).copyWith(
            bodyMedium: GoogleFonts.outfit(textStyle: textTheme.bodyMedium),
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: const NewLoginPage());
  }
}

class GlobalData extends ChangeNotifier {
  bool _isUserLoggedIn = false;

  bool get isUserLoggedIn => _isUserLoggedIn;

  void setIsUserLoggedIn(bool isUserLoggedIn) {
    _isUserLoggedIn = isUserLoggedIn;
    notifyListeners();
  }
}
