import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/core/localization/country_providers.dart';
import 'package:mobi_app/core/localization/country_service.dart';
import 'package:mobi_app/shared/data/phone_country_codes.dart';
import 'package:mobi_app/shared/widgets/country_flag.dart';
import 'package:mobi_app/shared/widgets/mobi_bottom_sheet.dart';
import 'package:mobi_app/shared/widgets/whatsapp_input.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_theme.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';
import 'package:mobi_shared_types/models/country.dart';

void main() {
  group('country picker input-focus return', () {
    const accessibilityChannel = MethodChannel(
      'rw.mobi.app/accessibility_focus',
    );
    late List<MethodCall> nativeFocusCalls;
    late GlobalKey<NavigatorState> navigatorKey;
    late StateSetter updateFixture;
    late FocusNode countryFocus;
    late String countryCode;
    late bool enabled;
    late bool inputPresent;
    late int changes;

    setUp(() {
      nativeFocusCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(accessibilityChannel, (call) async {
            nativeFocusCalls.add(call);
            return true;
          });
      navigatorKey = GlobalKey<NavigatorState>();
      countryCode = '+250';
      enabled = true;
      inputPresent = true;
      changes = 0;
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(accessibilityChannel, null);
    });

    void countryFocusTest(
      String description,
      WidgetTesterCallback callback, {
      bool semanticsEnabled = true,
    }) {
      testWidgets(
        description,
        callback,
        variant: TargetPlatformVariant.only(TargetPlatform.android),
        semanticsEnabled: semanticsEnabled,
      );
    }

    Finder countryTrigger() => find
        .descendant(
          of: find.byType(WhatsAppInput),
          matching: find.byType(InkWell),
        )
        .first;

    Finder countrySemantics() => find
        .ancestor(of: countryTrigger(), matching: find.byType(Semantics))
        .first;

    Future<void> pumpFixture(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryServiceProvider.overrideWithValue(_TestCountryService()),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  updateFixture = setState;
                  return inputPresent
                      ? WhatsAppInput(
                          value: '0788123456',
                          onChanged: (_) {},
                          countryCode: countryCode,
                          onCountryCodeChanged: (value) => setState(() {
                            countryCode = value;
                            changes++;
                          }),
                          enabled: enabled,
                        )
                      : const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      countryFocus = tester.widget<InkWell>(countryTrigger()).focusNode!;
    }

    Future<Finder> openAndActivateSearch(WidgetTester tester) async {
      await tester.tap(countryTrigger());
      await tester.pumpAndSettle();
      final search = find.widgetWithText(TextField, 'Search country or code');
      await tester.tap(search);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: search, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      return search;
    }

    countryFocusTest(
      'explicit Search then Close restores real input and semantics focus after transition',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpFixture(tester);
          expect(countryFocus.hasPrimaryFocus, isFalse);
          final search = await openAndActivateSearch(tester);
          final sheetRoute = ModalRoute.of(tester.element(search))!;
          var transitionCompleted = false;
          final completed = sheetRoute.completed.then<void>((_) {
            transitionCompleted = true;
          });

          await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
          await tester.pump();
          await tester.pump(sheetRoute.reverseTransitionDuration ~/ 2);
          expect(transitionCompleted, isFalse);
          expect(countryFocus.hasPrimaryFocus, isFalse);
          expect(nativeFocusCalls, isEmpty);

          await tester.pumpAndSettle();
          await completed;
          expect(transitionCompleted, isTrue);
          expect(find.text('Country code'), findsNothing);
          expect(countryFocus.hasPrimaryFocus, isTrue);
          final openerNode = tester.getSemantics(countrySemantics());
          final flags = openerNode.flagsCollection;
          expect(flags.isFocused.toBoolOrNull(), isTrue);
          expect(openerNode.attached, isTrue);
          expect(openerNode.isMergedIntoParent, isFalse);
          expect(openerNode.getSemanticsData().identifier, isNotEmpty);
          expect(nativeFocusCalls, hasLength(1));
          expect(nativeFocusCalls.single.method, 'restoreFocus');
          expect(nativeFocusCalls.single.arguments, {'nodeId': openerNode.id});
          expect(changes, 0);
          expect(countryCode, '+250');
          expect(find.text('0788123456'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    countryFocusTest(
      'selection keeps callback and phone while returning input focus',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpFixture(tester);
          final search = await openAndActivateSearch(tester);
          await tester.enterText(search, 'Kenya');
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, 'Kenya'));
          await tester.pumpAndSettle();

          expect(changes, 1);
          expect(countryCode, '+254');
          expect(find.text('KE'), findsOneWidget);
          expect(find.text('0788123456'), findsOneWidget);
          expect(find.text('Country code'), findsNothing);
          expect(
            tester.widget<InkWell>(countryTrigger()).focusNode,
            same(countryFocus),
          );
          expect(countryFocus.hasPrimaryFocus, isTrue);
          expect(nativeFocusCalls, hasLength(1));
          expect(nativeFocusCalls.single.arguments, {
            'nodeId': tester.getSemantics(countrySemantics()).id,
          });
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    countryFocusTest('disabled owner does not regain country input focus', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpFixture(tester);
        await openAndActivateSearch(tester);
        updateFixture(() => enabled = false);
        await tester.pump();
        await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
        await tester.pumpAndSettle();

        expect(countryFocus.canRequestFocus, isFalse);
        expect(countryFocus.hasFocus, isFalse);
        expect(nativeFocusCalls, isEmpty);
        expect(changes, 0);
        expect(find.text('Country code'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    countryFocusTest(
      'disposed owner can finish Close without restoring a dead node',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpFixture(tester);
          await openAndActivateSearch(tester);
          updateFixture(() => inputPresent = false);
          await tester.pump();
          expect(find.byType(WhatsAppInput), findsNothing);
          await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
          await tester.pumpAndSettle();

          expect(find.text('Country code'), findsNothing);
          expect(changes, 0);
          expect(nativeFocusCalls, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    countryFocusTest(
      'covered owner does not steal input focus from a newer route',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final newerFocus = FocusNode();
          addTearDown(newerFocus.dispose);
          await pumpFixture(tester);
          await openAndActivateSearch(tester);
          await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
          await tester.pump();
          navigatorKey.currentState!.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: TextField(focusNode: newerFocus, autofocus: true),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(newerFocus.hasPrimaryFocus, isTrue);
          expect(countryFocus.hasFocus, isFalse);
          expect(nativeFocusCalls, isEmpty);
          expect(changes, 0);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    countryFocusTest('input focus chosen before opener return is preserved', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpFixture(tester);
        final phoneInput = tester.widget<EditableText>(
          find.byType(EditableText),
        );
        // Keep the phone selection valid so gaining focus changes no controller
        // value and cannot cancel the return through the input-edit epoch.
        phoneInput.controller.selection = TextSelection.collapsed(
          offset: phoneInput.controller.text.length,
        );
        final phoneFocus = phoneInput.focusNode;
        final search = await openAndActivateSearch(tester);
        final phoneValueBeforeDismissal = phoneInput.controller.value;
        final sheetRoute = ModalRoute.of(tester.element(search))!;
        var chosePhoneBeforeCountryReturn = false;
        final choosePhoneAfterDismissal = sheetRoute.completed.then<void>((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            expect(countryFocus.hasFocus, isFalse);
            phoneFocus.requestFocus();
            FocusManager.instance.applyFocusChangesIfNeeded();
            chosePhoneBeforeCountryReturn = true;
          });
        });

        await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
        await tester.pumpAndSettle();
        await choosePhoneAfterDismissal;

        expect(chosePhoneBeforeCountryReturn, isTrue);
        expect(phoneFocus.hasPrimaryFocus, isTrue);
        expect(phoneInput.controller.value, phoneValueBeforeDismissal);
        expect(countryFocus.hasFocus, isFalse);
        expect(nativeFocusCalls, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    countryFocusTest(
      'a tap on the already focused phone cancels opener return',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpFixture(tester);
          final phoneField = find.descendant(
            of: find.byType(WhatsAppInput),
            matching: find.byType(TextField),
          );
          final phone = tester.widget<TextField>(phoneField);
          final phoneFocus = tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode;
          phone.controller!.selection = TextSelection.collapsed(
            offset: phone.controller!.text.length,
          );
          final originalValue = phone.controller!.value;
          final search = await openAndActivateSearch(tester);
          final sheetRoute = ModalRoute.of(tester.element(search))!;
          var tappedUnchangedPhone = false;
          final restorePhone = sheetRoute.completed.then<void>((_) {
            phoneFocus.requestFocus();
            FocusManager.instance.applyFocusChangesIfNeeded();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              expect(phoneFocus.hasPrimaryFocus, isTrue);
              // Dispatch the TextField tap callback with no new focus or value.
              phone.onTap!();
              tappedUnchangedPhone = true;
            });
          });

          await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
          await tester.pumpAndSettle();
          await restorePhone;
          expect(tappedUnchangedPhone, isTrue);
          expect(phone.controller!.value, originalValue);
          expect(phoneFocus.hasPrimaryFocus, isTrue);
          expect(countryFocus.hasFocus, isFalse);
          expect(nativeFocusCalls, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    countryFocusTest(
      'a newer input-focus choice cancels native country return',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpFixture(tester);
          final phoneFocus = tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode;
          await openAndActivateSearch(tester);
          void choosePhoneFocus() {
            if (countryFocus.hasFocus) phoneFocus.requestFocus();
          }

          countryFocus.addListener(choosePhoneFocus);
          try {
            await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
            await tester.pumpAndSettle();
            expect(phoneFocus.hasPrimaryFocus, isTrue);
            expect(countryFocus.hasFocus, isFalse);
            expect(nativeFocusCalls, isEmpty);
            expect(tester.takeException(), isNull);
          } finally {
            countryFocus.removeListener(choosePhoneFocus);
          }
        } finally {
          semantics.dispose();
        }
      },
    );

    countryFocusTest('reopening invalidates the older pending country return', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpFixture(tester);
        await openAndActivateSearch(tester);
        var reopened = false;
        void reopenAfterInputFocus() {
          if (!countryFocus.hasFocus || reopened) return;
          reopened = true;
          tester.widget<InkWell>(countryTrigger()).onTap!();
        }

        countryFocus.addListener(reopenAfterInputFocus);
        try {
          await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
          await tester.pumpAndSettle();
          expect(reopened, isTrue);
          expect(find.text('Country code'), findsOneWidget);
          expect(nativeFocusCalls, isEmpty);
        } finally {
          countryFocus.removeListener(reopenAfterInputFocus);
        }

        await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
        await tester.pumpAndSettle();
        expect(nativeFocusCalls, hasLength(1));
        expect(nativeFocusCalls.single.arguments, {
          'nodeId': tester.getSemantics(countrySemantics()).id,
        });
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    countryFocusTest('disabled semantics skips native country return', (
      tester,
    ) async {
      await pumpFixture(tester);
      await openAndActivateSearch(tester);
      await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
      await tester.pumpAndSettle();

      expect(countryFocus.hasPrimaryFocus, isTrue);
      expect(nativeFocusCalls, isEmpty);
      expect(tester.takeException(), isNull);
    }, semanticsEnabled: false);
  });

  testWidgets('WhatsApp input uses native phone text entry', (tester) async {
    var phone = '';
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            countryServiceProvider.overrideWithValue(_TestCountryService()),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: WhatsAppInput(
                value: phone,
                onChanged: (value) => phone = value,
                countryCode: '+250',
                onCountryCodeChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final phoneField = tester.widget<TextField>(find.byType(TextField).first);
      expect(phoneField.keyboardType, TextInputType.phone);
      expect(phoneField.autofillHints, contains(AutofillHints.telephoneNumber));
      expect(find.byType(TextButton), findsNothing);
      expect(find.byIcon(Icons.backspace_outlined), findsNothing);
      expect(
        tester.getSemantics(find.byType(EditableText)).getSemanticsData().label,
        contains('WhatsApp Number phone number, +250'),
      );

      await tester.enterText(find.byType(TextField).first, '0788 123 456');
      await tester.pump();

      expect(phone, '0788123456');
      expect(find.text('0788123456'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(EditableText)).getSemanticsData().label,
        contains('WhatsApp Number phone number, +250'),
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} country picker is neutral above authentication',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final base = brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme;
          final authentication = MobiFamilyPalette.resolve(
            MobiVisualFamily.authentication,
            brightness,
          ).apply(base);
          const phone = '0788123456';
          var countryCode = '+250';
          var changes = 0;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                countryServiceProvider.overrideWithValue(_TestCountryService()),
              ],
              child: MaterialApp(
                theme: authentication,
                home: Scaffold(
                  body: StatefulBuilder(
                    builder: (context, setState) => WhatsAppInput(
                      value: phone,
                      onChanged: (_) {},
                      countryCode: countryCode,
                      onCountryCodeChanged: (value) => setState(() {
                        countryCode = value;
                        changes++;
                      }),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('RW'), findsOneWidget);

          await tester.tap(find.text('RW'));
          await tester.pumpAndSettle();

          final search = find.widgetWithText(
            TextField,
            'Search country or code',
          );
          final header = find.text('Country code');
          final close = find.widgetWithIcon(IconButton, Icons.close);
          final searchContext = tester.element(search);
          final sheetTheme = Theme.of(searchContext);
          final body = brightness == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : base.colorScheme.surfaceContainerLowest;
          final searchSurface = brightness == Brightness.dark
              ? const Color(0xFF0F0F12)
              : base.colorScheme.surfaceContainerLow;
          final bodyDecorations = tester
              .widgetList<DecoratedBox>(
                find.ancestor(of: header, matching: find.byType(DecoratedBox)),
              )
              .map((widget) => widget.decoration)
              .whereType<BoxDecoration>()
              .map((decoration) => decoration.color);

          expect(bodyDecorations, contains(body));
          expect(
            tester.getSemantics(close),
            matchesSemantics(
              label: 'Close country selector',
              tooltip: 'Close country selector',
              isButton: true,
              isFocusable: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true,
              hasFocusAction: true,
            ),
          );
          final closeBounds = tester.getRect(close);
          expect(closeBounds.width, greaterThanOrEqualTo(48));
          expect(closeBounds.height, greaterThanOrEqualTo(48));
          expect(
            tester.widget<IconButton>(close).style!.shape!.resolve({}),
            isA<CircleBorder>(),
          );
          expect(
            tester.getSemantics(header),
            matchesSemantics(label: 'Country code', isHeader: true),
          );
          final slab =
              tester
                      .widget<DecoratedSliver>(find.byType(DecoratedSliver))
                      .decoration
                  as BoxDecoration;
          expect(
            slab.color,
            brightness == Brightness.dark
                ? const Color(0xFF242527)
                : base.colorScheme.surfaceContainerLow,
          );
          expect(slab.color, isNot(body));
          expect(slab.borderRadius, BorderRadius.circular(AppRadii.xl));
          expect(sheetTheme.colorScheme.surface, body);
          expect(
            sheetTheme.extension<MobiThemeExtension>()!.surfaceContainerLow,
            searchSurface,
          );
          expect(
            tester
                .widget<InputDecorator>(
                  find.descendant(
                    of: search,
                    matching: find.byType(InputDecorator),
                  ),
                )
                .decoration
                .fillColor,
            searchSurface,
          );
          expect(
            tester.widget<Text>(header).style!.color,
            base.colorScheme.onSurface,
          );
          expect(
            sheetTheme.colorScheme.onSurfaceVariant,
            base.colorScheme.onSurfaceVariant,
          );
          expect(
            sheetTheme.inputDecorationTheme.prefixIconColor,
            base.colorScheme.onSurfaceVariant,
          );
          expect(
            sheetTheme.inputDecorationTheme.focusedBorder!.borderSide.color,
            base.colorScheme.primary,
          );
          expect(
            sheetTheme.textTheme.titleMedium!.fontFamily,
            authentication.textTheme.titleMedium!.fontFamily,
          );
          expect(
            sheetTheme.textTheme.titleMedium!.fontSize,
            authentication.textTheme.titleMedium!.fontSize,
          );
          expect(
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: search,
                    matching: find.byType(EditableText),
                  ),
                )
                .focusNode
                .hasFocus,
            isTrue,
          );
          expect(
            Theme.of(
              tester.element(find.byType(WhatsAppInput)),
            ).colorScheme.surface,
            authentication.colorScheme.surface,
          );

          // Search keeps name, ISO and dialing-code lookup, with the original
          // phone value retained across cancellation and a later selection.
          await tester.enterText(search, '  rwanda  ');
          await tester.pumpAndSettle();
          expect(find.byType(ListTile), findsOneWidget);
          final rwanda = find.widgetWithText(ListTile, 'Rwanda');
          expect(rwanda, findsOneWidget);
          // The decorative flag cannot replace readable country identity.
          // Name, ISO and dial code remain visible and identify the same row.
          expect(
            find.descendant(of: rwanda, matching: find.text('RW')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: rwanda, matching: find.text('+250')),
            findsOneWidget,
          );
          final rwandaFlag = find.descendant(
            of: rwanda,
            matching: find.byType(CountryFlag),
          );
          expect(rwandaFlag, findsOneWidget);
          final countryArtwork = tester.widget<CountryFlag>(rwandaFlag);
          expect(countryArtwork.isoCode, 'RW');
          expect(
            countryArtwork.flag,
            _TestCountryService._countries.first.flag,
          );
          expect(
            tester.widget<Text>(header).style!.fontSize,
            greaterThan(
              tester
                      .widget<Text>(
                        find.descendant(
                          of: rwanda,
                          matching: find.text('Rwanda'),
                        ),
                      )
                      .style!
                      .fontSize! *
                  1.5,
            ),
          );
          expect(
            tester
                .widget<Text>(
                  find.descendant(of: rwanda, matching: find.text('Rwanda')),
                )
                .style!
                .color,
            base.colorScheme.onSurface,
          );

          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(header, findsNothing);
          expect(changes, 0);
          expect(countryCode, '+250');
          expect(find.text(phone), findsOneWidget);

          await tester.tap(find.text('RW'));
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(header, findsNothing);
          expect(changes, 0);
          expect(countryCode, '+250');
          expect(find.text(phone), findsOneWidget);

          await tester.tap(find.text('RW'));
          await tester.pumpAndSettle();
          await tester.enterText(search, '+254');
          await tester.pumpAndSettle();
          expect(find.widgetWithText(ListTile, 'Kenya'), findsOneWidget);
          await tester.enterText(search, 'ke');
          await tester.pumpAndSettle();
          final kenya = find.widgetWithText(ListTile, 'Kenya');
          expect(kenya, findsOneWidget);
          await tester.tap(kenya);
          await tester.pumpAndSettle();
          expect(header, findsNothing);
          expect(countryCode, '+254');
          expect(changes, 1);
          expect(find.text('KE'), findsOneWidget);
          expect(find.text(phone), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} country picker uses available safe space and grows for text',
      (tester) async {
        const viewport = Size(390, 844);
        const safeInsets = EdgeInsets.fromLTRB(8, 52, 8, 34);
        tester.view
          ..physicalSize = viewport
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var textScale = 1.0;
        late StateSetter updateFixture;
        final base = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        final authentication = MobiFamilyPalette.resolve(
          MobiVisualFamily.authentication,
          brightness,
        ).apply(base);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              countryServiceProvider.overrideWithValue(_TestCountryService()),
            ],
            child: MaterialApp(
              theme: authentication,
              builder: (context, child) => StatefulBuilder(
                builder: (context, setState) {
                  updateFixture = setState;
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: safeInsets,
                      viewPadding: safeInsets,
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: child!,
                  );
                },
              ),
              home: Scaffold(
                body: WhatsAppInput(
                  value: '0788123456',
                  onChanged: (_) {},
                  countryCode: '+250',
                  onCountryCodeChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('RW'));
        await tester.pumpAndSettle();

        final search = find.widgetWithText(TextField, 'Search country or code');
        final title = find.text('Country code');
        final close = find.widgetWithIcon(IconButton, Icons.close);
        final bodyColor = Theme.of(tester.element(search)).colorScheme.surface;
        final sheet = find.ancestor(
          of: title,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color == bodyColor,
          ),
        );
        final sheetRect = tester.getRect(sheet.first);
        final searchRect = tester.getRect(search);
        final list = find.byType(CustomScrollView);
        // A tall picker uses the available portrait space while its controls
        // avoid a notch and side cutouts; no source crop is a system inset.
        expect(sheetRect.top, greaterThanOrEqualTo(safeInsets.top));
        expect(sheetRect.top, lessThanOrEqualTo(safeInsets.top + 16));
        expect(sheetRect.left, greaterThanOrEqualTo(safeInsets.left));
        expect(
          sheetRect.right,
          lessThanOrEqualTo(viewport.width - safeInsets.right),
        );
        expect(searchRect.height, greaterThanOrEqualTo(48));
        expect(tester.getRect(close).height, greaterThanOrEqualTo(48));
        expect(
          tester.getRect(list).bottom,
          lessThanOrEqualTo(viewport.height - safeInsets.bottom),
        );
        expect(
          tester.getRect(find.byType(ListTile).first).height,
          closeTo(72, 0.01),
          reason: 'A short country name keeps the source-observed row rhythm.',
        );
        final editable = tester.widget<EditableText>(
          find.descendant(of: search, matching: find.byType(EditableText)),
        );
        expect(editable.focusNode.hasFocus, isTrue);
        editable.focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(tester.getRect(search), searchRect);

        updateFixture(() => textScale = 1.3);
        await tester.pumpAndSettle();
        final largeSearchRect = tester.getRect(search);
        expect(largeSearchRect.height, greaterThan(searchRect.height));
        expect(largeSearchRect.width, searchRect.width);
        // A real long country name wraps instead of overlapping its ISO/dial
        // content or forcing the row back to a fixed-height crop.
        await tester.enterText(search, 'British Indian Ocean Territory');
        await tester.pumpAndSettle();
        final longCountry = find.widgetWithText(
          ListTile,
          'British Indian Ocean Territory',
        );
        expect(longCountry, findsOneWidget);
        final longRowRect = tester.getRect(longCountry);
        final nameRect = tester.getRect(
          find.descendant(
            of: longCountry,
            matching: find.text('British Indian Ocean Territory'),
          ),
        );
        expect(longRowRect.height, greaterThan(72));
        expect(nameRect.top, greaterThanOrEqualTo(longRowRect.top));
        expect(nameRect.bottom, lessThanOrEqualTo(longRowRect.bottom));
        expect(nameRect.left, greaterThanOrEqualTo(longRowRect.left));
        expect(nameRect.right, lessThanOrEqualTo(longRowRect.right));
        expect(close.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(title, findsNothing);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} country picker remains usable with keyboard and large text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final base = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        final authentication = MobiFamilyPalette.resolve(
          MobiVisualFamily.authentication,
          brightness,
        ).apply(base);
        const phone = '0788123456';
        var changes = 0;
        var countryCode = '+250';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              countryServiceProvider.overrideWithValue(_TestCountryService()),
            ],
            child: MaterialApp(
              theme: authentication,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.3),
                  viewInsets: const EdgeInsets.only(bottom: 300),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => WhatsAppInput(
                    value: phone,
                    onChanged: (_) {},
                    countryCode: countryCode,
                    onCountryCodeChanged: (value) => setState(() {
                      countryCode = value;
                      changes++;
                    }),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('RW'));
        await tester.pumpAndSettle();

        final close = find.widgetWithIcon(IconButton, Icons.close);
        final search = find.widgetWithText(TextField, 'Search country or code');
        final editable = tester.widget<EditableText>(
          find.descendant(of: search, matching: find.byType(EditableText)),
        );
        expect(editable.focusNode.hasFocus, isTrue);
        expect(tester.getRect(search).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(close).bottom, lessThanOrEqualTo(544));
        expect(tester.getRect(search).bottom, lessThanOrEqualTo(544));
        expect(
          tester.getRect(find.byType(CustomScrollView)).bottom,
          lessThanOrEqualTo(544),
        );
        expect(tester.takeException(), isNull);

        final list = find.byType(CustomScrollView);
        expect(
          tester.widget<CustomScrollView>(list).keyboardDismissBehavior,
          ScrollViewKeyboardDismissBehavior.onDrag,
        );
        final zimbabwe = find.widgetWithText(ListTile, 'Zimbabwe');
        final scrollable = find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        // This actual fixture contains every global country row (RW is merged
        // into its existing entry). Allow two viewport-sized gestures per row
        // rather than the SDK's default of 50; lazy extent estimates and
        // wrapped text do not provide an exact total height before traversal.
        final gestureBudget = globalPhoneCountryCodes.length * 2;
        final scrollStep = position.viewportDimension * 0.75;
        var gestures = 0;
        while (zimbabwe.evaluate().isEmpty && gestures < gestureBudget) {
          final before = position.pixels;
          await tester.drag(scrollable, Offset(0, -scrollStep));
          await tester.pumpAndSettle();
          gestures++;
          expect(tester.takeException(), isNull);
          expect(
            position.pixels,
            greaterThan(before),
            reason:
                'Country traversal stalled before Zimbabwe: gesture=$gestures '
                'budget=$gestureBudget offset=${position.pixels} '
                'max=${position.maxScrollExtent} '
                'viewport=${position.viewportDimension}',
          );
        }
        expect(
          zimbabwe,
          findsOneWidget,
          reason:
              'Zimbabwe was not built after $gestures of $gestureBudget '
              'gestures: offset=${position.pixels} '
              'max=${position.maxScrollExtent} '
              'viewport=${position.viewportDimension}',
        );
        await tester.ensureVisible(zimbabwe);
        await tester.pumpAndSettle();
        expect(zimbabwe.hitTestable(), findsOneWidget);
        debugPrint(
          'COUNTRY_SCROLL_REACHED ${brightness.name} gestures=$gestures '
          'budget=$gestureBudget offset=${position.pixels} '
          'max=${position.maxScrollExtent} viewport=${position.viewportDimension}',
        );
        await tester.tap(zimbabwe);
        await tester.pumpAndSettle();
        expect(countryCode, '+263');
        expect(changes, 1);
        expect(find.text(phone), findsOneWidget);
        expect(find.text('Country code'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('ZW'));
        await tester.pumpAndSettle();
        await tester.enterText(search, 'no-country-matches-this');
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsNothing);
        expect(close.hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(changes, 1);
        expect(countryCode, '+263');
        expect(find.text(phone), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} other bottom sheets keep their inherited visual family',
      (tester) async {
        final authentication =
            MobiFamilyPalette.resolve(
              MobiVisualFamily.authentication,
              brightness,
            ).apply(
              brightness == Brightness.dark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme,
            );
        ThemeData? contentTheme;
        await tester.pumpWidget(
          MaterialApp(
            theme: authentication,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => MobiBottomSheet.show<void>(
                    context: context,
                    title: 'Existing sheet',
                    builder: (context) {
                      contentTheme = Theme.of(context);
                      return const Text('Existing content');
                    },
                  ),
                  child: const Text('Open existing sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open existing sheet'));
        await tester.pumpAndSettle();
        expect(find.text('Existing content'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing);
        expect(
          tester.widget<Text>(find.text('Existing sheet')).style!.fontSize,
          18,
        );
        expect(contentTheme!.colorScheme, authentication.colorScheme);
        expect(
          contentTheme!.extension<MobiThemeExtension>(),
          authentication.extension<MobiThemeExtension>(),
        );
      },
    );
  }
}

class _TestCountryService implements CountryService {
  static final _countries = Country.fallbackCountries
      .where((country) => country.id == 'RW')
      .toList();

  @override
  Future<List<Country>> getCountries() async => _countries;

  @override
  Future<List<Country>> getAfricanCountries() async => _countries;

  @override
  Future<Country?> findById(String id) async =>
      _countries.where((country) => country.id == id).firstOrNull;

  @override
  Future<Country> findByDialingCode(String code) async =>
      findByDialingCodeSync(code) ?? _countries.first;

  @override
  Country? findByDialingCodeSync(String code) =>
      _countries.where((country) => country.dialingCode == code).firstOrNull;

  @override
  Future<String> currencyForCode(String dialingCode) async =>
      currencyForCodeSync(dialingCode);

  @override
  String currencyForCodeSync(String dialingCode) =>
      findByDialingCodeSync(dialingCode)?.currency ?? 'RWF';

  @override
  String momoBrandForCodeSync(String dialingCode) =>
      findByDialingCodeSync(dialingCode)?.momoBrand ?? 'MoMo';

  @override
  String buildUssdForNumber(
    String dialingCode,
    String phone, [
    String? amount,
  ]) =>
      findByDialingCodeSync(dialingCode)?.buildUssdForNumber(phone, amount) ??
      '';

  @override
  String buildUssdForCode(String dialingCode, String code, [String? amount]) =>
      findByDialingCodeSync(dialingCode)?.buildUssdForCode(code, amount) ?? '';

  @override
  String normalizeLocalPhoneDisplay({
    required String dialingCode,
    required String rawValue,
    Country? country,
  }) => rawValue.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Future<void> warmCache() async {}

  @override
  void clearCache() {}
}
