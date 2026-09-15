import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_wardrobe_app/core/api/api_client.dart';
import 'package:smart_wardrobe_app/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    final apiClient = ApiClient();

    // Render SmartWardrobeApp with the required ApiClient dependency
    await tester.pumpWidget(SmartWardrobeApp(apiClient: apiClient));

    // Verify the root app renders correctly
    expect(find.byType(SmartWardrobeApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}