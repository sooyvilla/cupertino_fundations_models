import 'generation_diagnostic_event.dart';

final class GenerationDiagnostics {
  const GenerationDiagnostics({
    required this.onEvent,
    this.captureOutput = false,
    this.maximumOutputCharacters = 65536,
  });

  final void Function(GenerationDiagnosticEvent event) onEvent;
  final bool captureOutput;
  final int maximumOutputCharacters;
}
