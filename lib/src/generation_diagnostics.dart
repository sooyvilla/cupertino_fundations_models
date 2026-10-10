import 'generation_diagnostic_event.dart';

/// Optional per-request diagnostics with output capture disabled by default.
///
/// The callback runs in the application and owns any logging or retention.
/// Callback failures do not interrupt generation. Enabling [captureOutput]
/// may expose user content, so apply the app's data policy before enabling it.
final class GenerationDiagnostics {
  /// Configures the callback and a maximum length for exact captured output.
  const GenerationDiagnostics({
    required this.onEvent,
    this.captureOutput = false,
    this.maximumOutputCharacters = 65536,
  });

  /// Receives lifecycle metadata and optionally bounded output.
  final void Function(GenerationDiagnosticEvent event) onEvent;

  /// Whether response strings may be included in diagnostic events.
  final bool captureOutput;

  /// Maximum captured string length in Dart UTF-16 code units.
  ///
  /// A longer string is omitted entirely rather than truncated. Must be positive.
  final int maximumOutputCharacters;
}
