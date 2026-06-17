import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('errors', () {
    test('platform exceptions map to package exceptions', () {
      final exception = FoundationModelsException.fromPlatformException(
        PlatformException(
          code: FoundationModelsErrorCode.networkUnavailable.name,
          message: 'offline',
          details: <Object?, Object?>{
            'recoverySuggestion': 'connect',
            'raw': 1,
          },
        ),
      );

      expect(exception.code, FoundationModelsErrorCode.networkUnavailable);
      expect(exception.recoverySuggestion, 'connect');
      expect(
        exception.toString(),
        'FoundationModelsException(networkUnavailable, offline)',
      );
      expect(
        FoundationModelsException.fromPlatformException(
          PlatformException(code: 'future'),
        ).code,
        FoundationModelsErrorCode.unknown,
      );
      expect(
        FoundationModelsException.fromPlatformException(
          PlatformException(code: 'x', details: 'bad'),
        ).details,
        isEmpty,
      );
    });
  });
}
