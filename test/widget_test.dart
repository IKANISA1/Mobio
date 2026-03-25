import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/main.dart';

void main() {
  testWidgets('App initializes without crashing', (tester) async {
    // The main app can be pumped, though full initialization 
    // requires Supabase and other mocking, so we just do a simple sanity check.
    await tester.pumpWidget(const MobiMainApp());
    await tester.pump();
    expect(find.byType(MobiMainApp), findsOneWidget);
  });
}
