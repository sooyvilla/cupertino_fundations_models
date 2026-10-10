/// Native Apple language generation, guided data, tools and speech for Flutter.
///
/// Start with `CupertinoFoundationModels`, check native availability, then use
/// a one-shot request or an owned `FoundationModelSession`. Local is the default
/// privacy policy. Eligible hardware, system settings and model assets remain
/// required even when the plugin can load on an older operating system.
library;

export 'src/availability.dart';
export 'src/cupertino_foundation_models.dart';
export 'src/decoded_model_response.dart';
export 'src/errors.dart';
export 'src/file_selection.dart';
export 'src/generation.dart';
export 'src/generation_diagnostic_event.dart';
export 'src/generation_diagnostics.dart';
export 'src/generation_termination.dart';
export 'src/schema.dart';
export 'src/session.dart';
export 'src/session_history.dart';
export 'src/session_history_entry.dart';
export 'src/session_history_segment.dart';
export 'src/session_history_tool_call.dart';
export 'src/structured_decoding_exception.dart';
export 'src/structured_field.dart';
export 'src/structured_model.dart';
export 'src/structured_partial_field.dart';
export 'src/structured_snapshot.dart';
export 'src/structured_value_reader.dart';
export 'src/text_model_language.dart';
export 'src/token_budget.dart';
export 'src/token_measurement.dart';
export 'src/tools.dart';
export 'src/transcription.dart';
