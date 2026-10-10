import 'package:cupertino_fundations_models/cupertino_fundations_models_adapters.dart';

/// App-owned boundary for Apple requests; external providers can have separate implementations.
abstract interface class AppTextBackend {
  /// Retains the provider response rather than flattening metadata to a string.
  Future<ModelResponse> generate(Prompt prompt);
  /// Retains terminal/tool/snapshot events and append/replacement semantics.
  Stream<AdaptedSessionEvent> stream(Prompt prompt);
}
