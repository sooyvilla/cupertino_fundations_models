// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: no_leading_underscores_for_library_prefixes, prefer_single_quotes, use_raw_strings, no_leading_underscores_for_local_identifiers, unnecessary_lambdas, avoid_redundant_argument_values, directives_ordering
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart' as _cfm;
import "generated_generation_choices.dart" as _i0;
import "generated_document_row.structured.dart" as _i1;
/// Generated guidance and final conversion for GeneratedGenerationChoices.
final class GeneratedGenerationChoicesCodec {
  /// Equivalent runtime schema; native availability and guide validation still apply.
  static const schema = _cfm.StructuredSchema.object(name: "GeneratedGenerationChoices",
properties: {"accepted": _cfm.SchemaProperty.boolean(),
"confidence": _cfm.SchemaProperty.number(),
"count": _cfm.SchemaProperty.integer(),
"labels": _cfm.SchemaProperty.array(exactItems: 2,items: _cfm.SchemaProperty.anyOf(alternatives: [_cfm.SchemaProperty.string(), _cfm.SchemaProperty.nullValue()])),
"note/~": _cfm.SchemaProperty.anyOf(alternatives: [_cfm.SchemaProperty.string(), _cfm.SchemaProperty.nullValue()]),
"rows": _cfm.SchemaProperty.array(items: _cfm.SchemaProperty.anyOf(alternatives: [_cfm.SchemaProperty.object(
properties: {"amountText": _cfm.SchemaProperty.string(),
"dateText": _cfm.SchemaProperty.string(),
"description": _cfm.SchemaProperty.string(),
"sourceRow": _cfm.SchemaProperty.integer(minimum: 1)}, requiredProperties: ["sourceRow","description","amountText"], propertyOrder: ["sourceRow","dateText","description","amountText"], ), _cfm.SchemaProperty.nullValue()])),
"score": _cfm.SchemaProperty.number(minimum: 0,maximum: 1),
"status": _cfm.SchemaProperty.string(enumValues: ["pending","reviewed"], )}, requiredProperties: ["accepted","confidence","count","labels","note/~","rows","score","status"],  description: "Typed integration choices",);
  /// Converts final data structurally without validating business truth or guides.
  static _i0.GeneratedGenerationChoices decode(Object? value, {String path = '#'}) {
    final _object = _cfm.StructuredValueReader.object(value, path, {"accepted","confidence","count","labels","note/~","rows","score","status"});
    return _i0.GeneratedGenerationChoices.named(accepted: _cfm.StructuredValueReader.field(_object, "accepted", path, (value, path) => _cfm.StructuredValueReader.boolean(value, path), required: true, allowNull: false)!,
confidence: _cfm.StructuredValueReader.field(_object, "confidence", path, (value, path) => _cfm.StructuredValueReader.number(value, path), required: true, allowNull: false)!,
count: _cfm.StructuredValueReader.field(_object, "count", path, (value, path) => _cfm.StructuredValueReader.integer(value, path), required: true, allowNull: false)!,
labels: _cfm.StructuredValueReader.field(_object, "labels", path, (value, path) => _cfm.StructuredValueReader.list(value, path, (item, itemPath) => _cfm.StructuredValueReader.nullable(item, itemPath, (value, path) => _cfm.StructuredValueReader.string(value, path))), required: true, allowNull: false)!,
note: _cfm.StructuredValueReader.field(_object, "note/~", path, (value, path) => _cfm.StructuredValueReader.string(value, path), required: true, allowNull: true),
rows: _cfm.StructuredValueReader.field(_object, "rows", path, (value, path) => _cfm.StructuredValueReader.list(value, path, (item, itemPath) => _cfm.StructuredValueReader.nullable(item, itemPath, (value, path) => _i1.GeneratedDocumentRowCodec.decode(value, path: path))), required: true, allowNull: false)!,
score: _cfm.StructuredValueReader.field(_object, "score", path, (value, path) => _cfm.StructuredValueReader.doubleValue(value, path), required: true, allowNull: false)!,
status: _cfm.StructuredValueReader.field(_object, "status", path, (value, path) => _cfm.StructuredValueReader.enumValue(value, path, _i0.ReviewStatus.values), required: true, allowNull: false)!);
  }
}

/// A typed nonterminal view retaining native presence and completeness.
final class GeneratedGenerationChoicesPartial {
  /// Views the original snapshot at an object path without final-model construction.
  GeneratedGenerationChoicesPartial.fromSnapshot(this._snapshot, {String path = '#'}) : _path = path {
    _cfm.StructuredValueReader.partialObject(_snapshot, _path, {"accepted","confidence","count","labels","note/~","rows","score","status"});
  }
  final _cfm.StructuredSnapshot _snapshot;
  final String _path;
  /// Original replaceable snapshot; a complete root is still nonterminal.
  _cfm.StructuredSnapshot get snapshot => _snapshot;
  /// Native completeness at this object's path.
  bool get isComplete => _snapshot.completePaths.contains(_path);
  _cfm.StructuredPartialField<bool> get accepted =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "accepted"), (value, path) => _cfm.StructuredValueReader.boolean(value, path), container: false);
_cfm.StructuredPartialField<num> get confidence =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "confidence"), (value, path) => _cfm.StructuredValueReader.number(value, path), container: false);
_cfm.StructuredPartialField<int> get count =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "count"), (value, path) => _cfm.StructuredValueReader.integer(value, path), container: false);
_cfm.StructuredPartialField<List<String?>> get labels =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "labels"), (value, path) => _cfm.StructuredValueReader.partialList(_snapshot, value, path, (item, itemPath) => _cfm.StructuredValueReader.nullable(item, itemPath, (value, path) => _cfm.StructuredValueReader.string(value, path)), containers: false), container: true);
_cfm.StructuredPartialField<String?> get note =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "note/~"), (value, path) => _cfm.StructuredValueReader.nullable(value, path, (value, path) => _cfm.StructuredValueReader.string(value, path)), container: false);
_cfm.StructuredPartialField<List<_i1.GeneratedDocumentRowPartial?>> get rows =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "rows"), (value, path) => _cfm.StructuredValueReader.partialList(_snapshot, value, path, (item, itemPath) => _cfm.StructuredValueReader.nullable(item, itemPath, (value, path) => _i1.GeneratedDocumentRowPartial.fromSnapshot(_snapshot, path: path)), containers: true), container: true);
_cfm.StructuredPartialField<double> get score =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "score"), (value, path) => _cfm.StructuredValueReader.doubleValue(value, path), container: false);
_cfm.StructuredPartialField<_i0.ReviewStatus> get status =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "status"), (value, path) => _cfm.StructuredValueReader.enumValue(value, path, _i0.ReviewStatus.values), container: false);
}
