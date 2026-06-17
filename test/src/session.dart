import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('session', () {
    test('delegates requests and resolves tool calls', () async {
      final platform = FakePlatform();
      final session = await platform.createSession(
        options: SessionOptions(
          mode: ModelMode.local,
          tools: <ModelTool>[
            TestTool(name: 'echo', callback: (arguments) => arguments),
          ],
        ),
      );

      expect(session.id, 'session_1');
      expect(session.mode, ModelMode.local);
      expect(
        await session.respond(const Prompt.text('hi')),
        isA<ModelResponse>(),
      );
      expect(
        await session.stream(const Prompt.text('hi')).toList(),
        hasLength(1),
      );
      expect(
        await session.generateStructured(
          prompt: const Prompt.text('hi'),
          schema: testSchema(),
        ),
        isA<ModelResponse>(),
      );
      await session.prewarm(promptPrefix: const Prompt.text('prefix'));
      await session.cancelActiveRequest();
      await session.dispose();

      expect(
        platform.calls,
        containsAll(<String>[
          'respond',
          'stream',
          'generateStructured',
          'prewarm',
          'cancelActiveRequest',
          'disposeSession',
        ]),
      );
      expect(
        (await session.resolveToolCall(
          const ToolCall(
            id: '1',
            name: 'echo',
            arguments: <String, Object?>{'a': 1},
          ),
        )).value,
        <String, Object?>{'a': 1},
      );
      expect(
        (await session.resolveToolCall(
          const ToolCall(
            id: '2',
            name: 'missing',
            arguments: <String, Object?>{},
          ),
        )).isError,
        isTrue,
      );
    });

    test('returns tool failure when a registered tool throws', () async {
      final platform = FakePlatform();
      final session = FoundationModelSession(
        id: 'throwing',
        mode: ModelMode.local,
        platform: platform,
        tools: <ModelTool>[
          TestTool(name: 'boom', callback: (_) => throw StateError('boom')),
        ],
      );

      expect(
        (await session.resolveToolCall(
          const ToolCall(id: '3', name: 'boom', arguments: <String, Object?>{}),
        )).message,
        contains('boom'),
      );
    });
  });
}
