import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:cupertino_fundations_models/src/platform/cupertino_foundation_models_platform.dart';
import 'package:cupertino_fundations_models/src/platform/foundation_models_availability_platform.dart';
import 'package:cupertino_fundations_models/src/platform/method_channel_cupertino_foundation_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/main.dart' as chat;
import 'src/test_helpers.dart';

ModelAvailability readiness(AvailabilityStatus status, {Map<String, Object?> details = const {}}) => ModelAvailability(
  mode: ModelMode.local, status: status, isAvailable: status == AvailabilityStatus.available,
  supportsFullPower: false, details: details,
);

Future<void> flush() async {
  for (var i = 0; i < 4; i++) { await Future<void>.delayed(Duration.zero); }
}

final class AvailabilityTestPlatform implements CupertinoFoundationModelsPlatform, FoundationModelsAvailabilityPlatform {
  final sources = <StreamController<ModelAvailability>>[];
  Object? startError;
  Object? cancelError;
  Future<void>? cancelWait;
  bool synchronous = false;
  Stream<ModelAvailability>? special;
  int cancellations = 0;

  @override
  Stream<ModelAvailability> watchAvailability({required FoundationModelsUseCase useCase,
    required String? localeIdentifier, required Duration? pollingInterval}) {
    // ignore: only_throw_errors
    if (startError != null) throw startError!;
    if (special != null) return special!;
    final source = StreamController<ModelAvailability>(sync: synchronous, onCancel: () async {
      cancellations++;
      await cancelWait;
      // ignore: only_throw_errors
      if (cancelError != null) throw cancelError!;
    });
    sources.add(source);
    return source.stream;
  }

  @override
  Future<List<TextModelLanguage>> getTextModelLanguages({required FoundationModelsUseCase useCase}) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

  test('text language labels serialize independently of Speech and preserve script IDs', () {
    final language = TextModelLanguage.fromMap({'identifier': 'zh-Hans', 'languageCode': 'zh',
      'displayName': 'Chinese', 'nativeDisplayName': '中文'});
    expect(TextModelLanguage.fromMap(language.toMap()).toMap(), language.toMap());
    expect(language.identifier, 'zh-Hans'); expect(language.languageCode, 'zh');
    expect(language.displayName, 'Chinese'); expect(language.nativeDisplayName, '中文');
    expect(language.toMap().containsKey('isTranscriptionAssetInstalled'), false);
    expect(TextModelLanguage.fromMap({}).identifier, 'und');
    expect(TextModelLanguage.fromMap({'identifier': 'es', 'displayName': 'Spanish'}).nativeDisplayName, 'Spanish');
  });

  test('older adapters remain valid and reject optional monitoring capabilities', () async {
    final models = CupertinoFoundationModels(platform: FakePlatform());
    expect(models.getTextModelLanguages, throwsA(isA<FoundationModelsException>()
      .having((error) => error.code, 'code', FoundationModelsErrorCode.unsupportedCapability)));
    await expectLater(models.watchAvailability(), emitsError(isA<FoundationModelsException>()));
    expect((await models.checkAvailability()).isAvailable, true);
  });

  test('polling interval must be explicitly bounded before subscription', () async {
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    for (final interval in [Duration.zero, const Duration(microseconds: -1), const Duration(milliseconds: 999), const Duration(minutes: 6)]) {
      expect(() => models.watchAvailability(pollingInterval: interval), throwsArgumentError);
    }
    expect(platform.sources, isEmpty);
    expect(await models.getTextModelLanguages(useCase: FoundationModelsUseCase.contentTagging), isEmpty);
    for (final interval in [const Duration(seconds: 1), const Duration(minutes: 5)]) {
      final subscription = models.watchAvailability(pollingInterval: interval, pauseWhenBackgrounded: false).listen((_) {});
      await flush(); await subscription.cancel();
    }
  });

