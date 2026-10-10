// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: no_leading_underscores_for_library_prefixes, prefer_single_quotes, use_raw_strings, no_leading_underscores_for_local_identifiers, unnecessary_lambdas, avoid_redundant_argument_values, directives_ordering
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart' as _cfm;
import "generated_document.dart" as _i0;
import "generated_document_row.structured.dart" as _i1;
/// Generated guidance and final conversion for GeneratedDocument.
final class GeneratedDocumentCodec {
  /// Equivalent runtime schema; native availability and guide validation still apply.
  static const schema = _cfm.StructuredSchema.object(name: "DocumentRows",
properties: {"currency": _cfm.SchemaProperty.string(pattern: "^(?:[A-Z]{3}|unknown)\$"),
"rows": _cfm.SchemaProperty.array(maxItems: 50,items: _cfm.SchemaProperty.object(
properties: {"amountText": _cfm.SchemaProperty.string(),
"dateText": _cfm.SchemaProperty.string(),
"description": _cfm.SchemaProperty.string(),
"sourceRow": _cfm.SchemaProperty.integer(minimum: 1)}, requiredProperties: ["sourceRow","description","amountText"], propertyOrder: ["sourceRow","dateText","description","amountText"], ))}, requiredProperties: ["currency","rows"], propertyOrder: ["currency","rows"], );
  /// Converts final data structurally without validating business truth or guides.
  static _i0.GeneratedDocument decode(Object? value, {String path = '#'}) {
    final _object = _cfm.StructuredValueReader.object(value, path, {"currency","rows"});
    return _i0.GeneratedDocument(currency: _cfm.StructuredValueReader.field(_object, "currency", path, (value, path) => _cfm.StructuredValueReader.string(value, path), required: true, allowNull: false)!,
rows: _cfm.StructuredValueReader.field(_object, "rows", path, (value, path) => _cfm.StructuredValueReader.list(value, path, (item, itemPath) => _i1.GeneratedDocumentRowCodec.decode(item, path: itemPath)), required: true, allowNull: false)!);
  }
}

/// A typed nonterminal view retaining native presence and completeness.
final class GeneratedDocumentPartial {
  /// Views the original snapshot at an object path without final-model construction.
  GeneratedDocumentPartial.fromSnapshot(this._snapshot, {String path = '#'}) : _path = path {
    _cfm.StructuredValueReader.partialObject(_snapshot, _path, {"currency","rows"});
  }
  final _cfm.StructuredSnapshot _snapshot;
  final String _path;
  /// Original replaceable snapshot; a complete root is still nonterminal.
  _cfm.StructuredSnapshot get snapshot => _snapshot;
  /// Native completeness at this object's path.
  bool get isComplete => _snapshot.completePaths.contains(_path);
  _cfm.StructuredPartialField<String> get currency =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "currency"), (value, path) => _cfm.StructuredValueReader.string(value, path), container: false);
_cfm.StructuredPartialField<List<_i1.GeneratedDocumentRowPartial>> get rows =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "rows"), (value, path) => _cfm.StructuredValueReader.partialList(_snapshot, value, path, (item, itemPath) => _i1.GeneratedDocumentRowPartial.fromSnapshot(_snapshot, path: itemPath), containers: true), container: true);
}
