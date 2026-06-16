import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/theme/app_theme.dart';
import 'package:mobi_app/features/profile/widgets/profile_subscription_section.dart';
import 'package:mobi_app/models/subscription_plan_model.dart';

void main() {
  const plans = [
    SubscriptionPlanModel(
      id: 'cab-monthly',
      vehicleTypeId: 'cab',
      countryId: 'RW',
      intervalDays: 30,
      price: 15000,
    ),
    SubscriptionPlanModel(
      id: 'moto-monthly',
      vehicleTypeId: 'moto',
      countryId: 'RW',
      intervalDays: 30,
      price: 5000,
    ),
    SubscriptionPlanModel(
      id: 'private-daily',
      vehicleTypeId: 'private',
      countryId: 'RW',
      intervalDays: 1,
      price: 1000,
    ),
    SubscriptionPlanModel(
      id: 'rentals-daily',
      vehicleTypeId: 'rentals',
      countryId: 'RW',
      intervalDays: 1,
      price: 1000,
    ),
    SubscriptionPlanModel(
      id: 'rentals-monthly',
      vehicleTypeId: 'rentals',
      countryId: 'RW',
      intervalDays: 30,
      price: 15000,
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    required String vehicleTypeId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: ProfileSubscriptionSection(
            allPlans: plans,
            vehicleTypeId: vehicleTypeId,
            countryId: 'RW',
          ),
        ),
      ),
    );
  }

  testWidgets('free-credit vehicle types do not show subscription prices', (
    tester,
  ) async {
    await pump(tester, vehicleTypeId: 'cab');

    expect(find.text('30 free credits, one free everyday'), findsOneWidget);
    expect(
      find.text('Use one free driver credit per day before upgrading'),
      findsOneWidget,
    );
    expect(find.text('Subscription required'), findsNothing);
    expect(find.text('15,000 RWF'), findsNothing);
  });

  testWidgets('Others shows one free credit every day for 30 days', (
    tester,
  ) async {
    await pump(tester, vehicleTypeId: 'private');

    expect(
      find.text('One free Others credit every day for 30 days'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Use one free trip credit every day for 30 days before upgrading.',
      ),
      findsOneWidget,
    );
    expect(find.text('Subscription required'), findsNothing);
    expect(find.text('1,000 RWF'), findsNothing);
  });

  testWidgets('Others alias uses private free-credit policy', (tester) async {
    await pump(tester, vehicleTypeId: 'private_');

    expect(
      find.text('One free Others credit every day for 30 days'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Use one free trip credit every day for 30 days before upgrading.',
      ),
      findsOneWidget,
    );
    expect(find.text('1,000 RWF'), findsNothing);
  });

  testWidgets('Rentals shows one free credit every day for 30 days', (
    tester,
  ) async {
    await pump(tester, vehicleTypeId: 'rentals');

    expect(
      find.text('One free Rentals credit every day for 30 days'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Use one free trip credit every day for 30 days before upgrading.',
      ),
      findsOneWidget,
    );
    expect(find.text('Subscription required'), findsNothing);
    expect(find.text('1,000 RWF'), findsNothing);
    expect(find.text('15,000 RWF'), findsNothing);
  });

  testWidgets('Moto Taxi shows one free credit every day for 12 months', (
    tester,
  ) async {
    await pump(tester, vehicleTypeId: 'moto');

    expect(find.text('One free credit per day for 12 months'), findsOneWidget);
    expect(
      find.text('One free Moto Taxi credit every day for 12 months'),
      findsNothing,
    );
    expect(find.text('One free credit per day for 12 months.'), findsOneWidget);
    expect(find.text('Subscription required'), findsNothing);
    expect(find.text('5,000 RWF'), findsNothing);
  });
}
