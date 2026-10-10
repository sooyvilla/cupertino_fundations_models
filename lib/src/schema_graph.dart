import 'schema_property.dart';

/// Bounded serialization state for local schema definitions and references.
final class SchemaGraph {
  /// Creates one traversal; a null registry permits an unbound property reference.
  SchemaGraph(this.definitions) {
    final registry = definitions;
    if (registry != null && (registry.length > 32 || registry.keys.any((name) => name.trim().isEmpty))) {
      throw ArgumentError.value(registry, '#/definitions', 'Use at most 32 non-empty definition names.');
    }
  }

  /// Root-scoped definitions supplied during complete-schema serialization.
  final Map<String, SchemaProperty>? definitions;
  final Set<SchemaProperty> _active = Set<SchemaProperty>.identity();
  int _nodes = 0;
  bool _extended = false;

  /// Rejects recursive, overly deep or oversized expanded graphs before admission.
  void enter(SchemaProperty property, String path, int depth) {
    _nodes++;
    _extended = _extended || (definitions?.isNotEmpty ?? false) ||
        const {'anyof', 'reference', 'null'}.contains(property.type.toLowerCase());
    if (depth > 16 || (_extended && _nodes > 512) || !_active.add(property)) {
      throw ArgumentError.value(property.type, path, 'Use an acyclic graph with depth <= 16 and at most 512 expanded nodes.');
    }
  }

  /// Releases a node after its descendants were traversed.
  void leave(SchemaProperty property) => _active.remove(property);

  /// Resolves a root-scoped name, preserving unbound standalone serialization.
  SchemaProperty? target(String? name, String path) {
    if (name == null || name.trim().isEmpty || (definitions != null && !definitions!.containsKey(name))) {
      throw ArgumentError.value(name, '$path/reference', 'Reference a declared non-empty local definition.');
    }
    return definitions?[name];
  }

  /// Escapes one schema-path segment without treating names as external URIs.
  static String pointer(String name) => name.replaceAll('~', '~0').replaceAll('/', '~1');
}
