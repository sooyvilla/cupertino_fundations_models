import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('languages preserve localized labels and safe native fallbacks', () {
    final language = FoundationModelsLanguage.fromMap(<Object?, Object?>{
      'identifier': 'es-CO',
      'languageCode': 'es',
      'displayName': 'Spanish',
      'nativeDisplayName': 'Español',
      'isTranscriptionAssetInstalled': true,
    });
    expect(language.toMap(), <String, Object?>{
      'identifier': 'es-CO',
      'languageCode': 'es',
      'displayName': 'Spanish',
      'nativeDisplayName': 'Español',
      'isTranscriptionAssetInstalled': true,
    });
    expect(FoundationModelsLanguage.fromMap(const {}).identifier, 'und');
    expect(
      FoundationModelsLanguage.fromMap(const {
        'identifier': 'en',
      }).nativeDisplayName,
      'en',
    );
    expect(
      FoundationModelsLanguage.fromMap(const {
        'displayName': 'English',
      }).nativeDisplayName,
      'English',
    );
  });

  test('token budgets preserve precision without inventing missing counts', () {
    final budget = TokenBudget.fromMap(<Object?, Object?>{
      'mode': 'privateCloudCompute',
      'modelIdentifier': 'model',
      'maximumResponseTokens': 30,
      'contextWindowTokens': 100,
      'components': <Object?, Object?>{
        'prompt': <Object?, Object?>{'count': 5, 'precision': 'exact'},
        'image': <Object?, Object?>{'count': 10, 'precision': 'estimated'},
        'tools': <Object?, Object?>{'reason': 'unsupported'},
        'future': <Object?, Object?>{'count': 3, 'precision': 'future'},
      },
    });
    expect(budget.mode, ModelMode.privateCloudCompute);
    expect(budget.modelIdentifier, 'model');
    expect(budget.maximumResponseTokens, 30);
    expect(budget.contextWindowTokens, 100);
    expect(budget.components['prompt']!.precision, TokenPrecision.exact);
    expect(budget.components['image']!.count, 10);
    expect(budget.components['tools']!.count, isNull);
    expect(budget.components['tools']!.reason, 'unsupported');
    expect(budget.components['future']!.precision, TokenPrecision.unavailable);
    expect(budget.components.clear, throwsUnsupportedError);
    expect(TokenBudget.fromMap(const {'mode': 'future'}).mode, ModelMode.local);
    expect(TokenBudget.fromMap(const {}).components, isEmpty);
  });

  test('generation rejects invalid deadlines and diagnostic limits', () {
    final custom = ['brief'].single;
    expect(
      GenerationOptions(
        reasoningLevel: ReasoningLevel.custom(custom),
      ).toMap()['customReasoningLevel'],
      'brief',
    );
    for (final options in <GenerationOptions>[
      const GenerationOptions(samplingTopK: 0),
      const GenerationOptions(samplingProbabilityThreshold: double.nan),
      const GenerationOptions(samplingProbabilityThreshold: -1),
      const GenerationOptions(samplingProbabilityThreshold: 2),
      const GenerationOptions(samplingSeed: -1),
      const GenerationOptions(maximumResponseTokens: 0),
      const GenerationOptions(maximumToolCalls: 0),
      const GenerationOptions(maximumToolCalls: 129),
      const GenerationOptions(temperature: double.nan),
      const GenerationOptions(temperature: double.infinity),
      const GenerationOptions(temperature: -1),
      const GenerationOptions(temperature: 2),
      const GenerationOptions(firstResponseTimeout: Duration.zero),
      const GenerationOptions(idleTimeout: Duration(microseconds: -1)),
      const GenerationOptions(totalTimeout: Duration.zero),
      GenerationOptions(
        diagnostics: GenerationDiagnostics(
          onEvent: (_) {},
          maximumOutputCharacters: 0,
        ),
      ),
      const GenerationOptions(reasoningLevel: ReasoningLevel.custom('  ')),
    ]) {
      expect(options.toMap, throwsArgumentError);
    }
    expect(
      const GenerationOptions(
        reasoningLevel: ReasoningLevel.custom('brief'),
      ).toMap()['customReasoningLevel'],
      'brief',
    );
  });

  test(
    'responses retain usage and recursively normalize structured channel values',
    () {
      final response = ModelResponse.fromMap(<Object?, Object?>{
        'usage': <Object?, Object?>{
          'inputTokenCount': 1,
          'cachedInputTokenCount': 2,
          'outputTokenCount': 3,
          'reasoningTokenCount': 4,
          'totalTokenCount': 10,
        },
        'structuredValue': <Object?, Object?>{
          'items': <Object?>[
            <Object?, Object?>{'ok': true},
            2,
            null,
          ],
          3: 'discard',
        },
      });
      expect(response.usage!.inputTokenCount, 1);
      expect(response.usage!.cachedInputTokenCount, 2);
      expect(response.usage!.outputTokenCount, 3);
      expect(response.usage!.reasoningTokenCount, 4);
      expect(response.usage!.totalTokenCount, 10);
      expect(response.structuredValue, <String, Object?>{
        'items': <Object?>[
          <String, Object?>{'ok': true},
          2,
          null,
        ],
      });
      expect(
        const FailureEvent(
          requestId: 'r',
          code: 'future',
          message: 'failed',
        ).termination.status,
        GenerationStatus.failed,
      );
      expect(
        const FailureEvent(
          requestId: 'r',
          code: 'cancelled',
          message: 'cancelled',
        ).termination.reason,
        GenerationStopReason.cancelled,
      );
      expect(
        (SessionEvent.fromMap(const {
                  'type': 'failed',
                  'details': <Object?, Object?>{'reason': 'refusal'},
                })
                as FailureEvent)
            .details['reason'],
        'refusal',
      );
    },
  );

  test('runtime request builders serialize attachments and nested schemas', () {
    final label = DateTime(2026).year.toString();
    final prompt = Prompt(
      text: label,
      attachments: [
        PromptAttachment.file(path: '/$label', label: label),
        PromptAttachment.bytes(bytes: [1], label: label),
      ],
    );
    expect(prompt.toMap()['attachments'], [
      <String, Object?>{
        'path': '/$label',
        'bytes': null,
        'label': label,
        'mimeType': null,
      },
      <String, Object?>{
        'path': null,
        'bytes': [1],
        'label': label,
        'mimeType': null,
      },
    ]);
    expect(Prompt.text(label).text, label);
    final properties = <String, SchemaProperty>{
      'string': SchemaProperty.string(description: label, enumValues: [label]),
      'integer': SchemaProperty.integer(description: label),
      'number': SchemaProperty.number(description: label),
      'boolean': SchemaProperty.boolean(description: label),
      'array': SchemaProperty.array(items: SchemaProperty(type: label)),
      'object': SchemaProperty.object(
        properties: {'nested': SchemaProperty.string(description: label)},
      ),
    };
    final schema = StructuredSchema.object(
      name: label,
      properties: properties,
      requiredProperties: ['string'],
    );
    final map = schema.toMap();
    expect(map['name'], label);
    expect(map['requiredProperties'], ['string']);
    expect((map['properties']! as Map<String, Object?>).keys, properties.keys);
    expect(
      properties['array']!.toMap()['items'],
      SchemaProperty(type: label).toMap(),
    );
    expect(
      AudioTranscriptionRequest(filePath: '/$label').toMap()['filePath'],
      '/$label',
    );
  });

  test(
    'transcription validates file requests and preserves live snapshots',
    () {
      for (final request in <AudioTranscriptionRequest>[
        const AudioTranscriptionRequest(filePath: '  '),
        const AudioTranscriptionRequest(filePath: '/a', localeIdentifier: ''),
        const AudioTranscriptionRequest(filePath: '/a', timeout: Duration.zero),
      ]) {
        expect(request.toMap, throwsArgumentError);
      }
      expect(
        const LiveTranscriptionRequest(
          localeIdentifier: 'es',
          reportPartialResults: false,
        ).toMap()['reportPartialResults'],
        isFalse,
      );
      final live = LiveTranscriptionEvent.fromMap(const {
        'text': 'hola',
        'isFinal': true,
        'metadata': <Object?, Object?>{'source': 'speech'},
      });
      expect(live.text, 'hola');
      expect(live.isFinal, isTrue);
      expect(live.metadata['source'], 'speech');
      expect(LiveTranscriptionEvent.fromMap(const {}).isFinal, isFalse);
    },
  );
}
