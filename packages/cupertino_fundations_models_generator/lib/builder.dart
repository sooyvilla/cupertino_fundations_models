import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/structured_model_generator.dart';

/// Builds standalone .structured.dart companions without modifying source models.
Builder structuredModelsBuilder(BuilderOptions options) => LibraryBuilder(
  const StructuredModelGenerator(), generatedExtension: '.structured.dart',
  formatOutput: (code, _) => code, writeDescriptions: false,
);
