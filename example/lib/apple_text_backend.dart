import 'package:cupertino_fundations_models/cupertino_fundations_models_adapters.dart';

import 'app_text_backend.dart';

/// Optional app-interface implementation with explicit Apple session policy.
final class AppleTextBackend implements AppTextBackend {
  /// Shares the app facade; local/never remains the default.
  AppleTextBackend({required CupertinoFoundationModels models,
    this.sessionOptions = const SessionOptions(mode: ModelMode.local)})
    : _adapter = FoundationModelsAdapter(models: models);
  final FoundationModelsAdapter _adapter;
  /// App-chosen route, instructions, tools, locale and optional native history.
  final SessionOptions sessionOptions;
  @override
  Future<ModelResponse> generate(Prompt prompt) => _adapter.generate(prompt: prompt, sessionOptions: sessionOptions);
  @override
  Stream<AdaptedSessionEvent> stream(Prompt prompt) => _adapter.stream(prompt: prompt, sessionOptions: sessionOptions);
}
