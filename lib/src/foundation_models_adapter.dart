import 'adapted_session_event.dart';
import 'availability.dart';
import 'cupertino_foundation_models.dart';
import 'generation.dart';
import 'schema.dart';
import 'session.dart';
import 'session_event_adapter.dart';

/// Optional app-interface adapter over Apple requests with explicit session ownership.
/// It does not select external providers, replay history or invent usage counters.
final class FoundationModelsAdapter {
  /// Uses the supplied facade, normally the app's existing shared instance.
  const FoundationModelsAdapter({required CupertinoFoundationModels models}) : _models = models;
  final CupertinoFoundationModels _models;

  /// Creates/disposes a session for one text or guided response, retaining it by identity.
  Future<ModelResponse> generate({required Prompt prompt, StructuredSchema? schema,
    SessionOptions sessionOptions = const SessionOptions(mode: ModelMode.local),
    GenerationOptions options = const GenerationOptions()}) async {
    final session = await _models.createSession(options: sessionOptions);
    try {
      return schema == null ? await session.respond(prompt, options: options)
        : await session.generateStructured(prompt: prompt, schema: schema, options: options);
    } finally { await session.dispose(); }
  }

  /// Starts one cold owned stream with lossless text operations and original events.
  /// Pause propagates to the source; existing native deadlines continue to apply.
  /// Cancel waits for pending creation, native cleanup and disposal. No work starts on creation.
  Stream<AdaptedSessionEvent> stream({required Prompt prompt, StructuredSchema? schema,
    SessionOptions sessionOptions = const SessionOptions(mode: ModelMode.local),
    GenerationOptions options = const GenerationOptions(), bool allowReplacements = true}) {
    FoundationModelSession? session;
    return SessionEventAdapter(source: () async {
      session = await _models.createSession(options: sessionOptions);
      return session!.stream(prompt, schema: schema, options: options);
    }, dispose: () async { await session?.dispose(); }, allowReplacements: allowReplacements).stream;
  }
}
