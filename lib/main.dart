import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/app_gate.dart';
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
  runApp(MyFarmApp(lang: await Storage.getLang()));
  Backend.sync();
}

class MyFarmApp extends StatelessWidget {
  final String lang;
  const MyFarmApp({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MY FARM',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: AppGate(initialLang: lang),
    );
  }
}
