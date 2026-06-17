import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('availability', () {
    test('capabilities map round trip and unknown values', () {
      final capabilities = FoundationModelsCapabilities.fromMap(
        <Object?, Object?>{
          'platform': 'ios',
          'operatingSystemVersion': '27.0',
          'sdkVersion': '27.0',
          'capabilities': <Object?>[
            ModelCapability.localText.name,
            ModelCapability.fullPower.name,
            'future',
            1,
          ],
          'supportsFullPower': true,
          'preferredMode': ModelMode.privateCloudCompute.name,
          'contextSize': 4096,
          'privateCloudContextSize': 8192,
          'supportedLanguages': <Object?>['en_US', 1, 'es_ES'],
          'details': <Object?, Object?>{'device': 'simulator'},
        },
      );

      expect(capabilities.platform, 'ios');
      expect(capabilities.supports(ModelCapability.localText), isTrue);
      expect(capabilities.supports(ModelCapability.streaming), isFalse);
      expect(capabilities.preferredMode, ModelMode.privateCloudCompute);
      expect(capabilities.supportedLanguages, <String>['en_US', 'es_ES']);
      expect(capabilities.toMap(), <String, Object?>{
        'platform': 'ios',
        'operatingSystemVersion': '27.0',
        'sdkVersion': '27.0',
        'capabilities': <String>['localText', 'fullPower'],
        'supportsFullPower': true,
        'preferredMode': 'privateCloudCompute',
        'contextSize': 4096,
        'privateCloudContextSize': 8192,
        'supportedLanguages': <String>['en_US', 'es_ES'],
        'details': <String, Object?>{'device': 'simulator'},
      });

      final fallback = FoundationModelsCapabilities.fromMap(<Object?, Object?>{
        'preferredMode': 'future',
        'capabilities': <Object?>['future'],
      });
      expect(fallback.platform, 'unknown');
      expect(fallback.preferredMode, ModelMode.local);
      expect(fallback.capabilities, isEmpty);
    });

    test('diagnostics and availability handle full and fallback maps', () {
      final resetDate = DateTime.fromMillisecondsSinceEpoch(123456);
      final availability = ModelAvailability.fromMap(<Object?, Object?>{
        'mode': ModelMode.privateCloudCompute.name,
        'status': AvailabilityStatus.quotaExceeded.name,
        'isAvailable': false,
        'supportsFullPower': true,
        'reason': 'quota',
        'recoverySuggestion': 'try later',
        'contextSize': 100,
        'quota': <Object?, Object?>{
          'status': 'limited',
          'isLimitReached': true,
          'resetDate': resetDate.millisecondsSinceEpoch,
          'limitIncreaseSuggestion': 'wait',
          'details': <Object?, Object?>{'remaining': 0},
        },
        'details': <Object?, Object?>{'source': 'native'},
      });

      expect(availability.mode, ModelMode.privateCloudCompute);
      expect(availability.status, AvailabilityStatus.quotaExceeded);
      expect(availability.quota?.resetDate, resetDate);
      expect(availability.toMap(), <String, Object?>{
        'mode': 'privateCloudCompute',
        'status': 'quotaExceeded',
        'isAvailable': false,
        'supportsFullPower': true,
        'reason': 'quota',
        'recoverySuggestion': 'try later',
        'contextSize': 100,
        'quota': <String, Object?>{
          'status': 'limited',
          'isLimitReached': true,
          'resetDate': resetDate.millisecondsSinceEpoch,
          'limitIncreaseSuggestion': 'wait',
          'details': <String, Object?>{'remaining': 0},
        },
        'details': <String, Object?>{'source': 'native'},
      });

      final diagnostics = FoundationModelsDiagnostics.fromMap(
        <Object?, Object?>{
          'platform': 'ios',
          'operatingSystemVersion': '27.0',
          'sdkVersion': '27.0',
          'currentLocaleIdentifier': 'en_US',
          'preferredLanguages': <Object?>['en_US', 3],
          'localAvailability': availability.toMap(),
          'localSupportsCurrentLocale': true,
          'localSupportedLanguages': <Object?>['en_US'],
          'localPreferredLanguageSupport': <Object?>[
            <Object?, Object?>{'identifier': 'en_US', 'isSupported': true},
            'skip',
          ],
          'privateCloudAvailability': availability.toMap(),
          'privateCloudSupportsCurrentLocale': false,
          'privateCloudSupportedLanguages': <Object?>['es_ES'],
          'privateCloudPreferredLanguageSupport': <Object?>[
            <Object?, Object?>{'identifier': 'es_ES', 'isSupported': false},
          ],
          'details': <Object?, Object?>{'note': 'ok'},
        },
      );

      expect(diagnostics.targetLocaleIdentifier, 'en_US');
      expect(
        diagnostics.localPreferredLanguageSupport.single.isSupported,
        isTrue,
      );
      expect(
        diagnostics.privateCloudAvailability?.status,
        AvailabilityStatus.quotaExceeded,
      );
      expect(diagnostics.toMap()['details'], <String, Object?>{'note': 'ok'});

      final fallbackDiagnostics = FoundationModelsDiagnostics.fromMap(
        <Object?, Object?>{},
      );
      expect(
        fallbackDiagnostics.localAvailability.status,
        AvailabilityStatus.unknown,
      );
      expect(fallbackDiagnostics.privateCloudSupportedLanguages, isEmpty);
      expect(fallbackDiagnostics.privateCloudPreferredLanguageSupport, isEmpty);

      final fallbackAvailability = ModelAvailability.fromMap(<Object?, Object?>{
        'mode': 'future',
        'status': 'future',
        'quota': <Object?, Object?>{},
      });
      expect(fallbackAvailability.mode, ModelMode.local);
      expect(fallbackAvailability.status, AvailabilityStatus.unknown);
      expect(fallbackAvailability.quota, isNull);
      expect(
        PrivateCloudQuota.fromMap(<Object?, Object?>{
          'resetDate': 'bad',
        }).resetDate,
        isNull,
      );
      expect(
        LanguageSupport.fromMap(<Object?, Object?>{}).toMap(),
        <String, Object?>{'identifier': 'unknown', 'isSupported': false},
      );
    });
  });
}