  test('cold observation deduplicates full snapshots structurally and freezes listener state', () async {
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    final stream = models.watchAvailability(); expect(platform.sources, isEmpty);
    final values = <ModelAvailability>[]; final subscription = stream.listen(values.add);
    await flush(); final source = platform.sources.single;
    addTearDown(() { unawaited(source.close()); });
    final details = <String, Object?>{'b': [false], 'a': {'ready': 0}};
    source.add(readiness(AvailabilityStatus.assetsUnavailable, details: details)); await flush();
    details.clear();
    source.add(readiness(AvailabilityStatus.assetsUnavailable, details: {'a': {'ready': 0}, 'b': [false]})); await flush();
    expect(values, hasLength(1)); expect(values.single.details.clear, throwsUnsupportedError);
    expect((values.single.details['b']! as List<Object?>).clear, throwsUnsupportedError);
    source.add(readiness(AvailabilityStatus.available)); await flush();
    expect(values.map((value) => value.status), [AvailabilityStatus.assetsUnavailable, AvailabilityStatus.available]);
    await subscription.cancel(); expect(platform.cancellations, 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused); binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush(); expect(platform.sources, hasLength(1));
  });

  test('subscription pause stops native work and resume rechecks without duplicates', () async {
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    final values = <ModelAvailability>[]; final subscription = models.watchAvailability().listen(values.add);
    await flush(); platform.sources.last.add(readiness(AvailabilityStatus.available)); await flush();
    subscription.pause(); await flush(); expect(platform.cancellations, 1);
    subscription.resume(); await flush(); expect(platform.sources, hasLength(2));
    platform.sources.last.add(readiness(AvailabilityStatus.available)); await flush(); expect(values, hasLength(1));
    platform.sources.last.add(readiness(AvailabilityStatus.appleIntelligenceDisabled)); await flush(); expect(values, hasLength(2));
    await subscription.cancel();
  });

