import 'generation.dart';
import 'text_update.dart';

/// A bridge event retained by identity, with optional lossless text adaptation.
final class AdaptedSessionEvent {
  /// Pairs the original native event with an append/replacement operation.
  const AdaptedSessionEvent({required this.original, this.textUpdate});
  /// Original event with tools, structured snapshots, response/usage and errors intact.
  /// Observed tool calls are data; the core already owns their execution.
  final SessionEvent original;
  /// Text operation for snapshots and final response reconciliation, otherwise null.
  final TextUpdate? textUpdate;
  /// Whether the original event is a completion or native failure.
  bool get isTerminal => original is CompletionEvent || original is FailureEvent;
}
