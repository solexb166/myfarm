import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/backend.dart';
import 'services/storage.dart';
import 'services/treatment_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  // Use the last treatment text downloaded from the backend, if any.
  TreatmentDB.setOverrides(await Storage.getTreatmentOverrides());
  await Backend.init();
  runApp(const MyFarmApp());
  Backend.sync();
}

class MyFarmApp extends StatelessWidget {
  const MyFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MY FARM',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
