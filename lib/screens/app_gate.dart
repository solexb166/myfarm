import 'dart:async';
import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/storage.dart';
import 'main_shell.dart';
import 'sign_in_screen.dart';

/// Root of the app. Farmers sign in once before using MY FARM; after that
/// the session stays on the phone, so the app opens straight to the home
/// screen even offline. Also owns the language choice, which is saved.
///
/// A build without Supabase settings has no accounts and opens the home
/// screen directly, so diagnosis is never blocked by a missing backend.
class AppGate extends StatefulWidget {
  final String initialLang;
  const AppGate({super.key, required this.initialLang});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  late String _lang = widget.initialLang;
  StreamSubscription<void>? _accountSub;

  @override
  void initState() {
    super.initState();
    _accountSub = Backend.accountChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    super.dispose();
  }

  void _setLang(String lang) {
    setState(() => _lang = lang);
    Storage.setLang(lang);
  }

  @override
  Widget build(BuildContext context) {
    if (Backend.enabled && Backend.account == null) {
      return SignInScreen(lang: _lang, onLang: _setLang);
    }
    return MainShell(lang: _lang, onLang: _setLang);
  }
}
