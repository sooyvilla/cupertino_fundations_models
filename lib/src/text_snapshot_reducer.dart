import 'text_update.dart';

/// Derives append or replacement operations from cumulative native text.
final class TextSnapshotReducer {
  /// Starts one request with an optional already displayed baseline.
  TextSnapshotReducer({String initialText = ''}) : _previous = initialText;
  String _previous;
  /// Latest authoritative cumulative text.
  String get text => _previous;

  /// Preserves revisions and avoids splitting a UTF-16 surrogate pair into a delta.
  TextUpdate next(String snapshot) {
    final boundary = _previous.isEmpty ? 0 : _previous.codeUnitAt(_previous.length - 1);
    final safe = boundary < 0xD800 || boundary > 0xDBFF;
    final update = safe && snapshot.startsWith(_previous)
      ? TextUpdate.append(content: snapshot.substring(_previous.length), baseText: _previous)
      : TextUpdate.replace(content: snapshot);
    _previous = snapshot;
    return update;
  }
}
