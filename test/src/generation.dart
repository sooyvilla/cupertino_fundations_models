import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('generation', () {
    test('prompt and options serialize', () {
      const prompt = Prompt(
        text: 'hello',
        attachments: <PromptAttachment>[
          PromptAttachment.file(
            path: '/tmp/a.png',
            label: 'image',
            mimeType: 'image/png',
          ),
          PromptAttachment.bytes(bytes: <int>[1, 2], label: 'bytes'),
        ],
        metadata: <String, Object?>{'trace': true},
      );

      expect(const Prompt.text('plain').toMap()['text'], 'plain');
      expect(prompt.toMap()['attachments'], hasLength(2));

      const options = GenerationOptions(
        samplingMode: SamplingMode.randomTopK,
        temperature: 0.4,
        maximumResponseTokens: 20,
        toolCallingPolicy: ToolCallingPolicy.required,
        reasoningLevel: ReasoningLevel.high,
        cloudPolicy: CloudPolicy.automaticWithUserConsent,
        includeSchemaInPrompt: true,
        timeout: Duration(milliseconds: 7),
      );
      expect(options.toMap()['timeoutMilliseconds'], 7);
    });

    test('model and structured responses parse maps', () {
      final request = StructuredGenerationRequest(
        prompt: const Prompt.text('hello'),
        schema: testSchema(),
      );
      expect(request.toMap()['schema'], testSchema().toMap());

      final response = ModelResponse.fromMap(<Object?, Object?>{
        'text': 'done',
        'usedMode': ModelMode.privateCloudCompute.name,
        'metadata': <Object?, Object?>{'tokens': 3},
        'structuredValue': <Object?, Object?>{'title': 'a'},
      });
      expect(response.text, 'done');
      expect(response.usedMode, ModelMode.privateCloudCompute);
      expect(response.structuredValue, <String, Object?>{'title': 'a'});
      expect(
        ModelResponse.fromMap(<Object?, Object?>{
          'usedMode': 'future',
        }).usedMode,
        ModelMode.local,
      );
    });

    test('session events parse known and unknown payloads', () {
      expect(
        SessionEvent.fromMap(<Object?, Object?>{
          'type': 'textDelta',
          'requestId': 'r1',
          'text': 'hi',
        }),
        isA<TextDeltaEvent>(),
      );

      final toolCall =
          SessionEvent.fromMap(<Object?, Object?>{
                'type': 'toolCall',
                'requestId': 'r1',
                'toolCallId': 't1',
                'name': 'search',
                'arguments': <Object?, Object?>{'q': 'dart'},
              })
              as ToolCallEvent;
      expect(toolCall.arguments, <String, Object?>{'q': 'dart'});
      expect(
        (SessionEvent.fromMap(<Object?, Object?>{
                  'type': 'toolCall',
                  'name': 'search',
                })
                as ToolCallEvent)
            .arguments,
        isEmpty,
      );

      final completed =
          SessionEvent.fromMap(<Object?, Object?>{
                'type': 'completed',
                'requestId': 'r1',
                'response': <Object?, Object?>{'text': 'ok'},
              })
              as CompletionEvent;
      expect(completed.response.text, 'ok');

      final failed =
          SessionEvent.fromMap(<Object?, Object?>{
                'type': 'failed',
                'requestId': 'r1',
                'code': 'bad',
                'message': 'no',
              })
              as FailureEvent;
      expect(failed.message, 'no');

      final unknown =
          SessionEvent.fromMap(<Object?, Object?>{'type': 'future'})
              as UnknownSessionEvent;
      expect(unknown.payload['type'], 'future');
      expect(
        SessionEvent.fromMap(<Object?, Object?>{}),
        isA<UnknownSessionEvent>(),
      );
    });
  });
}
