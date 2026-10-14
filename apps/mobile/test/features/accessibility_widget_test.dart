import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediexplain/design_system/widgets/badges.dart';
import 'package:mediexplain/features/home/presentation/home_screen.dart';
import 'package:mediexplain/l10n/app_localizations.dart';

void main() {
  testWidgets('offline indicator announces status without relying on color', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: OfflineIndicator(label: 'Offline')),
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    expect(tester.getSemantics(find.byType(OfflineIndicator)).label, 'Offline');
  });

  testWidgets('important home screen renders at 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('A clearer path through medical language'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Urdu localization establishes RTL directionality', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ur'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('طبی زبان')),
      ),
    );

    expect(
      Directionality.of(tester.element(find.text('طبی زبان'))),
      TextDirection.rtl,
    );
  });
}
