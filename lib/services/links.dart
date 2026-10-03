import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web pages the app links to. They live in docs/ and are published with
/// GitHub Pages (see store/README.md). Override at build time with
/// --dart-define=WEB_BASE_URL=https://example.org/myfarm if hosted elsewhere.
class Links {
  static const _base = String.fromEnvironment('WEB_BASE_URL',
      defaultValue: 'https://solexb166.github.io/myfarm');

  static const privacyPolicy = '$_base/privacy.html';
  static const deleteAccount = '$_base/delete-account.html';

  /// Opens [url] in the browser. False if there's no browser to open it.
  static Future<bool> open(String url) async {
    try {
      return await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open $url: $e');
      return false;
    }
  }
}
