# Inteligencia artificial local de Apple con Flutter

En esta guía vas a añadir un resumen de texto que se genera dentro del iPhone, iPad o Mac,
usando `cupertino_fundations_models`. La librería conecta Dart con Foundation
Models, el framework nativo de Apple. También permite reescribir mensajes,
clasificar contenido, extraer JSON estructurado y llamar funciones de tu app.
La generación local no necesita una clave de API.

[English](local-ai-ios.md) · [Plataformas y macOS](apple-platforms.md) · [Recetas](recipes.md) · [Preguntas frecuentes](faq.md)

## Qué necesitas

| Requisito | Qué significa |
| --- | --- |
| Flutter 3.41+ y Dart 3.11+ | Versiones mínimas declaradas por el paquete. |
| macOS y un SDK de Xcode apropiado | Compilar el host nativo iOS o macOS; cada función puede exigir un SDK adicional. |
| iOS/iPadOS 26+ o macOS 26+ para generar | Los deployment targets iOS 15 y macOS 12 permiten incluir el plugin, pero no habilitan el modelo en sistemas anteriores. |
| Dispositivo apto para Apple Intelligence, ajustes, idioma y modelos disponibles | Consulta disponibilidad nativa; la versión del sistema por sí sola no basta. |

El plugin admite CocoaPods y Swift Package Manager. No añade paquetes runtime
de terceros ni exige incluir un modelo GGUF en tu aplicación. Apple administra
el modelo del sistema y sus recursos. Las descargas iniciales pueden necesitar
internet aunque la inferencia se ejecute dentro del dispositivo.

## Instalar la librería

Desde tu aplicación Flutter:

```sh
flutter pub add cupertino_fundations_models
```

Si prefieres indicar la versión en el archivo, añade:

```yaml
dependencies:
  cupertino_fundations_models: ^0.5.0
```

