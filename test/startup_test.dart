import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_farm/main.dart';
import 'package:my_farm/screens/home_screen.dart';
import 'package:my_farm/screens/startup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('opening animation plays, then the app opens', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'flutter.lang': 'lg'});
    await tester.pumpWidget(const MyFarmApp());

    // Mid-animation: still on the opening screen.
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(StartupScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    // After the animation and the fade, the app is open (no backend in
    // tests, so straight to home) in the saved language.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('FAAMU YANGE'), findsOneWidget);
  });
}
