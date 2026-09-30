import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/presentation/face_copy.dart';

void main() {
  testWidgets('uncertain Face mutation tells the user to check state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text(
            faceErrorCopy(
              context,
              const FaceServiceException('OUTCOME_UNKNOWN'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.textContaining('Check the current status or activity'),
      findsOneWidget,
    );
    expect(find.textContaining('Try again or use a number'), findsNothing);
  });
}
