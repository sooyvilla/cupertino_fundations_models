import '../availability.dart';
import '../session.dart';
import '../text_model_language.dart';

/// Optional internal text-model support, preserving existing platform adapters.
abstract interface class FoundationModelsAvailabilityPlatform {
  /// Queries the selected local variant without Speech or asset requests.
  Future<List<TextModelLanguage>> getTextModelLanguages({required FoundationModelsUseCase useCase});

  /// Watches local readiness using Observation or explicit bounded polling.
  Stream<ModelAvailability> watchAvailability({required FoundationModelsUseCase useCase,
    required String? localeIdentifier, required Duration? pollingInterval});
}
