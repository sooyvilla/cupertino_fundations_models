import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:cupertino_fundations_models/cupertino_fundations_models_annotations.dart';
import 'package:source_gen/source_gen.dart';

import 'model_emitter.dart';

/// Emits existing runtime schemas, structural decoders and typed display views.
final class StructuredModelGenerator extends GeneratorForAnnotation<StructuredModel> {
  /// Matches only this package's annotation rather than an unrelated same-named type.
  const StructuredModelGenerator() : super(inPackage: 'cupertino_fundations_models');

  @override
  String generateForAnnotatedElement(Element element, ConstantReader annotation, BuildStep buildStep) {
    if (!buildStep.inputId.path.startsWith('lib/')) {
      throw InvalidGenerationSourceError('Place generated model libraries under lib/.', element: element);
    }
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError('StructuredModel requires a concrete public class.', element: element);
    }
    if (LibraryReader(element.library).annotatedWith(typeChecker).length != 1) {
      throw InvalidGenerationSourceError('Use one StructuredModel per source library.', element: element);
    }
    return ModelEmitter(element, annotation).emit();
  }
}
