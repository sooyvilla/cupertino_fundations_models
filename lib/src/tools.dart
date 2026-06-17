import 'dart:async';

/// Function exposed to the model as a callable tool.
abstract interface class ModelTool {
  String get name;

  String get description;

  Map<String, Object?> get parameters;

  Duration get timeout;

  FutureOr<Object?> call(Map<String, Object?> arguments);
}

/// Immutable tool declaration sent to the native model.
final class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
    this.timeout = const Duration(seconds: 20),
  });

  factory ToolDefinition.fromTool(ModelTool tool) {
    return ToolDefinition(
      name: tool.name,
      description: tool.description,
      parameters: tool.parameters,
      timeout: tool.timeout,
    );
  }

  final String name;
  final String description;
  final Map<String, Object?> parameters;
  final Duration timeout;

  Map<String, Object?> toMap() {
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
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, Object?> arguments;
}

/// The result returned to the model after a tool invocation.
final class ToolResult {
  const ToolResult.success(this.value) : isError = false, message = null;

  const ToolResult.failure(this.message) : isError = true, value = null;

  final bool isError;
  final Object? value;
  final String? message;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'isError': isError,
      'value': value,
      'message': message,
    };
  }
}