  test('background suspension discards stale callbacks and refreshes the selected stream', () async {
    final platform = AvailabilityTestPlatform()..synchronous = true;
    final values = <ModelAvailability>[];
    final subscription = CupertinoFoundationModels(platform: platform).watchAvailability().listen(values.add);
    await flush(); final old = platform.sources.last;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    old.add(readiness(AvailabilityStatus.available)); old.addError(StateError('stale')); unawaited(old.close());
    await flush(); expect(values, isEmpty); expect(platform.cancellations, 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush(); platform.sources.last.add(readiness(AvailabilityStatus.assetsUnavailable)); await flush();
    expect(values.single.status, AvailabilityStatus.assetsUnavailable);
    await subscription.cancel();
  });

  test('starting in background waits for foreground and cancellation during suspension is final', () async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    final subscription = models.watchAvailability().listen((_) {});
    await flush(); expect(platform.sources, isEmpty);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); await flush();
    expect(platform.sources, hasLength(1));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden); await flush();
    await subscription.cancel();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); await flush();
    expect(platform.sources, hasLength(1));
  });

  test('background handling is optional for callers that own their lifecycle', () async {
    final platform = AvailabilityTestPlatform();
    final subscription = CupertinoFoundationModels(platform: platform).watchAvailability(pauseWhenBackgrounded: false).listen((_) {});
    await flush(); binding.handleAppLifecycleStateChanged(AppLifecycleState.paused); await flush();
    expect(platform.cancellations, 0); await subscription.cancel();
  });

  test('source completion releases the observer and synchronous startup errors stay typed', () async {
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    final done = Completer<void>(); final subscription = models.watchAvailability().listen((_) {}, onDone: done.complete);
    await flush(); await platform.sources.single.close(); await done.future;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive); binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await flush(); expect(platform.sources, hasLength(1)); await subscription.cancel();
    platform.startError = const FoundationModelsException(code: FoundationModelsErrorCode.unsupportedCapability, message: 'not exposed');
    await expectLater(models.watchAvailability(), emitsError(isA<FoundationModelsException>()));
  });

  test('unsupported host becomes one unavailable state and then closes', () async {
    final platform = AvailabilityTestPlatform()..startError = const FoundationModelsException(
      code: FoundationModelsErrorCode.unsupportedPlatform, message: 'No backend', recoverySuggestion: 'Use Apple');
    final values = await CupertinoFoundationModels(platform: platform).watchAvailability().toList();
    expect(values.single.status, AvailabilityStatus.unsupportedPlatform);
    expect(values.single.isAvailable, false); expect(values.single.recoverySuggestion, 'Use Apple');
  });

  test('source errors and invalid snapshots terminate rather than fabricate readiness', () async {
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    final errors = <Object>[]; final done = Completer<void>();
    models.watchAvailability().listen((_) {}, onError: errors.add, onDone: done.complete);
    await flush(); platform.sources.last.addError(StateError('bridge failed')); await done.future;
    expect(errors.single, isA<StateError>());
    final malformed = Completer<void>();
    models.watchAvailability().listen((_) {}, onError: errors.add, onDone: malformed.complete);
    await flush(); platform.sources.last.add(readiness(AvailabilityStatus.available, details: {'private': DateTime(2026)}));
    await malformed.future;
    expect(errors.last, isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.parsingFailure));
  });

  test('cancellation failure is surfaced and cannot restart suspended work', () async {
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    final errors = <Object>[]; final done = Completer<void>();
    models.watchAvailability().listen((_) {}, onError: errors.add, onDone: done.complete);
    await flush(); platform.cancelError = StateError('stop failed');
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused); await done.future;
    expect(errors.single, isA<StateError>());
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); await flush();
    expect(platform.sources, hasLength(1));
  });

  test('error settlement immediately ignores further synchronous frames and releases work', () async {
    final platform = AvailabilityTestPlatform()..synchronous = true;
    final values = <ModelAvailability>[]; final errors = <Object>[]; final done = Completer<void>();
    CupertinoFoundationModels(platform: platform).watchAvailability().listen(values.add, onError: errors.add, onDone: done.complete);
    await flush();
    platform.sources.last.addError(StateError('failure'));
    platform.sources.last.add(readiness(AvailabilityStatus.available));
    platform.sources.last.addError(StateError('late failure'));
    await done.future;
    expect(values, isEmpty); expect(errors, hasLength(1)); expect(platform.cancellations, 1);
  });

  test('explicit cancellation exposes cleanup errors while error completion reports them once', () async {
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    final subscription = models.watchAvailability().listen((_) {}); await flush();
    platform.cancelError = StateError('cleanup failed');
    await expectLater(subscription.cancel(), throwsStateError);
    final errors = <Object>[]; final done = Completer<void>();
    models.watchAvailability().listen((_) {}, onError: errors.add, onDone: done.complete); await flush();
    platform.sources.last.addError(StateError('source failed')); await done.future;
    expect(errors, hasLength(2));
  });

  test('cancel while background cleanup is pending still reports its failure', () async {
    final platform = AvailabilityTestPlatform(); final models = CupertinoFoundationModels(platform: platform);
    final subscription = models.watchAvailability().listen((_) {}); await flush();
    final pending = Completer<void>(); platform.cancelWait = pending.future;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused); await flush();
    platform.cancelError = StateError('pending stop failed');
    final assertion = expectLater(subscription.cancel(), throwsStateError);
    pending.complete(); await assertion;
  });

  test('cancel after a source failure still awaits and exposes pending stop failure', () async {
    final platform = AvailabilityTestPlatform()..synchronous = true;
    final errors = <Object>[];
    final subscription = CupertinoFoundationModels(platform: platform).watchAvailability().listen((_) {}, onError: errors.add);
    await flush(); final pending = Completer<void>(); platform.cancelWait = pending.future;
    platform.sources.last.addError(StateError('source failed')); await flush();
    platform.cancelError = StateError('stop failed');
    final assertion = expectLater(subscription.cancel(), throwsStateError);
    pending.complete(); await assertion; expect(errors, hasLength(1));
  });

  testWidgets('chat updates its existing readiness banner and disposes its watch', (tester) async {
    const channel = MethodChannel('cupertino_fundations_models/methods');
    const codec = StandardMethodCodec();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getSupportedLanguages') return <Object?>[];
      if (call.method == 'checkAvailability') return readiness(AvailabilityStatus.assetsUnavailable).toMap();
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(const chat.ExampleApp()); await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsOneWidget);
    final original = calls.singleWhere((call) => call.method == 'startAvailabilityWatch').arguments as Map<Object?, Object?>;
    await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    final request = calls.lastWhere((call) => call.method == 'startAvailabilityWatch').arguments as Map<Object?, Object?>;
    expect(request['watchId'], isNot(original['watchId']));
    Future<void> send(Object? id, Object? snapshot) async {
      final reply = Completer<ByteData?>();
      await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('availabilityEvent', {
        'watchId': id, 'availability': snapshot,
      })), reply.complete); await reply.future; await tester.pumpAndSettle();
    }
    await send(original['watchId'], readiness(AvailabilityStatus.available).toMap());
    expect(find.byType(MaterialBanner), findsOneWidget);
    await send(request['watchId'], readiness(AvailabilityStatus.available).toMap());
    expect(find.byType(MaterialBanner), findsNothing);
    expect(calls.any((call) => ['createSession', 'respond', 'getTextModelLanguages'].contains(call.method)), false);
    await send(request['watchId'], {'mode': 'privateCloudCompute'});
    expect(find.byType(MaterialBanner), findsOneWidget);
    expect(find.textContaining('payload is malformed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'stopAvailabilityWatch'), hasLength(2));
  });

  group('native transport isolation and payloads', () {
    const channel = MethodChannel('test/local-availability');
    const codec = StandardMethodCodec();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls; late CupertinoFoundationModels models;
    Future<void> event(String id, Object? snapshot, {bool terminal = false}) async {
      final reply = Completer<ByteData?>();
      await messenger.handlePlatformMessage(channel.name, codec.encodeMethodCall(MethodCall('availabilityEvent', {
        'watchId': id, 'availability': snapshot, 'isTerminal': terminal,
      })), reply.complete); await reply.future;
    }
    String lastId() => (calls.lastWhere((call) => call.method == 'startAvailabilityWatch').arguments as Map<Object?, Object?>)['watchId']! as String;
    setUp(() {
      calls = []; models = CupertinoFoundationModels(platform: MethodChannelCupertinoFoundationModels(methodChannel: channel));
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getTextModelLanguages') return [{'identifier': 'es', 'languageCode': 'es', 'displayName': 'Spanish', 'nativeDisplayName': 'español'}];
        if (call.method == 'getSupportedLanguages') return <Object?>[];
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('text-only languages preserve independent Speech contract and selected variant', () async {
      final languages = await models.getTextModelLanguages(useCase: FoundationModelsUseCase.contentTagging);
      expect(languages.single.identifier, 'es'); expect(languages.clear, throwsUnsupportedError);
      expect((calls.last.arguments as Map<Object?, Object?>)['useCase'], 'contentTagging');
      expect(await models.getSupportedLanguages(), isEmpty);
      expect(calls.map((call) => call.method), ['getTextModelLanguages', 'getSupportedLanguages']);
    });

    for (final raw in [null, <String, Object?>{}, [7], [{'identifier': 7}]]) {
      test('malformed text language response fails: $raw', () async {
        messenger.setMockMethodCallHandler(channel, (_) async => raw);
        await expectLater(models.getTextModelLanguages(), throwsA(isA<FoundationModelsException>()
          .having((error) => error.code, 'code', FoundationModelsErrorCode.parsingFailure)));
      });
    }

    test('simultaneous watchers have independent IDs, locales and cleanup', () async {
      final a = <ModelAvailability>[]; final b = <ModelAvailability>[];
      final first = models.watchAvailability(localeIdentifier: 'es_CO').listen(a.add); await flush(); final idA = lastId();
      final second = models.watchAvailability(useCase: FoundationModelsUseCase.contentTagging,
        pollingInterval: const Duration(seconds: 15)).listen(b.add); await flush(); final idB = lastId();
      expect(idA, isNot(idB)); expect((calls.last.arguments as Map<Object?, Object?>)['pollingIntervalMs'], 15000);
      expect((calls.first.arguments as Map<Object?, Object?>)['localeIdentifier'], 'es_CO');
      expect((calls.first.arguments as Map<Object?, Object?>).containsKey('pollingIntervalMs'), false);
      await event(idA, readiness(AvailabilityStatus.assetsUnavailable).toMap());
      await event(idB, readiness(AvailabilityStatus.available).toMap()); await flush();
      expect(a.single.status, AvailabilityStatus.assetsUnavailable); expect(b.single.status, AvailabilityStatus.available);
      await first.cancel(); await event(idA, readiness(AvailabilityStatus.available).toMap());
      await event('unknown', null); await flush(); expect(a, hasLength(1));
      await second.cancel(); expect(calls.where((call) => call.method == 'stopAvailabilityWatch'), hasLength(2));
      expect(calls.any((call) => ['createSession', 'respond', 'getCapabilities', 'getSupportedLanguages', 'checkAvailability'].contains(call.method)), false);
    });

    test('native unsupported runtime is an initial terminal availability snapshot', () async {
      final pending = models.watchAvailability().toList(); await flush();
      await event(lastId(), readiness(AvailabilityStatus.unsupportedOsVersion).toMap(), terminal: true);
      expect((await pending).single.status, AvailabilityStatus.unsupportedOsVersion);
    });

    test('back-to-back terminal and corrupt callbacks stop once and ignore later frames', () async {
      final pending = models.watchAvailability().toList(); await flush(); final id = lastId();
      await Future.wait([
        event(id, readiness(AvailabilityStatus.unsupportedOsVersion).toMap(), terminal: true),
        event(id, null), event(id, readiness(AvailabilityStatus.available).toMap()),
      ]);
      expect((await pending).single.status, AvailabilityStatus.unsupportedOsVersion);
      expect(calls.where((call) => call.method == 'stopAvailabilityWatch'), hasLength(1));
      final errors = <Object>[]; final done = Completer<void>();
      models.watchAvailability().listen((_) {}, onError: errors.add, onDone: done.complete); await flush(); final corruptId = lastId();
      await Future.wait([event(corruptId, null), event(corruptId, readiness(AvailabilityStatus.available).toMap())]);
      await done.future; expect(errors, hasLength(1));
    });

    test('plugin absence returns availability state while other start failures remain errors', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => throw MissingPluginException());
      expect((await models.watchAvailability().toList()).single.status, AvailabilityStatus.unsupportedPlatform);
      messenger.setMockMethodCallHandler(channel, (_) async => throw PlatformException(code: 'invalidRequest'));
      await expectLater(models.watchAvailability(), emitsError(isA<FoundationModelsException>()
        .having((error) => error.code, 'code', FoundationModelsErrorCode.invalidRequest)));
    });

    test('cancel during pending start awaits acknowledgement then native cleanup', () async {
      final started = Completer<void>(); final pending = Completer<Object?>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call); if (call.method == 'startAvailabilityWatch') { started.complete(); return pending.future; }
        return null;
      });
      final subscription = models.watchAvailability().listen((_) {}); await started.future;
      var finished = false; final cancelling = subscription.cancel().then((_) => finished = true);
      await flush(); expect(finished, false); pending.complete(null); await cancelling;
      expect(calls.last.method, 'stopAvailabilityWatch');
    });

    for (final raw in [null, {'mode': 'local'}, {...availabilityMap(), 'mode': 'privateCloudCompute'}, {...availabilityMap(), 'contextSize': 'bad'}]) {
      test('malformed availability payload fails and cleans up: $raw', () async {
        final errors = <Object>[]; final done = Completer<void>();
        models.watchAvailability().listen((_) {}, onError: errors.add, onDone: done.complete);
        await flush(); await event(lastId(), raw); await done.future;
        expect(errors.single, isA<FoundationModelsException>().having((error) => error.code, 'code', FoundationModelsErrorCode.parsingFailure));
        expect(calls.last.method, 'stopAvailabilityWatch');
      });
    }
  });
}
