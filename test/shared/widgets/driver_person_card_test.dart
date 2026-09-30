import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/shared/models/discovery_person.dart';
import 'package:mobi_app/shared/widgets/driver_card.dart';
import 'package:mobi_design_system/theme/app_theme.dart';

void main() {
  testWidgets(
    'person card displays member ID and chats without fabricating a trip',
    (tester) async {
      final person = DiscoveryPerson(
        peerId: 'internal-peer-id',
        memberId: '004321',
        vehicleTypeId: 'moto',
        distanceKm: 1.2,
      );
      Uri? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DriverCard.person(
              person: person,
              onChat: () => opened = person.chatUri,
            ),
          ),
        ),
      );
      expect(find.text('004321'), findsOneWidget);
      expect(find.textContaining('internal-peer-id'), findsNothing);
      expect(find.text('1.2 KM AWAY'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Open in-app chat with 004321'));
      expect(opened?.queryParameters, {'peerId': 'internal-peer-id'});
      expect(tester.takeException(), isNull);
    },
  );
}
