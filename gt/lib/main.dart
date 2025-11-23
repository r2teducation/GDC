import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gt/login.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
        apiKey: "AIzaSyCRQZmaZDlM7bd00LKFqiXll-_2vRVANWQ",
        authDomain: "hfapp-b53bb.firebaseapp.com",
        projectId: "hfapp-b53bb",
        storageBucket: "hfapp-b53bb.firebasestorage.app",
        messagingSenderId: "833342328412",
        appId: "1:833342328412:web:fdb34c56218b18c44d2099",
        measurementId: "G-X0BES6V8J4"),
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => GlobalData(),
      child: const MainWidget(),
    ),
  );
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
