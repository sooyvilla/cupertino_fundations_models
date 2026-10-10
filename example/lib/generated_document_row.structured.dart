// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: no_leading_underscores_for_library_prefixes, prefer_single_quotes, use_raw_strings, no_leading_underscores_for_local_identifiers, unnecessary_lambdas, avoid_redundant_argument_values, directives_ordering
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart' as _cfm;
import "generated_document_row.dart" as _i0;
/// Generated guidance and final conversion for GeneratedDocumentRow.
final class GeneratedDocumentRowCodec {
  /// Equivalent runtime schema; native availability and guide validation still apply.
  static const schema = _cfm.StructuredSchema.object(name: "GeneratedDocumentRow",
properties: {"amountText": _cfm.SchemaProperty.string(),
"dateText": _cfm.SchemaProperty.string(),
"description": _cfm.SchemaProperty.string(),
"sourceRow": _cfm.SchemaProperty.integer(minimum: 1)}, requiredProperties: ["sourceRow","description","amountText"], propertyOrder: ["sourceRow","dateText","description","amountText"], );
  /// Converts final data structurally without validating business truth or guides.
  static _i0.GeneratedDocumentRow decode(Object? value, {String path = '#'}) {
    final _object = _cfm.StructuredValueReader.object(value, path, {"amountText","dateText","description","sourceRow"});
    return _i0.GeneratedDocumentRow(amountText: _cfm.StructuredValueReader.field(_object, "amountText", path, (value, path) => _cfm.StructuredValueReader.string(value, path), required: true, allowNull: false)!,
dateText: _cfm.StructuredValueReader.field(_object, "dateText", path, (value, path) => _cfm.StructuredValueReader.string(value, path), required: false, allowNull: false),
description: _cfm.StructuredValueReader.field(_object, "description", path, (value, path) => _cfm.StructuredValueReader.string(value, path), required: true, allowNull: false)!,
sourceRow: _cfm.StructuredValueReader.field(_object, "sourceRow", path, (value, path) => _cfm.StructuredValueReader.integer(value, path), required: true, allowNull: false)!);
  }
}

/// A typed nonterminal view retaining native presence and completeness.
final class GeneratedDocumentRowPartial {
  /// Views the original snapshot at an object path without final-model construction.
  GeneratedDocumentRowPartial.fromSnapshot(this._snapshot, {String path = '#'}) : _path = path {
    _cfm.StructuredValueReader.partialObject(_snapshot, _path, {"amountText","dateText","description","sourceRow"});
  }
  final _cfm.StructuredSnapshot _snapshot;
  final String _path;
  /// Original replaceable snapshot; a complete root is still nonterminal.
  _cfm.StructuredSnapshot get snapshot => _snapshot;
  /// Native completeness at this object's path.
  bool get isComplete => _snapshot.completePaths.contains(_path);
  _cfm.StructuredPartialField<String> get amountText =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "amountText"), (value, path) => _cfm.StructuredValueReader.string(value, path), container: false);
_cfm.StructuredPartialField<String?> get dateText =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "dateText"), (value, path) => _cfm.StructuredValueReader.string(value, path), container: false);
_cfm.StructuredPartialField<String> get description =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "description"), (value, path) => _cfm.StructuredValueReader.string(value, path), container: false);
_cfm.StructuredPartialField<int> get sourceRow =>
    _cfm.StructuredValueReader.partialField(_snapshot, _cfm.StructuredValueReader.childPath(_path, "sourceRow"), (value, path) => _cfm.StructuredValueReader.integer(value, path), container: false);
}
