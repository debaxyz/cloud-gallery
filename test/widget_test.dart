import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_gallery/main.dart';
import 'package:cloud_gallery/src/providers/app_providers.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const CloudGalleryApp(),
      ),
    );

    // Allow initial frame
    await tester.pump();
    expect(find.byType(CloudGalleryApp), findsOneWidget);
  });
}
