import 'dart:async';

import 'package:cupertino_fundations_models/cupertino_fundations_models_adapters.dart';
import 'package:cupertino_fundations_models/src/platform/cupertino_foundation_models_platform.dart';
import 'package:cupertino_fundations_models/src/session_event_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../example/lib/apple_text_backend.dart';
import 'src/test_helpers.dart';

Future<void> flush() async { for (var i=0;i<4;i++) { await Future<void>.delayed(Duration.zero); } }

const finalResponse = ModelResponse(text:'Hello',usedMode:ModelMode.local,
  metadata:{'request':'retained'}, usage:ModelUsage(inputTokenCount:2,outputTokenCount:null,
    cachedInputTokenCount:null,reasoningTokenCount:null,totalTokenCount:null));
const completed = CompletionEvent(requestId:'r',response:finalResponse);

final class CreatingPlatform implements CupertinoFoundationModelsPlatform {
  final FakePlatform delegate = FakePlatform();
  Completer<FoundationModelSession>? pending;
  @override
  Future<FoundationModelSession> createSession({required SessionOptions options}) async =>
    pending == null ? delegate.createSession(options:options) : pending!.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reducer appends only unchanged prefixes and replaces every revision', () {
    final reducer = TextSnapshotReducer(); var buffer='';
    for (final value in ['H','Hello','Hello','Help','He','', '😀','😀!','e','e\u0301']) {
      final update = reducer.next(value); buffer=update.applyTo(buffer);
      expect(buffer,value); expect(update.fullText,value); expect(reducer.text,value);
    }
    const replacement = TextUpdate.replace(content:'new');
    expect(replacement.kind,TextUpdateKind.replace); expect(replacement.applyTo('old'),'new');
    const append = TextUpdate.append(content:'suffix',baseText:'base');
    expect(append.fullText,'basesuffix'); expect(()=>append.applyTo('stale'),throwsStateError);
  });

  test('UTF-16 partial surrogate baselines become replacement instead of invalid deltas', () {
    final reducer = TextSnapshotReducer(initialText:'\uD83D');
    final update = reducer.next('😀');
    expect(update.kind,TextUpdateKind.replace); expect(update.content,'😀');
  });

  test('adapted stream retains all original event identities and reconciles final text', () async {
    const tool=ToolCallEvent(requestId:'r',toolCallId:'t',name:'lookup',arguments:{'x':1});
    const unknown=UnknownSessionEvent(payload:{'future':'preserved'});
    final partial=StructuredSnapshot.fromMap({'hasValue':true,'value':{'name':'known'},'isComplete':false,
      'presentPaths':['#','#/name'],'completePaths':['#/name']});
    final first=TextSnapshotEvent(requestId:'r',text:'Hi',structuredSnapshot:partial);
    final originals=<SessionEvent>[tool,unknown,first,completed];
    final values=await Stream<SessionEvent>.fromIterable(originals).adaptEvents().toList();
    expect(values,hasLength(4));
    for(var i=0;i<values.length;i++){expect(values[i].original,same(originals[i]));}
    expect(values.first.textUpdate,isNull); expect(values[1].textUpdate,isNull);
    expect((values[2].original as TextSnapshotEvent).structuredSnapshot,same(partial));
    expect(values[2].textUpdate!.kind,TextUpdateKind.append);
    expect(values.last.textUpdate!.kind,TextUpdateKind.replace);
    expect(values.last.isTerminal,true);
    final response=(values.last.original as CompletionEvent).response;
    expect(response,same(finalResponse)); expect(response.usage!.outputTokenCount,isNull);
    expect(response.termination.reason,GenerationStopReason.unknown);
  });

  test('failure events remain terminal data and unknown failure codes are not translated', () async {
    const failure=FailureEvent(requestId:'r',code:'futureFailure',message:'native',details:{'reason':'preserved'});
    final values=await Stream<SessionEvent>.value(failure).adaptEvents().toList();
    expect(values.single.original,same(failure)); expect(values.single.isTerminal,true);
    expect(values.single.textUpdate,isNull);
  });

  test('empty request IDs are retained while different known requests fail', () async {
    final values=await Stream<SessionEvent>.fromIterable(const [
      TextSnapshotEvent(requestId:'',text:''),completed,
    ]).adaptEvents().toList();
    expect(values.first.textUpdate!.content,'');
    await expectLater(Stream<SessionEvent>.fromIterable(const [
      TextSnapshotEvent(requestId:'a',text:'x'),completed,
    ]).adaptEvents().toList(),throwsA(isA<FoundationModelsException>()
      .having((error)=>error.details['adapterStage'],'stage','mixedRequests')));
  });

  test('append-only consumers fail explicitly on intermediate or final revisions', () async {
    for(final events in <List<SessionEvent>>[
      const [TextSnapshotEvent(requestId:'r',text:'Hello'),TextSnapshotEvent(requestId:'r',text:'Help'),completed],
      const [TextSnapshotEvent(requestId:'r',text:'Different'),completed],
    ]) {
      await expectLater(Stream<SessionEvent>.fromIterable(events).adaptEvents(allowReplacements:false).toList(),
        throwsA(isA<FoundationModelsException>().having((e)=>e.details['adapterStage'],'stage','textRevision')));
    }
    expect(await Stream<SessionEvent>.value(completed).adaptEvents(allowReplacements:false).toList(),hasLength(1));
  });

  test('missing terminal and source errors are not converted to successful responses', () async {
    await expectLater(const Stream<SessionEvent>.empty().adaptEvents().toList(),throwsA(isA<FoundationModelsException>()
      .having((e)=>e.details['adapterStage'],'stage','missingTerminal')));
    final error=StateError('source');
    await expectLater(Stream<SessionEvent>.error(error).adaptEvents().toList(),throwsA(same(error)));
    await expectLater(SessionEventAdapter(source:()=>throw error).stream.toList(),throwsA(same(error)));
  });

  test('pause and resume propagate to borrowed sources and cancel waits for cleanup', () async {
    var pauses=0;var resumes=0;var cancellations=0;
    final pending=Completer<void>();
    final source=StreamController<SessionEvent>(onPause:()=>pauses++,onResume:()=>resumes++,onCancel:()async{cancellations++;await pending.future;});
    addTearDown(() { unawaited(source.close()); });
    final subscription=source.stream.adaptEvents().listen((_){}); await flush();
    subscription.pause();await flush();expect(pauses,1);
    source.add(const TextSnapshotEvent(requestId:'r',text:'H'));
    subscription.resume();await flush();expect(resumes,1);
    var cancelled=false;final ending=subscription.cancel().then((_)=>cancelled=true);
    await flush();expect(cancelled,false);pending.complete();await ending;expect(cancellations,1);
  });

  test('pause during asynchronous source creation is applied before queued events', () async {
    final created=Completer<Stream<SessionEvent>>();var pauses=0;
    final source=StreamController<SessionEvent>(onPause:()=>pauses++);
    addTearDown(() { unawaited(source.close()); });
    final values=<AdaptedSessionEvent>[];
    final subscription=SessionEventAdapter(source:()=>created.future).stream.listen(values.add);
    subscription.pause();created.complete(source.stream);await flush();
    expect(pauses,1);source.add(completed);await flush();expect(values,isEmpty);
    subscription.resume();await flush();expect(values,hasLength(1));await subscription.cancel();
  });

  test('late callbacks after a terminal or error cannot reopen the adapter', () async {
    final source=StreamController<SessionEvent>(sync:true);final ending=Completer<void>();
    addTearDown(() { unawaited(source.close()); });
    final values=<AdaptedSessionEvent>[];final errors=<Object>[];
    source.stream.adaptEvents().listen(values.add,onError:errors.add,onDone:ending.complete);
    await flush();source.add(completed);source.add(const TextSnapshotEvent(requestId:'r',text:'late'));
    await ending.future;expect(values,hasLength(1));expect(errors,isEmpty);
    final failed=StreamController<SessionEvent>(sync:true);final done=Completer<void>();
    addTearDown(() { unawaited(failed.close()); });
    failed.stream.adaptEvents().listen((_)=>fail('Late data'),onError:errors.add,onDone:done.complete);
    await flush();failed.addError(StateError('first'));failed.addError(StateError('late'));failed.add(completed);
    await done.future;expect(errors,hasLength(1));
  });

  test('terminal delivery waits for disposal and explicit cancel during it suppresses success', () async {
    final dispose=Completer<void>();var disposals=0;
    final values=<AdaptedSessionEvent>[];
    final stream=SessionEventAdapter(source:()=>Stream<SessionEvent>.value(completed),dispose:()async{disposals++;await dispose.future;}).stream;
    final subscription=stream.listen(values.add);await flush();expect(values,isEmpty);
    var stopped=false;final cancel=subscription.cancel().then((_)=>stopped=true);
    await flush();expect(stopped,false);dispose.complete();await cancel;
    expect(values,isEmpty);expect(disposals,1);
  });

  test('cleanup failure is reported, owned disposal still runs and cancellation exposes failures', () async {
    var disposals=0;final error=StateError('cleanup');
    final source=StreamController<SessionEvent>(onCancel:()=>throw error);
    addTearDown(() { unawaited(source.close()); });
    final done=Completer<void>();final errors=<Object>[];
    SessionEventAdapter(source:()=>source.stream,dispose:()async{disposals++;}).stream.listen((_)=>fail('Success'),onError:errors.add,onDone:done.complete);
    await flush();source.add(completed);await done.future;expect(errors.single,same(error));expect(disposals,1);
    final source2=StreamController<SessionEvent>(onCancel:()=>throw error);
    addTearDown(() { unawaited(source2.close()); });
    final subscription=source2.stream.adaptEvents().listen((_){});await flush();
    await expectLater(subscription.cancel(),throwsA(same(error)));
  });

  group('owned Apple adapter', () {
    late FakePlatform platform;late FoundationModelsAdapter adapter;
    setUp(()=>{platform=FakePlatform(),adapter=FoundationModelsAdapter(models:CupertinoFoundationModels(platform:platform))});

    test('text and structured requests retain response and always dispose', ()async{
      platform.respondCompleter=Completer<ModelResponse>()..complete(finalResponse);
      expect(await adapter.generate(prompt:const Prompt.text('Bounded')),same(finalResponse));
      expect(platform.calls,['createSession','respond','disposeSession']);
      platform.calls.clear();
      final result=await adapter.generate(prompt:const Prompt.text('Extract'),schema:const StructuredSchema.object(name:'x',properties:{'ok':SchemaProperty.boolean()}));
      expect(result.structuredValue,{'ok':true});expect(platform.calls,['createSession','generateStructured','disposeSession']);
    });
    test('one-shot failures dispose and preserve original errors', ()async{
      final error=StateError('generation');platform.respondCompleter=Completer<ModelResponse>();
      final expectation=expectLater(adapter.generate(prompt:const Prompt.text('x')),throwsA(same(error)));
      await flush();platform.respondCompleter!.completeError(error);await expectation;
      expect(platform.disposedSessionIds,hasLength(1));
    });
    test('owned stream is cold and releases a fresh session at completion', ()async{
      final stream=adapter.stream(prompt:const Prompt.text('x'));expect(platform.calls,isEmpty);
      final result=await stream.toList();expect(result.last.original,isA<CompletionEvent>());
      expect(platform.calls,['createSession','stream','disposeSession']);
    });
    test('example app boundary delegates without selecting or replaying external providers', ()async{
      final backend=AppleTextBackend(models:CupertinoFoundationModels(platform:platform));
      expect(backend.sessionOptions.mode,ModelMode.local);expect(backend.sessionOptions.cloudPolicy,CloudPolicy.never);
      expect((await backend.generate(const Prompt.text('supplied'))).text,'response');
      expect((await backend.stream(const Prompt.text('supplied')).toList()).last.isTerminal,true);
      expect(platform.disposedSessionIds,hasLength(2));
    });
    test('owned cancel stops native work before disposal, borrowed adapters preserve the session', ()async{
      platform.controlledSessionStream=StreamController<SessionEvent>().stream;
      final subscription=adapter.stream(prompt:const Prompt.text('x')).listen((_){});await flush();await subscription.cancel();
      expect(platform.calls,['createSession','stream','cancelActiveRequest','disposeSession']);
      platform.calls.clear();platform.controlledSessionStream=StreamController<SessionEvent>().stream;
      final session=await CupertinoFoundationModels(platform:platform).createSession();
      final borrowed=session.stream(const Prompt.text('x')).adaptEvents().listen((_){});await flush();await borrowed.cancel();
      expect(platform.disposedSessionIds,hasLength(1));await session.dispose();
    });
    test('cancel during pending session creation avoids generation and disposes once ready', ()async{
      final creating=CreatingPlatform()..pending=Completer<FoundationModelSession>();
      final instance=FoundationModelsAdapter(models:CupertinoFoundationModels(platform:creating));
      final sub=instance.stream(prompt:const Prompt.text('x')).listen((_){});await flush();
      var stopped=false;final cancel=sub.cancel().then((_)=>stopped=true);await flush();expect(stopped,false);
      creating.pending!.complete(await creating.delegate.createSession(options:const SessionOptions(mode:ModelMode.local)));
      await cancel;expect(creating.delegate.calls,['createSession','disposeSession']);
    });
    test('native cancellation failures are exposed and owned sessions still disposed', ()async{
      platform.controlledSessionStream=StreamController<SessionEvent>().stream;
      platform.cancelError=const FoundationModelsException(code:FoundationModelsErrorCode.nativeFailure,message:'stop failed');
      final sub=adapter.stream(prompt:const Prompt.text('x')).listen((_){});await flush();
      await expectLater(sub.cancel(),throwsA(same(platform.cancelError)));expect(platform.disposedSessionIds,hasLength(1));
    });
  });
}
