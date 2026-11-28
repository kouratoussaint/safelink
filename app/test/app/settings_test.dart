import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:safelink/core/settings/theme_mode_controller.dart';
import 'package:safelink/features/share/shortcuts.dart';

import '../helpers/fake_shortcuts.dart';
import '../helpers/pump_app.dart';

Brightness currentBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(NavigationBar))).brightness;

void main() {
  testWidgets('le thème choisi est appliqué et enregistré', (tester) async {
    final prefs = await pumpSafeLinkApp(tester);
    expect(currentBrightness(tester), Brightness.light);

    await tapDestination(tester, 'Paramètres');
    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();

    expect(currentBrightness(tester), Brightness.dark);
    expect(prefs.getString(ThemeModeController.storageKey), 'dark');

    await tester.tap(find.text('Clair'));
    await tester.pumpAndSettle();
    expect(currentBrightness(tester), Brightness.light);
    expect(prefs.getString(ThemeModeController.storageKey), 'light');
  });

  testWidgets('le thème enregistré est restauré au démarrage', (tester) async {
    await pumpSafeLinkApp(
      tester,
      preferences: {ThemeModeController.storageKey: 'dark'},
    );
    expect(currentBrightness(tester), Brightness.dark);
  });

  testWidgets('une valeur enregistrée inconnue revient au thème système', (
    tester,
  ) async {
    await pumpSafeLinkApp(
      tester,
      preferences: {ThemeModeController.storageKey: 'inconnu'},
    );
    await tapDestination(tester, 'Paramètres');
    final group = tester.widget<RadioGroup<ThemeMode>>(
      find.byType(RadioGroup<ThemeMode>),
    );
    expect(group.groupValue, ThemeMode.system);
  });

  testWidgets('« À propos » affiche version, licence et dépôt', (tester) async {
    await pumpSafeLinkApp(tester);
    await openAbout(tester);

    expect(appBarTitle('À propos'), findsOneWidget);
    expect(find.text('0.0.1 (1)'), findsOneWidget);
    expect(find.text('Build local'), findsOneWidget);
    expect(find.text('GPL-3.0-or-later (logiciel libre)'), findsOneWidget);
    expect(
      find.text('https://github.com/kouratoussaint/safelink'),
      findsOneWidget,
    );
    expect(
      find.textContaining('ne garantit jamais', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('l’adresse du dépôt est copiée, jamais ouverte', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          copied.add(args['text']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpSafeLinkApp(tester);
    await openAbout(tester);
    await tester.tap(find.byTooltip('Copier l’adresse du code source'));
    await tester.pumpAndSettle();

    expect(copied, ['https://github.com/kouratoussaint/safelink']);
    expect(find.text('Adresse copiée.'), findsOneWidget);
  });

  testWidgets('la page des licences s’ouvre', (tester) async {
    await pumpSafeLinkApp(tester);
    await openAbout(tester);
    await tester.scrollUntilVisible(
      find.text('Licences des composants'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Licences des composants'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  group('raccourcis', () {
    Future<void> openShortcuts(WidgetTester tester) async {
      await tapDestination(tester, 'Paramètres');
      await tester.scrollUntilVisible(find.text('Tuile du volet'), 200);
      await tester.ensureVisible(find.text('Tuile du volet'));
      await tester.pumpAndSettle();
    }

    testWidgets('Android 13 et plus : « Ajouter » propose la tuile', (
      tester,
    ) async {
      final shortcuts = FakeShortcuts(canRequest: true);
      await pumpSafeLinkApp(tester, shortcuts: shortcuts);
      await openShortcuts(tester);
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      expect(shortcuts.requests, 1);
      expect(find.text('Tuile ajoutée au volet.'), findsOneWidget);
    });

    testWidgets('tuile refusée : dit qu’elle n’est pas ajoutée', (
      tester,
    ) async {
      await pumpSafeLinkApp(
        tester,
        shortcuts: FakeShortcuts(canRequest: true, answer: TileRequest.refused),
      );
      await openShortcuts(tester);
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      expect(find.text('Tuile non ajoutée.'), findsOneWidget);
    });

    testWidgets('avant Android 13 : la marche à suivre, sans bouton', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      await openShortcuts(tester);
      expect(find.text('Ajouter'), findsNothing);
      expect(find.textContaining('touchez le crayon'), findsOneWidget);
      expect(find.text('Sélection de texte'), findsOneWidget);
    });
  });

  group('bulle flottante', () {
    Future<void> openShortcuts(WidgetTester tester) async {
      await tapDestination(tester, 'Paramètres');
      await tester.scrollUntilVisible(find.text('Bulle flottante'), 200);
      await tester.ensureVisible(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
    }

    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    SwitchListTile bubbleSwitch(WidgetTester tester) =>
        tester.widget(find.widgetWithText(SwitchListTile, 'Bulle flottante'));

    testWidgets('téléphone qui ne la permet pas : dit pourquoi', (
      tester,
    ) async {
      await pumpSafeLinkApp(tester);
      await openShortcuts(tester);
      expect(find.text('Non disponible sur ce téléphone.'), findsOneWidget);
      expect(
        find.widgetWithText(SwitchListTile, 'Bulle flottante'),
        findsNothing,
      );
    });

    testWidgets('désactivée par défaut ; activation après l’autorisation', (
      tester,
    ) async {
      final shortcuts = FakeShortcuts(bubbleSupported: true);
      await pumpSafeLinkApp(tester, shortcuts: shortcuts);
      await openShortcuts(tester);
      expect(bubbleSwitch(tester).value, isFalse);

      await tester.tap(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
      // Explication avant d'ouvrir le réglage Android.
      expect(find.text('Autoriser la bulle'), findsOneWidget);
      expect(find.textContaining('ne lit ni votre écran'), findsOneWidget);
      // Android 10 et suivants : cachée, la notification la remplace, faute
      // d'être prévenue des copies.
      expect(
        find.textContaining('touchez la notification SafeLink'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ouvrir le réglage'));
      await tester.pumpAndSettle();
      expect(shortcuts.overlaySettingsOpened, 1);

      // L'utilisateur donne l'autorisation puis revient ; les notifications
      // sont alors demandées (Android 13+), et accordées.
      shortcuts.bubblePermitted = true;
      await resume(tester);
      expect(shortcuts.notificationRequests, 1);
      expect(
        find.text(
          'Bulle activée\u00a0: elle disparaît après quelques secondes. Pour '
          'vérifier un lien copié, touchez la notification SafeLink.',
        ),
        findsOneWidget,
      );
      expect(bubbleSwitch(tester).value, isTrue);
      expect(shortcuts.bubbleEnabled, isTrue);

      // Désactiver.
      await tester.tap(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
      expect(bubbleSwitch(tester).value, isFalse);
      expect(shortcuts.bubbleEnabled, isFalse);
    });

    testWidgets('autorisation non donnée : reste désactivée', (tester) async {
      final shortcuts = FakeShortcuts(bubbleSupported: true);
      await pumpSafeLinkApp(tester, shortcuts: shortcuts);
      await openShortcuts(tester);
      await tester.tap(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouvrir le réglage'));
      await tester.pumpAndSettle();
      await resume(tester);
      expect(find.textContaining('Autorisation non donnée'), findsOneWidget);
      expect(bubbleSwitch(tester).value, isFalse);
    });

    testWidgets('« Annuler » : rien n’est ouvert', (tester) async {
      final shortcuts = FakeShortcuts(bubbleSupported: true);
      await pumpSafeLinkApp(tester, shortcuts: shortcuts);
      await openShortcuts(tester);
      await tester.tap(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(shortcuts.overlaySettingsOpened, 0);
      expect(bubbleSwitch(tester).value, isFalse);
    });

    testWidgets('Android 9 et avant : elle revient à chaque copie', (
      tester,
    ) async {
      final shortcuts = FakeShortcuts(
        bubbleSupported: true,
        bubbleDetectsCopies: true,
      );
      await pumpSafeLinkApp(tester, shortcuts: shortcuts);
      await openShortcuts(tester);
      await tester.tap(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
      expect(find.textContaining('revient quand vous copiez'), findsOneWidget);
      await tester.tap(find.text('Ouvrir le réglage'));
      await tester.pumpAndSettle();
      shortcuts.bubblePermitted = true;
      await resume(tester);
      expect(
        find.text(
          'Bulle activée\u00a0: elle apparaît quand vous copiez un lien ou un '
          'texte.',
        ),
        findsOneWidget,
      );
      // Elle revient d'elle-même : pas besoin des notifications.
      expect(shortcuts.notificationRequests, 0);
    });

    testWidgets('notifications refusées : la tuile est proposée', (
      tester,
    ) async {
      final shortcuts = FakeShortcuts(
        bubbleSupported: true,
        bubblePermitted: true,
        notificationsAnswer: false,
      );
      await pumpSafeLinkApp(tester, shortcuts: shortcuts);
      await openShortcuts(tester);
      await tester.tap(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
      expect(shortcuts.notificationRequests, 1);
      expect(find.textContaining('Sans notifications'), findsOneWidget);
      expect(bubbleSwitch(tester).value, isTrue);
    });

    testWidgets('notifications déjà permises : rien n’est redemandé', (
      tester,
    ) async {
      final shortcuts = FakeShortcuts(
        bubbleSupported: true,
        bubblePermitted: true,
        notificationsAllowed: true,
      );
      await pumpSafeLinkApp(tester, shortcuts: shortcuts);
      await openShortcuts(tester);
      await tester.tap(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
      expect(shortcuts.notificationRequests, 0);
      expect(
        find.textContaining('touchez la notification SafeLink'),
        findsOneWidget,
      );
    });

    testWidgets('déjà autorisée : activée tout de suite', (tester) async {
      final shortcuts = FakeShortcuts(
        bubbleSupported: true,
        bubblePermitted: true,
      );
      await pumpSafeLinkApp(tester, shortcuts: shortcuts);
      await openShortcuts(tester);
      await tester.tap(find.text('Bulle flottante'));
      await tester.pumpAndSettle();
      expect(find.text('Autoriser la bulle'), findsNothing);
      expect(bubbleSwitch(tester).value, isTrue);
    });
  });
}
