import '../session_history.dart';

/// Optional internal history capability, preserving existing platform implementers.
/// Implementers also accept compatible SessionOptions.history in createSession.
abstract interface class FoundationModelsHistoryPlatform {
  /// Exports a supported idle native session without running generation.
  Future<SessionHistory> exportSessionHistory({required String sessionId});
}