La versión `0.5.0` añade macOS. Sigue la
[configuración del host](apple-platforms.md#macos-host-setup) para usarlo en Mac.

Usa el identificador exacto, conservando la escritura existente `fundations`:

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';
```

Vuelve a compilar la app iOS o macOS después de añadir o actualizar el plugin. Hot reload
no instala un puente Swift nuevo. Una app exclusivamente local no necesita
activar PCC. Generar texto por sí solo no requiere permisos de micrófono ni
las descripciones de uso de Speech.

## Generar tu primer resumen

Llama esta función desde tu app Flutter. Comprueba la disponibilidad, crea una
sesión local y la libera al terminar. Si devuelve null, tu interfaz puede
ofrecer el flujo manual cuando el modelo no esté disponible o la solicitud falle.

```dart
import 'package:cupertino_fundations_models/cupertino_fundations_models.dart';

Future<String?> resumirEnDispositivo(String texto) async {
  final models = CupertinoFoundationModels();
  FoundationModelSession? session;
  try {
    final availability = await models.checkAvailability(
      mode: ModelMode.local,
      cloudPolicy: CloudPolicy.never,
      localeIdentifier: 'es_ES',
    );
    if (!availability.isAvailable) return null;

    session = await models.createSession(
      options: const SessionOptions(
        mode: ModelMode.local,
        cloudPolicy: CloudPolicy.never,
        localeIdentifier: 'es_ES',
        instructions:
            'Resume el texto suministrado en tres puntos breves en español. '
            'Usa únicamente hechos presentes en el texto.',
      ),
    );
    final response = await session.respond(
      Prompt.text(texto),
      options: const GenerationOptions(maximumResponseTokens: 180),
    );
    return response.text;
  } on FoundationModelsException {
    return null;
  } finally {
    await session?.dispose();
  }
}
```

Mantén la entrada corta y deja que el usuario revise el resultado. La
disponibilidad puede cambiar entre la consulta y la generación. En producción,
el código de error tipado y la [guía de recuperación](troubleshooting.md) permiten
explicar cada fallo en vez de tratar todos los resultados nulos como iguales.

## Qué API usar después

| Tarea | API | Contrato importante |
| --- | --- | --- |
| Generación independiente | `models.respond()` | Crea y libera una sesión para esa llamada. |
| Conversación con turnos anteriores | `models.createSession()` | Tu app administra la liberación y el historial de la sesión. |
| Mostrar texto progresivo | `session.stream()` | Cada snapshot es acumulativo: reemplaza el texto visible. |
| Extraer campos JSON | `models.generateStructured()` | Usa `StructuredSchema` y valida después el significado de los datos. |
| Streaming de JSON guiado | `session.streamStructured()` | El JSON parcial no es el resultado final; usa la respuesta de finalización. |
| Invocar funciones de tu app | `SessionOptions.tools` | Valida argumentos, autorización y efectos. |
| Reconocer voz | `transcribeAudio()` o `liveTranscription()` | Permisos, recursos y política de privacidad Speech separados. |

Las [recetas](recipes.md) incluyen extracción estructurada y clasificación.
La [referencia de uso](usage.md) detalla sesiones, tokens, plazos y cancelación.

## Mantener la inteligencia local dentro del dispositivo

Selecciona `ModelMode.local` y `CloudPolicy.never`. El paquete no envía
automáticamente una solicitud fallida a OpenAI, Gemini u otra API remota y no
almacena sus claves.

Las herramientas son código de tu aplicación y pueden consultar bases de
datos o acceder a internet. La política del modelo local no vuelve offline una
herramienta que usa la red. Para transcribir voz localmente selecciona, además,
`AudioTranscriptionMode.onDevice`; los modos `automatic` y `server` pueden
permitir reconocimiento mediante servidores Apple Speech.

PCC es una ruta cloud opcional de Apple. No se necesita para generar localmente.
La [guía Private Cloud Compute](private-cloud-compute.md) explica sus requisitos
separados: iOS/iPadOS 27 o macOS 27, entitlement Apple, firma, activación del host y consentimiento.
Una bandera en Info.plist no concede acceso a la nube.

## Tener en cuenta los límites del modelo

El código del repositorio admite **iOS/iPadOS y macOS**. No ofrece un backend
Android o web ni es un SDK para aplicaciones escritas únicamente en Swift.
visionOS y watchOS no tienen un target oficial Flutter; tvOS tampoco ofrece
las APIs del modelo usadas aquí. Consulta la [matriz investigada](apple-platforms.md).
No todos los dispositivos Apple pueden generar con Apple Intelligence.

Usa tareas cortas y definidas. El modelo local no es un buscador web, una
fuente de hechos verificados ni un agente autónomo general. Consulta la
capacidad de contexto cuando esté disponible y reserva espacio para las
instrucciones, el esquema, las herramientas y la respuesta. Un archivo pequeño
en bytes puede seguir siendo demasiado largo para el modelo.

Los documentos y PDF aportan texto extraído. Las imágenes usan la ruta
documentada de Vision OCR, clasificación y códigos de barras. Los adjuntos
multimodales nativos siguen deshabilitados, por lo que la comprensión de
imágenes tiene esos límites.

Estos ejemplos se revisaron con el código fuente y no se ejecutaron durante
esta actualización documental. Antes de publicar tu app, pruébalos con los
dispositivos, idiomas y entradas que quieras admitir.

## Referencias y siguientes pasos

- [Foundation Models de Apple](https://developer.apple.com/documentation/foundationmodels)
- [Referencia completa de uso](usage.md)
- [Aplicación de ejemplo](../example/README.md)
- [Extracción de documentos](document-extraction.md)
- [Escoger IA local o una API cloud](choosing-local-ai.md)
- [Referencia de la API Dart](https://pub.dev/documentation/cupertino_fundations_models/latest/)
- [Reportar un problema de integración](https://github.com/sooyvilla/cupertino_fundations_models/issues)
