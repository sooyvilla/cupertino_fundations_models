import 'dart:async';

/// Function exposed to the model as a callable tool.
abstract interface class ModelTool {
  /// Unique non-empty name used by the native model to select this tool.
  String get name;

  /// Concise guidance on what the tool does and when the model should use it.
  String get description;

  /// Supported object-root parameter schema, including native constraints.
  Map<String, Object?> get parameters;

  /// Maximum time the package waits; it cannot stop arbitrary Dart work.
  Duration get timeout;

  /// Handles one invocation; the app validates arguments and authorizes effects.
  ///
  /// Return a bounded, channel-safe value. Cancellation does not undo effects,
  /// so mutating tools should apply the app's idempotency and consent policy.
  FutureOr<Object?> call(Map<String, Object?> arguments);
}

/// Immutable tool declaration sent to the native model.
final class ToolDefinition {
  /// Creates the declaration used when registering tools for a session.
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    this.timeout = const Duration(seconds: 20),
  });

  /// Copies the public registration metadata from an application tool.
  factory ToolDefinition.fromTool(ModelTool tool) {
    return ToolDefinition(
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters,
      timeout: tool.timeout,
    );
  }

  /// Unique tool identifier.
  final String name;
  /// Model-facing description of the tool's purpose.
  final String description;
  /// Native object schema for the tool's arguments.
  final Map<String, Object?> parameters;
  /// Maximum wait for the Dart callback, between 1 ms and 10 minutes.
  final Duration timeout;

  /// Serializes metadata, rejecting an empty name or invalid timeout.
  Map<String, Object?> toMap() {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Cannot be empty.');
    }
    if (timeout.inMilliseconds < 1 || timeout > const Duration(minutes: 10)) {
      throw ArgumentError.value(
        timeout,
        'timeout',
        'Must be between 1 millisecond and 10 minutes.',
      );
    }
    return <String, Object?>{
      'name': name,
      'description': description,
      'parameters': parameters,
      'timeoutMilliseconds': timeout.inMilliseconds,
    };
  }
}

/// A tool invocation requested by the native model.
final class ToolCall {
  /// Creates an invocation descriptor without executing the tool.
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  /// Native identifier of this invocation.
  final String id;
  /// Name of the registered tool requested by the model.
  final String name;
  /// Arguments to validate before executing application behavior.
  final Map<String, Object?> arguments;
}

/// The result returned to the model after a tool invocation.
final class ToolResult {
  /// Creates a successful result whose value must remain channel-safe.
  const ToolResult.success(this.value) : isError = false, message = null;

  /// Creates a failure description for the native tool bridge.
  const ToolResult.failure(this.message) : isError = true, value = null;

  /// Whether the callback failed rather than returning application data.
  final bool isError;
  /// Callback result on success, otherwise null.
  final Object? value;
  /// Failure description, otherwise null.
  final String? message;

  /// Serializes the outcome for the native tool bridge.
  Map<String, Object?> toMap() {
    return <String, Object?>{
      'isError': isError,
      'value': value,
      'message': message,
    };
  }
}
