import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:subiquity_client/subiquity_client.dart';
import 'package:ubuntu_service/ubuntu_service.dart';
import 'package:ubuntu_test/mocks.dart';
import 'package:ubuntu_wizard/widgets.dart';
import 'package:ubuntu_wsl_setup/l10n.dart';
import 'package:ubuntu_wsl_setup/pages.dart';
import 'package:ubuntu_wsl_setup/pages/applying_changes/applying_changes_model.dart';

import 'applying_changes_page_test.mocks.dart';
import 'test_utils.dart';

// ignore_for_file: type=lint

@GenerateMocks([ApplyingChangesModel])
void main() {
  const theEnd = 'The end';
  LangTester.type = ApplyingChangesModel;

  Widget buildPage(ApplyingChangesModel model) {
    return ChangeNotifierProvider<ApplyingChangesModel>.value(
      value: model,
      child: ApplyingChangesPage(),
    );
  }

  Widget buildApp({
    required Widget Function(BuildContext) builder,
    bool hasNext = false,
  }) {
    return MaterialApp(
      localizationsDelegates: localizationsDelegates,
      home: Wizard(
        routes: {
          '/': WizardRoute(
            builder: builder,
            onNext: (settings) => '/end',
          ),
          if (hasNext)
            '/end': WizardRoute(
              builder: (_) => Center(
                child: const Text(theEnd),
              ),
              onNext: (settings) => '/end',
            ),
        },
      ),
    );
  }

  testWidgets('closes the window', (tester) async {
    final model = MockApplyingChangesModel();
    when(model.init())
        .thenAnswer((_) async => Future.delayed(const Duration(seconds: 2)));

    var windowClosed = false;
    final methodChannel = MethodChannel('yaru_window');
    methodChannel.setMockMethodCallHandler((call) async {
      expect(call.method, equals('close'));
      windowClosed = true;
    });

    await tester.pumpWidget(buildApp(
      builder: (_) => buildPage(model),
      hasNext: false,
    ));

    expect(windowClosed, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(windowClosed, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(windowClosed, isTrue);
  });

  testWidgets('won\'t go next while still installing', (tester) async {
    final model = MockApplyingChangesModel();
    when(model.init()).thenAnswer((realInvocation) async {});
    await tester.pumpWidget(buildApp(
      builder: (_) => buildPage(model),
      hasNext: true,
    ));
    expect(find.text(theEnd), findsNothing);
    await tester.pump(Duration.zero);
    expect(find.text(theEnd), findsNothing);
    await tester.pump(Duration.zero);
    expect(find.text(theEnd), findsNothing);
  });

  testWidgets('creates a model', (tester) async {
    final client = MockSubiquityClient();
    final monitor = MockSubiquityStatusMonitor();
    when(monitor.onStatusChanged).thenAnswer((_) => Stream.value(null));
    when(monitor.status).thenAnswer((_) => null);
    registerMockService<SubiquityClient>(client);
    registerMockService<SubiquityStatusMonitor>(monitor);
    await tester.pumpWidget(buildApp(
      builder: ApplyingChangesPage.create,
      hasNext: true,
    ));
    final page = find.byType(ApplyingChangesPage);
    expect(page, findsOneWidget);

    final context = tester.element(page);
    final model = Provider.of<ApplyingChangesModel>(context, listen: false);
    expect(model, isNotNull);
  });
}
