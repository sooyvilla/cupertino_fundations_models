# Cupertino Foundations Models - Contexto de desarrollo

Fecha de investigacion: 2026-06-11  
Estado actual: paquete Flutter/Dart convertido a base inicial de plugin iOS.  
Regla local del proyecto: no crear tests.

## Objetivo del paquete

Crear un puente Flutter nativo para Apple Foundation Models, priorizando:

- Acceso local a `SystemLanguageModel` cuando el dispositivo y Apple Intelligence lo permitan.
- Acceso online mediante Private Cloud Compute (PCC) solo cuando la API, version del sistema, entitlement, red y cuota lo permitan.
- Tool calling, structured generation, streaming, sesiones con historial y utilidades de disponibilidad.
- Orquestacion opcional para apps que combinan Apple local/PCC con un proveedor externo propio.
- API publica estable en Dart, con degradacion por capacidades para no romper apps en dispositivos o SDKs sin soporte.
- Cero dependencias runtime de terceros. Usar solo Flutter, Dart core y APIs nativas Apple.

## Fuentes oficiales consultadas

- Apple Developer, Foundation Models: https://developer.apple.com/documentation/FoundationModels
- Apple Developer, generar contenido y tareas: https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models
- Apple Developer, tool calling: https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
- Apple Developer, guided generation: https://developer.apple.com/documentation/FoundationModels/generating-swift-data-structures-with-guided-generation
- Apple Developer, multimodal image prompting: https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting
- Apple Developer, dynamic sessions/profiles: https://developer.apple.com/documentation/foundationmodels/composing-dynamic-sessions-with-instructions-and-profiles
- Apple Developer, PCC: https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- Apple Developer, performance runtime: https://developer.apple.com/documentation/foundationmodels/analyzing-the-runtime-performance-of-your-foundation-models-app
- Apple Developer, KV caching: https://developer.apple.com/documentation/foundationmodels/optimizing-key-value-caching-in-language-model-sessions
- Apple Developer, context window: https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- Apple Developer, languages/locales: https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- Apple Developer, Apple Intelligence overview: https://developer.apple.com/apple-intelligence/
- Apple Support, requisitos Apple Intelligence: https://support.apple.com/en-us/121115
- Apple Developer, WWDC26 Foundation Models: https://developer.apple.com/videos/play/wwdc2026/241/
- Apple Developer, WWDC26 PCC: https://developer.apple.com/videos/play/wwdc2026/319/
- Apple Developer, WWDC26 agentic apps: https://developer.apple.com/videos/play/wwdc2026/242/
- Apple Developer, WWDC26 LLM provider: https://developer.apple.com/videos/play/wwdc2026/339/
- Apple Developer, Core AI: https://developer.apple.com/documentation/coreai/
- Apple Developer, iOS/iPadOS 27 beta release notes: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
- Apple Developer, Xcode 27 beta release notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes

## Hechos confirmados por documentacion Apple

Foundation Models no debe tratarse como una API exclusivamente iOS 27. El nucleo local existe desde iOS/iPadOS/macOS/visionOS 26.0 para `LanguageModelSession`, `SystemLanguageModel`, `Tool`, `Generable`, `GenerationSchema`, `Prompt`, `Instructions` y `Transcript`.

`SystemLanguageModel` representa el modelo de texto on-device que potencia Apple Intelligence. La disponibilidad no debe inferirse por nombre de dispositivo: se debe consultar `SystemLanguageModel.default.availability` o `isAvailable` en runtime.

Apple Intelligence requiere dispositivo compatible, Apple Intelligence activado, modelos descargados, idioma/region soportados y espacio disponible. Apple lista como compatibles iPhone 15 Pro, iPhone 15 Pro Max, iPhone 16 o posterior, iPad mini A17 Pro, iPads con M1 o posterior, Mac con M1 o posterior y Apple Vision Pro.

Apple Support indica que si se cambia el idioma de Siri, Apple Intelligence puede quedar no disponible hasta que el nuevo idioma de Siri descargue completamente y coincida con el idioma del dispositivo. El paquete no puede leer publicamente el idioma de Siri; por eso expone diagnostics de `Locale.current`, preferred languages y `supportsLocale`.

El contexto local documentado para el modelo on-device es 4096 tokens por sesion. La suma incluye instrucciones, prompts, respuestas, tool definitions, tool input/output y schemas.

`SystemLanguageModel.contextSize` aparece disponible desde iOS 26.0 con back-deployment antes de iOS 26.4. `tokenCount(for:)` aparece desde iOS 26.4.

Private Cloud Compute en Foundation Models esta documentado como `PrivateCloudComputeLanguageModel`, beta desde iOS/iPadOS/Mac Catalyst/macOS/visionOS/watchOS 27.0. PCC ofrece mayor razonamiento y contexto de 32K tokens, requiere red, usa cuota diaria por usuario y exige el entitlement `com.apple.developer.private-cloud-compute`.

Apple indica que PCC no requiere que el desarrollador gestione API keys ni autenticacion propia. Aun asi, requiere dispositivo compatible con Apple Intelligence y disponibilidad runtime.

Las release notes de iOS/iPadOS 27 beta indican issues relevantes: PCC puede no funcionar en simuladores; tool calling + guided generation puede producir llamadas excesivas; truncar historial en `onPrompt` puede causar runtime errors; `PrivateCloudComputeLanguageModel` usa greedy decoding en esa beta; pasar `any LanguageModel` al modifier `model(_:)` puede fallar y Apple menciona `foundation-models-utilities` como workaround.

Dynamic Profiles, `DynamicInstructions`, `Profile`, `LanguageModel` protocol, `LanguageModelExecutor`, `ContextOptions`, image `Attachment` y control explicito `GenerationOptions.ToolCallingMode` aparecen como iOS/iPadOS/macOS/visionOS/watchOS 27.0 beta.

Core AI es otra tecnologia: sirve para ejecutar modelos propios `.aimodel` en Apple silicon. No debe mezclarse en el nucleo inicial del paquete Foundation Models, aunque puede ser una extension futura.

## Matriz de disponibilidad para la API Dart

| Capacidad | API Apple | Version minima documentada | Estado del paquete |
| --- | --- | --- | --- |
| Disponibilidad local | `SystemLanguageModel.availability` | iOS 26.0 | Core estable |
| Generacion texto | `LanguageModelSession.respond` | iOS 26.0 | Core estable |
| Streaming | `LanguageModelSession.streamResponse` | iOS 26.0 | Core estable |
| Sesion con historial | `LanguageModelSession`, `Transcript` | iOS 26.0 | Core estable |
| Tool calling base | `Tool` | iOS 26.0 | Core estable |
| Structured output | `Generable`, `GenerationSchema` | iOS 26.0 | Core estable |
| Tamano de contexto | `SystemLanguageModel.contextSize` | iOS 26.0 | Core estable |
| Conteo tokens | `tokenCount(for:)` | iOS 26.4 | Core condicional |
| Imagenes multimodales | `Attachment`, `ImageReference` | iOS 27.0 beta | Experimental |
| Tool calling mode | `GenerationOptions.ToolCallingMode` | iOS 27.0 beta | Experimental |
| PCC | `PrivateCloudComputeLanguageModel` | iOS 27.0 beta | Experimental con entitlement |
| Reasoning level | `ContextOptions.ReasoningLevel` | iOS 27.0 beta | Experimental |
| Dynamic profiles | `DynamicProfile`, `Profile` | iOS 27.0 beta | Experimental |
| Provider externo | Adapter Dart de la app | N/A | Capa opcional de orquestacion; el paquete no incluye clientes de terceros |
| Core AI | `CoreAI` | iOS 27.0 beta | Fuera del core inicial |

## Principios de arquitectura

1. Native-first: la logica pesada vive en Swift y usa Foundation Models directamente. Dart solo orquesta y tipa la experiencia.
2. Zero runtime dependencies: no Provider, Riverpod, Bloc, Pigeon, JSON schema packages ni paquetes de terceros. Solo Flutter channels y Dart core.
3. Capability-based API: nunca asumir soporte por modelo de iPhone. Consultar capacidades nativas y exponer razones de no disponibilidad.
4. Stable public API, unstable internals: Dart debe mantener contratos estables aunque Apple cambie detalles de APIs beta.
5. Explicit cloud boundary: nunca enviar a PCC por sorpresa. `automatic` puede existir, pero debe ser configurable y reportar que uso cloud.
6. Privacy by default: prompts, tool outputs, imagenes y transcripts deben quedarse locales salvo que el usuario active PCC o proveedor externo.
7. Session isolation: cada sesion tiene estado propio. No usar singleton global mutable para transcripts o tools.
8. Backpressure-aware streaming: usar `Stream` y cancelar correctamente en Dart y Swift.
9. Typed errors: mapear errores nativos a codigos Dart estables, con razon, recovery suggestion y datos seguros.
10. No forced state manager: exponer `Stream`, DTOs inmutables y session handles. El usuario decide si integra Riverpod, Bloc, Provider, setState o arquitectura propia.

## SOLID aplicado

- SRP: availability, model selection, session registry, generation, streaming, tools, schema mapping y error mapping son componentes separados.
- OCP: agregar PCC, proveedores externos o Core AI no debe modificar la fachada publica base; se agregan estrategias/adapters.
- LSP: todos los modelos se tratan como `ModelBackend` desde Dart, aunque internamente usen `SystemLanguageModel`, PCC o proveedor futuro.
- ISP: separar interfaces Dart para availability, generation, streaming, tools, quota y diagnostics.
- DIP: la fachada Dart depende de una abstraccion `CupertinoFoundationModelsPlatform`, no del `MethodChannel` concreto.

## Patrones de diseno

- Facade: `CupertinoFoundationModels` como entrada simple para apps Flutter.
- Strategy: `FoundationModelsRoutingPolicy` decide `appleLocal`, `applePrivateCloud`, `appleAutomatic` o `external`.
- Adapter: Swift adapta Foundation Models a payloads Dart; Dart adapta DTOs a channel messages.
- Repository/Registry: `SessionRegistry` nativo conserva sesiones por `sessionId`.
- Actor model: Swift `actor` para aislar sesiones, tools, streaming y cancelaciones.
- Builder: `SessionOptions`, `GenerationOptions`, `StructuredSchema`, `ToolDefinition`.
- Command: cada tool call Dart se representa como comando con nombre, argumentos, timeout y resultado.
- State machine: ciclo de vida de sesion: `idle`, `prewarming`, `responding`, `streaming`, `cancelled`, `disposed`, `failed`.
- Observer: `Stream<SessionEvent>` para tokens, tool calls, quota updates y estado.
- Null object/fallback: backend `unsupported` devuelve availability clara sin lanzar excepciones no controladas.

## Arquitectura propuesta

### Capa Dart publica

Archivos objetivo:

- `lib/cupertino_fundations_models.dart`: exports publicos.
- `lib/src/cupertino_foundation_models.dart`: fachada principal.
- `lib/src/availability.dart`: availability, capabilities, unavailable reasons.
- `lib/src/session.dart`: session handle, lifecycle, transcript summary.
- `lib/src/generation.dart`: prompt, response, stream chunks, options.
- `lib/src/orchestration.dart`: fachada opcional para rutas Apple/local/PCC/proveedor externo.
- `lib/src/schema.dart`: schema dinamico compatible con `GenerationSchema`.
- `lib/src/tools.dart`: `ModelTool`, `ToolDefinition`, `ToolCall`, `ToolResult`.
- `lib/src/errors.dart`: errores tipados.
- `lib/src/platform/cupertino_foundation_models_platform.dart`: interfaz interna.
- `lib/src/platform/method_channel_cupertino_foundation_models.dart`: implementacion channel.

No exponer `MethodChannel` al usuario. No imponer singleton obligatorio. Permitir inyeccion para apps grandes.

### Capa nativa Swift

Archivos objetivo (desde 2026-07-03 la capa nativa vive en `ios/cupertino_fundations_models/Sources/cupertino_fundations_models/`, layout hibrido SPM + CocoaPods; los subdirectorios listados abajo son organizacion aspiracional):

- `ios/Classes/CupertinoFoundationModelsPlugin.swift`: registro Flutter y routing.
- `ios/Classes/Core/SessionRegistry.swift`: `actor` con almacenamiento de sesiones.
- `ios/Classes/Core/AvailabilityService.swift`: consulta Apple Intelligence/Foundation Models.
- `ios/Classes/Core/ModelResolver.swift`: strategy local/PCC/automatic.
- `ios/Classes/Core/MessageCodec.swift`: conversion segura Dart <-> Swift.
- `ios/Classes/Core/ErrorMapper.swift`: errores Foundation Models a codigos Dart.
- `ios/Classes/Generation/GenerationService.swift`: respond/structured.
- `ios/Classes/Generation/StreamingService.swift`: event channel y cancelacion.
- `ios/Classes/Tools/ToolBridge.swift`: tool calls nativas hacia Dart.
- `ios/Classes/Schemas/SchemaMapper.swift`: Dart schema a `GenerationSchema`.
- `ios/Classes/Diagnostics/DiagnosticsService.swift`: context size, token count, quota, version.
- `ios/Classes/PCC/PCCModelResolver.swift`: solo si se compila con SDK iOS 27.

Si se agrega macOS, compartir la mayor parte del Swift en `darwin/Classes` o duplicar minimo en `macos/Classes` con sources comunes.

### Comunicacion Flutter

- `MethodChannel` para llamadas request/response: availability, createSession, respond, dispose, countTokens, quota.
- `EventChannel` o event stream multiplexado para streaming de tokens, tool calls, estado y errores.
- Payloads JSON-like con maps/listas/primitivos para evitar codecs externos.
- Cada llamada debe incluir `requestId` y `sessionId` para cancelacion y correlacion.
- Tool calls deben viajar al Dart isolate principal y volver al Swift con timeout controlado.

## API Dart planificada

```dart
final CupertinoFoundationModels client = CupertinoFoundationModels();

final FoundationModelsCapabilities capabilities = await client.getCapabilities();
final ModelAvailability availability = await client.checkAvailability(
  mode: ModelMode.local,
);

final FoundationModelSession session = await client.createSession(
  options: SessionOptions(
    mode: ModelMode.automatic,
    instructions: 'You are a concise assistant.',
    tools: [myTool],
  ),
);

final ModelResponse response = await session.respond(
  Prompt.text('Summarize this note in Spanish.'),
  options: const GenerationOptions(maximumResponseTokens: 300),
);

await for (final event in session.stream(Prompt.text('Draft three titles'))) {
  print(event);
}
```

Enums y DTOs clave:

- `ModelMode.local`, `ModelMode.privateCloudCompute`, `ModelMode.automatic`.
- `ModelCapability.localText`, `streaming`, `toolCalling`, `structuredOutput`, `tokenCounting`, `imageInput`, `pcc`, `reasoning`, `dynamicProfiles`.
- `AvailabilityStatus.available`, `unavailable`, `unsupportedPlatform`, `unsupportedOsVersion`, `appleIntelligenceDisabled`, `assetsUnavailable`, `unsupportedLanguage`, `networkUnavailable`, `quotaExceeded`, `missingEntitlement`.
- `CloudPolicy.never`, `whenExplicit`, `automaticWithUserConsent`.
- `ToolCallingPolicy.auto`, `required`, `disallowed`, con degradacion si iOS 27 beta no esta disponible.

## Reglas de rendimiento

- Usar sesion nueva para interacciones single-turn.
- Reusar sesion para multiturn solo cuando el historial sea necesario.
- Mantener instrucciones y tools estables al inicio de la sesion para preservar KV cache.
- Evitar cambiar tools a mitad de sesion. Si se cambian, iniciar nueva sesion o limpiar outputs relacionados.
- Usar `prewarm` cuando la app sabe que el modelo se usara en 1 o 2 segundos.
- Preferir streaming para UX responsiva.
- Mantener prompts especificos y cortos.
- Limitar `maximumResponseTokens` cuando la UI no necesita respuestas largas.
- Mantener nombres y descripciones de tools/schemas cortos. Las descripciones consumen tokens.
- Para documentos largos, chunking por sesiones independientes y resumen acumulativo.
- No recortar transcript en cada turno. Consolidar cerca del limite de contexto.
- Al exceder contexto, resumir o crear nueva sesion con entradas clave.
- Medir con Foundation Models Instrument en Xcode: tokens, latencia, cache hit rate, tool calls.

## Politica cloud/PCC

PCC es una capacidad experimental iOS 27 beta en junio de 2026. Reglas:

- No usar PCC si `CloudPolicy.never`.
- No usar PCC sin disponibilidad runtime, red y entitlement.
- Exponer `quotaUsage`, `resetDate` y sugerencias de upgrade si Apple las entrega.
- Si PCC falla por red, intentar fallback local solo si la politica lo permite.
- Informar en eventos/metadata cuando una respuesta uso PCC.
- No almacenar prompts ni transcripts en el paquete.
- No incluir clientes concretos de proveedores externos en el paquete. La capa Dart solo define adapters opcionales para que la app conecte Gemini, OpenAI, Anthropic o backend propio.

## Seguridad y privacidad

- El paquete no debe registrar prompts, tool args, tool outputs ni imagenes por defecto.
- Diagnostics deben ser opt-in y sanitizados.
- Las tools declaradas por el usuario deben tener timeouts.
- El puente debe validar tipos, tamanos maximos y nombres de tools.
- No ejecutar herramientas destructivas sin que el usuario del paquete las haya registrado explicitamente.
- Los errores deben evitar devolver contenido sensible en mensajes.

## Manejo de estado

No agregar gestor de estado externo. El paquete expone:

- Objetos inmutables para opciones y respuestas.
- `Stream<SessionEvent>` para cambios.
- `Future` para operaciones one-shot.
- `SessionHandle` con `dispose()` y `cancelActiveRequest()`.

El estado nativo vive en `SessionRegistry` actor. Dart solo conserva handles y suscripciones.

## Roadmap de implementacion

### Fase 0 - Documentacion base

- Mantener `context.md` como mapa vivo del proyecto.
- Corregir README para no prometer iOS 27 local-only ni ejemplos que no existen.
- Decidir nombre del paquete antes de publicar. `cupertino_fundations_models` parece tener typo; pub.dev no permite renombrar un paquete publicado sin publicar uno nuevo.

### Fase 1 - Convertir a Flutter plugin nativo

- Actualizar `pubspec.yaml` con seccion `flutter.plugin`.
- Crear estructura `ios/Classes`.
- Definir platform interface interna sin dependencias externas.
- Implementar `getPlatformInfo()` y `getCapabilities()` minimo.
- Validar con `flutter analyze` y ejecucion manual, sin crear tests.

### Fase 2 - Availability local iOS 26

- Implementar `SystemLanguageModel.default.availability`.
- Mapear razones de no disponibilidad.
- Exponer `contextSize`, `supportedLanguages`, `supportsLocale`.
- Exponer `tokenCount` solo desde iOS 26.4.

### Fase 3 - Generacion local

- Crear y destruir sesiones.
- Implementar `respond` texto.
- Implementar `GenerationOptions` base: sampling, temperature, maximumResponseTokens.
- Mapear errores: context exceeded, assets unavailable, unsupported language, cancellation.

### Fase 4 - Streaming

- Implementar `streamResponse`.
- Multiplexar eventos por `requestId`.
- Cancelacion desde Dart.
- Backpressure simple y limpieza de recursos al cancelar/dispose.

### Fase 5 - Tool calling

- Definir `ModelTool` Dart.
- Registrar tool definitions por sesion.
- Swift tool bridge llama a Dart y espera resultado.
- Controlar concurrencia, timeout y errores.
- `ToolCallingPolicy` iOS 27 beta se expone como capability experimental; en iOS 26 queda en comportamiento automatico del modelo.

### Fase 6 - Structured output

- Implementar schema dinamico para JSON-like structures.
- Evitar macros Swift `@Generable` en tipos generados por el paquete, porque los schemas vienen de Dart runtime.
- Devolver `Map<String, Object?>` validado por Foundation Models.

### Fase 7 - PCC experimental

- Agregar sources iOS 27 beta con `PrivateCloudComputeLanguageModel`.
- Chequear entitlement y availability.
- Exponer quota.
- Fallback local por politica.
- Documentar que simulador puede fallar segun release notes de iOS 27 beta.

### Fase 8 - Imagenes y multimodal experimental

- Soportar attachments por file URL o bytes temporales seguros.
- Labels para attachments.
- No cargar imagenes enormes sin limites.
- Usar PCC solo si la politica lo permite y local no alcanza.

### Fase 9 - Dynamic profiles y proveedores

- Evaluar si Dynamic Profiles aportan valor desde Dart o si conviene modelarlo como policies propias.
- Evitar dependencia obligatoria de `foundation-models-utilities`.
- Proveedores Anthropic/Google/Core AI deben ir en paquetes adapters, no en el core.

## Decisiones abiertas

- Confirmar nombre final del paquete antes de publicacion.
- Definir plataformas iniciales: iOS solo, o iOS + macOS desde el primer corte.
- Definir si se publicara una version estable solo iOS 26 y otra beta para iOS 27.
- Confirmar estrategia para entitlement PCC, porque Apple requiere solicitud/eligibilidad.

## Mapa actual del repo

- `pubspec.yaml`: define el plugin iOS `CupertinoFoundationModelsPlugin`.
- `lib/cupertino_fundations_models.dart`: exports publicos de la API Dart.
- `lib/src/availability.dart`: capacidades, modos, politica cloud, availability, cuota PCC, diagnostics de locale/idioma y `LanguageSupport`.
- `lib/src/cupertino_foundation_models.dart`: fachada publica `CupertinoFoundationModels`.
- `lib/src/errors.dart`: errores tipados estables para Dart.
- `lib/src/file_selection.dart`: seleccion de archivos nativos para alimentar prompts o transcripcion.
- `lib/src/generation.dart`: prompt, attachments, generation options, responses y eventos de streaming.
- `lib/src/schema.dart`: schema runtime para structured output.
- `lib/src/session.dart`: session handle, lifecycle y resolucion de tools Dart.
- `lib/src/transcription.dart`: contratos de transcripcion de audio via Speech framework.
- `lib/src/tools.dart`: contratos `ModelTool`, `ToolDefinition`, `ToolCall` y `ToolResult`.
- `lib/src/platform/cupertino_foundation_models_platform.dart`: contrato interno de plataforma.
- `lib/src/platform/method_channel_cupertino_foundation_models.dart`: implementacion MethodChannel/EventChannel.
- `ios/cupertino_fundations_models.podspec`: podspec del plugin iOS (ruta CocoaPods; apunta a las fuentes del layout SPM).
- `ios/cupertino_fundations_models/Package.swift`: manifiesto Swift Package Manager (soporte hibrido SPM + CocoaPods) con dependencia `FlutterFramework`.
- `ios/cupertino_fundations_models/Sources/cupertino_fundations_models/`: fuentes Swift del plugin (antes `ios/Classes/`):
  - `CupertinoFoundationModelsPlugin.swift`: registro Flutter y routing de metodos/eventos.
  - `AvailabilityService.swift`: capabilities y availability iOS 26/27, con runtime check local si Foundation Models esta disponible.
  - `FileSelectionService.swift`: `UIDocumentPickerViewController` para seleccionar texto, imagen, audio o cualquier archivo sin dependencias externas.
  - `SessionRegistry.swift`: actor de sesiones, generacion local basica y streaming local basico.
  - `SpeechTranscriptionService.swift`: transcripcion de archivos de audio con `SFSpeechURLRecognitionRequest`, on-device o servidor Apple Speech.
  - `LiveTranscriptionService.swift`: transcripcion en vivo con `AVAudioEngine` + Apple Speech.
  - `MessageCodec.swift`: conversion basica de payloads Flutter.
  - `ErrorMapper.swift`: conversion de errores nativos a `FlutterError`.
  - `PrivacyInfo.xcprivacy`: manifiesto de privacidad del SDK (sin tracking ni APIs con required reason declaradas).
- `implementation_for_agents.md`: guia operativa tipo skill para agentes que implementen o integren la libreria.
- `example/pubspec.yaml`: app Flutter de ejemplo creada con `flutter create --platforms=ios .` y dependencia path al paquete.
- `example/lib/main.dart`: UI manual para probar capabilities, diagnostics, availability, full power, respond local/automatic y streaming local.
- `example/ios`: scaffold iOS generado por Flutter para correr en dispositivo real.
- `README.md`: documentacion publica, se debe mantener alineada con `context.md`.
- `analysis_options.yaml`: usa `flutter_lints`.

## Implementado en 2026-06-11

- Se reemplazo el scaffold `Calculator` por una API Dart publica para availability, capabilities, sesiones, generacion, streaming, schema runtime, tools y errores tipados.
- Se agrego platform interface interna sin dependencias externas.
- Se agrego implementacion `MethodChannel`/`EventChannel`.
- Se convirtio el paquete en plugin iOS en `pubspec.yaml`.
- Se agrego podspec iOS.
- Se agrego plugin Swift con registry de sesiones por actor.
- Se agrego availability basada en version de iOS, con iOS 27 como runtime de mayor potencia.
- Se dejo PCC como capacidad condicionada por SDK/runtime; la validacion de entitlement queda pendiente hasta compilar con SDK que exponga PCC estable.
- Se agrego hook de `SystemLanguageModel.default.availability` cuando `FoundationModels` existe en el SDK.
- Se agrego generacion local basica con `LanguageModelSession.respond(to:)` cuando `FoundationModels` existe en el SDK.
- Se agrego streaming local basico con `LanguageModelSession.streamResponse(to:)` cuando `FoundationModels` existe en el SDK.
- Se elimino el test generado por scaffold porque apuntaba al `Calculator` removido y la regla del proyecto es no crear tests.
- PCC, structured generation nativo, tool calling nativo, quota real y Dynamic Profiles quedan como siguientes fases.
- No se crearon tests.

## Implementado en 2026-06-11, example

- Se creo `example/` usando `/Users/villa/Developer/tools/flutter/bin/flutter create --platforms=ios .`.
- Se mantuvo `example/lib/main.dart` como pantalla manual de validacion de la API del paquete.
- Se ajusto `example/ios/Podfile` a `platform :ios, '15.0'` para ser compatible con el pod del plugin.
- Se ajusto el deployment target iOS generado a 15.0.
- Se eliminaron los archivos de test generados por Flutter (`example/test` y `example/ios/RunnerTests`) por la regla local de no crear tests.
- Se corrigieron errores nativos detectados por build: uso de `SecTask` en iOS y almacenamiento de `LanguageModelSession` con `@available`.
- Validaciones ejecutadas: `flutter analyze` en `example` sin issues y `flutter build ios --no-codesign` exitoso.

## Implementado en 2026-06-11, hardening iOS 27 beta

- Se corrigio `AvailabilityService` para no anunciar PCC/full power si el SDK usado para compilar no expone `PrivateCloudComputeLanguageModel`.
- Se agrego availability real de PCC detras de compilacion con SDK compatible, usando `PrivateCloudComputeLanguageModel().availability` cuando exista.
- Se ajusto `automatic` para preferir PCC solo cuando esta disponible y caer a local/offline cuando no lo esta.
- Se reforzo `SessionRegistry` para hacer preflight de availability antes de crear sesiones.
- Se mapearon errores de Apple Intelligence deshabilitado, assets faltantes, idioma no soportado, contexto, red y cuota a codigos Dart estables.
- Se ajusto el stream Dart para convertir errores de `EventChannel` en `FoundationModelsException`.
- Se actualizo el example para que offline sea explicito: `ModelMode.local` + `CloudPolicy.never`.
- Se agrego preflight en el example antes de respond/stream para evitar ejecutar cuando availability no esta disponible.
- Se agrego logging del prompt enviado desde el `TextField`.
- Se creo `implementation_for_agents.md`.
- Validaciones ejecutadas: `flutter analyze` en raiz, `flutter analyze` en `example`, `flutter build ios --no-codesign` en `example`.

## Ejecutado en 2026-06-12, release en iPhone

- Se detecto Xcode beta en `/Users/villa/Downloads/Xcode-beta.app` y se uso con `DEVELOPER_DIR` sin cambiar `xcode-select` global.
- Se detecto el iPhone `00008150-0012689E3640401C` con iOS 27.0.
- Se ajusto `example/ios/Podfile` para forzar `IPHONEOS_DEPLOYMENT_TARGET = 15.0` tambien en targets de CocoaPods, requerido por Xcode 27.
- Se ejecuto `flutter run --release -d 00008150-0012689E3640401C --device-timeout 120`.
- Resultado: build release, instalacion y lanzamiento en el iPhone completados correctamente.

## Implementado en 2026-06-12, diagnostics de idioma y SDK 27

- Se agrego `CupertinoFoundationModels.getDiagnostics()` con DTO `FoundationModelsDiagnostics`.
- Diagnostics expone platform, OS, SDK, `Locale.current`, `Locale.preferredLanguages`, `SystemLanguageModel.supportsLocale(Locale.current)`, supported languages locales y availability local/PCC.
- Se documento que el paquete no puede leer el idioma de Siri con API publica; el estado debe diagnosticarse cruzando locale del sistema/app con la configuracion manual de Apple Intelligence & Siri.
- Se reforzo el mapeo nativo de `modelNotReady` a `assetsUnavailable` y `deviceNotEligible` a `unsupportedPlatform`.
- Se hizo que `GenerationOptions.maximumResponseTokens`, `temperature`, `samplingMode` y `toolCallingPolicy` se pasen al SDK nativo cuando estan disponibles.
- Se agrego boton `Diagnostics` en `example/lib/main.dart`.
- Validaciones ejecutadas: `flutter analyze` en raiz, `flutter analyze` en `example`, `flutter build ios --no-codesign` con Xcode 27 beta en `example`.
- Se instalo y lanzo release en el iPhone `00008150-0012689E3640401C` con `flutter run --release` usando Xcode 27 beta; luego se cerro la sesion interactiva de Flutter.

## Implementado en 2026-06-12, copiado de logs del example

- `example/lib/main.dart` permite copiar todos los logs visibles al portapapeles desde el AppBar y desde el encabezado de la seccion `Logs`.
- El copiado usa `Clipboard` de Flutter, sin dependencias externas, y muestra feedback con `SnackBar`.
- Validaciones ejecutadas: `flutter analyze` en raiz y `flutter analyze` en `example`.
- Se instalo y lanzo release en el iPhone `00008150-0012689E3640401C` con Xcode 27 beta; luego se cerro la sesion interactiva de Flutter.

## Implementado en 2026-06-12, example forzado a English US

- `example/lib/main.dart` fija `MaterialApp.locale` y `supportedLocales` a `Locale('en', 'US')`.
- `example/lib/main.dart` llama diagnostics y availability con `localeIdentifier: 'en_US'` para eliminar ambiguedad entre `es-CO`, `en-CO` y `en_US` durante pruebas.
- `example/ios/Runner/AppDelegate.swift` inicializa `AppleLanguages = ['en-US']` y `AppleLocale = en_US` antes de Flutter.
- `example/ios/Runner/Info.plist` declara `CFBundleDevelopmentRegion = en` y `CFBundleLocalizations = ['en']`.
- `FoundationModelsDiagnostics` ahora incluye `targetLocaleIdentifier`, y Swift evalua `supportsLocale` contra el locale objetivo recibido.

## Implementado en 2026-06-12, inputs avanzados y consola de pruebas

- Se agrego `CupertinoFoundationModels.pickFile()` con `FoundationModelsFileKind.any/image/audio/text`; la implementacion iOS usa `UIDocumentPickerViewController` y copia el archivo a temporal para que Swift pueda leerlo.
- Se agrego `CupertinoFoundationModels.transcribeAudio()` con `AudioTranscriptionMode.onDevice/server/automatic`; iOS usa `Speech.framework` y `SFSpeechURLRecognitionRequest`.
- `AudioTranscriptionMode.onDevice` fuerza `requiresOnDeviceRecognition = true`; `server` deja que Apple Speech use su ruta remota si aplica; `automatic` prefiere on-device cuando el locale lo soporta. Esta ruta no es PCC de Foundation Models.
- `SessionRegistry` ahora construye `FoundationModels.Prompt` real desde texto + attachments: archivos de texto se leen como UTF-8 y las imagenes usan `Attachment<ImageAttachmentContent>` cuando corre en iOS 27.
- `SessionRegistry` aplica `ContextOptions.reasoningLevel` en iOS 27 mapeando `low/medium/high` a `light/moderate/deep`, y devuelve metadata de usage/token counts cuando Apple la expone.
- `example/lib/main.dart` se convirtio en consola manual: modo local/automatic/PCC, cloud opt-in, sampling, tool calling, reasoning, temperatura, max tokens, instrucciones, prompt, attachments, audio, transcripcion, respond y stream.
- `example/ios/Runner/Info.plist` incluye `NSSpeechRecognitionUsageDescription` y `NSMicrophoneUsageDescription`.
- Limitacion actual: no hay picker directo de Photos ni microfono en vivo; para imagen/audio se usa Files/document picker. Audio no se envia directo al modelo, se transcribe primero y luego el texto se usa como prompt.
- No se crearon tests.
- Validaciones ejecutadas: `flutter analyze` en raiz, `flutter analyze` en `example`, `pod install` en `example/ios`, `flutter build ios --no-codesign` con Xcode 27 beta en `example`.

## Implemented on 2026-06-16, English publishing documentation and SEO

- Confirmed that conversation context is supported through reusable `FoundationModelSession` handles; `CupertinoFoundationModels.respond()` remains a single-turn convenience API because it creates and disposes a native session per request.
- Rewrote `README.md` in English with platform support, conversation context, installation, iOS setup, availability checks, local generation, streaming, attachments, audio transcription, PCC, error handling, example usage, and package naming notes.
- Rewrote `implementation_for_agents.md` in English as an operational integration guide for future agents and maintainers.
- Expanded `example/README.md` in English so pub.dev has a useful Example tab.
- Updated `CHANGELOG.md` in English with current capabilities.
- Updated `pubspec.yaml` with pub.dev discoverability fields: `homepage`, `repository`, `issue_tracker`, `documentation`, `topics`, and explicit `platforms`.
- SEO/discoverability terms intentionally included in public docs: Apple Foundation Models, Apple Intelligence, on-device AI, Flutter plugin, Private Cloud Compute, streaming, multimodal prompts, speech transcription, iOS 27.
- No tests were created.

## Implemented on 2026-06-16, pub.dev metadata hardening for 0.0.2

- Bumped `pubspec.yaml` to `0.0.2` because `0.0.1` is already published and cannot be republished.
- Kept the package explicitly iOS-only with `platforms: ios` and the iOS plugin registration only.
- Removed generated Flutter test scaffolding and the `flutter_test` dev dependency to comply with the local rule of not creating tests.
- Added `CONTRIBUTING.md` with English contribution and validation rules.
- Expanded `README.md` with source code links, repository/issues/documentation links, the advanced example source link, and a dedicated Agent Skill Guide section pointing to `implementation_for_agents.md`.
- Expanded `example/README.md` with a direct link to `example/lib/main.dart` and a list of advanced API paths demonstrated by the example app.
- Kept `implementation_for_agents.md` publishable so pub.dev/GitHub users can read it as a skill-style implementation guide.
- `.pubignore` excludes `context.md` and IDE files from the published package while keeping public English docs included.
- `.pubignore` also excludes generated `build/`, `coverage/`, and `test/` artifacts from publication.
- `analysis_options.yaml` keeps strict typing but no longer requires `public_member_api_docs` for every member, avoiding analyzer noise until the API docs pass is done.
- `dart pub publish --dry-run` for `0.0.2` packages only public files plus the advanced example and reports one expected warning: the git tree has uncommitted/staged changes.
- Note for publishing: pub.dev verified publisher status cannot be configured from this repository; it must be configured in the pub.dev admin UI using an owned domain.

## Implemented on 2026-07-03, hybrid chat, live transcription, 0.1.0

- Research: confirmed via Apple doc JSON API that iOS 27 beta 2 Foundation Models news are the `LanguageModel` protocol + `LanguageModelExecutor` (official path to plug external LLM providers into the framework), `PrivateCloudComputeLanguageModel` (32K context, greedy decoding in this beta, may fail on simulator), `GenerationOptions.ToolCallingMode`, multimodal image prompts with Vision tools, Dynamic Profiles, and the `foundation-models-utilities` Swift package workaround for `model(_:)`. `SpeechAnalyzer`/`SpeechTranscriber` (Speech framework) is stable since iOS 26 and is the modern path for live transcription; adopting it remains pending.
- Added live microphone transcription: `CupertinoFoundationModels.liveTranscription()` returns `Stream<LiveTranscriptionEvent>`; new `LiveTranscriptionRequest`/`LiveTranscriptionEvent` DTOs in `lib/src/transcription.dart`; new `ios/Classes/LiveTranscriptionService.swift` using `AVAudioEngine` + `SFSpeechAudioBufferRecognitionRequest` behind the dedicated `cupertino_fundations_models/transcription_events` event channel (registered in the plugin). Cancelling the Dart subscription stops capture; minimum iOS 13 for the Speech path.
- Improved hybrid orchestration in `lib/src/orchestration.dart`: `FoundationModelsChatMessage`/`FoundationModelsChatRole`, `FoundationModelsRequest.history` (external providers receive the conversation), `FoundationModelsExternalProvider.respondStream()` (default single snapshot), and `FoundationModelsChatSession` via `orchestrator.startChat()` with `send()`, `sendStream()` (emits `OrchestratedChatTextEvent`/`OrchestratedChatCompletionEvent`), `reset()`, `dispose()`. Apple turns reuse a persistent native session; when history and native transcript diverge (external turn or route change), the session is recreated and history is replayed in the prompt preamble.
- Rewrote `example/lib/main.dart` as a chat app: hybrid orchestrator + chat session with streaming bubbles, live transcription mic button feeding the input, image attachment via document picker, availability banner, diagnostics dialog, and an app-side `GeminiExternalProvider` (dart:io HttpClient, enabled with `--dart-define=GEMINI_API_KEY`). No third-party dependencies.
- Version set to 0.1.0 (additive changes only, no breaking API). CHANGELOG rewritten: unpublished 0.0.3 entry folded into 0.1.0.
- SEO for pub.dev (research: name weighs most in search, description 0.90, first 5000 README chars 0.75; ranking = text match x (50% pub points + 50% likes/downloads)): tuned `pubspec.yaml` description under 180 chars with key terms, topics now `apple-intelligence, foundation-models, on-device-ai, ai, speech-to-text`, README front-loaded with search terms. Open decision: the package name typo (`fundations` vs `foundations`) hurts exact-name matches for "foundation models"; renaming requires publishing a new package.
- Updated `README.md`, `example/README.md`, and `implementation_for_agents.md` for chat, live transcription, and hybrid streaming.
- test/src/test_helpers.dart fake platform gained a `liveTranscription` stub (tests already existed in repo; none were added).
- Validations: `flutter analyze` clean at root and example; `flutter build ios --no-codesign` with Xcode 27 beta (`/Applications/Xcode-beta.app`) succeeded. Flutter warns the plugin lacks Swift Package Manager support; adding SPM support is pending.

## Implemented on 2026-07-03, Swift Package Manager hybrid support

- Migrated the iOS plugin to the hybrid CocoaPods + Swift Package Manager layout per the official Flutter guide: Swift sources moved (with git history) from `ios/Classes/` to `ios/cupertino_fundations_models/Sources/cupertino_fundations_models/`.
- Added `ios/cupertino_fundations_models/Package.swift` (swift-tools-version 5.9, iOS 15 platform, product `cupertino-fundations-models`). The Flutter beta toolchain requires the package to depend on `FlutterFramework` (`.package(name: "FlutterFramework", path: "../FlutterFramework")` + target product); that package is generated ephemerally by the Flutter tool at build time, nothing is committed for it.
- Added `PrivacyInfo.xcprivacy` (no tracking, no collected data, no required-reason APIs declared) processed as an SPM resource and exposed to CocoaPods via `resource_bundles` (`cupertino_fundations_models_privacy`).
- Updated `ios/cupertino_fundations_models.podspec`: `source_files` now points at the SPM sources path, so CocoaPods consumers keep working unchanged.
- The Flutter tool auto-migrated `example/ios/Runner.xcodeproj` and the Runner scheme to add the `FlutterGeneratedPluginSwiftPackage` integration; those example changes must be kept. The example still has CocoaPods integration (Flutter prints an optional cleanup hint; removing it is a manual, optional step).
- Validations: `flutter analyze` clean at root and example; `flutter build ios --no-codesign` in example with Xcode 27 beta succeeded twice (first run surfaced the `FlutterFramework` dependency requirement, second run clean). The pub.dev "SPM support" warning from `flutter run` is resolved.
- No tests were created.

## Implemented on 2026-07-03, native full-power pass: tools, structured, prewarm, cancel, SpeechAnalyzer

- Native tool calling (iOS 26+): new `ToolBridge.swift` forwards model tool calls to Dart via `invokeMethod("toolCall")` and returns the Dart result as the tool output (errors become readable failure text so generation can continue). New `DynamicTool: Tool` in `SessionRegistry.swift` uses `GeneratedContent` arguments and a `GenerationSchema` built from the Dart tool definition. `SessionRegistry.makeSession` now registers tools on local and PCC `LanguageModelSession`s. Dart side: `MethodChannelCupertinoFoundationModels` sets a method-call handler, keeps a live-session map (sessions with tools only), decodes `argumentsJson`, and `FoundationModelSession.resolveToolCall` enforces the per-tool timeout.
- Native guided structured generation (iOS 26+): new `SchemaMapper.swift` maps the Dart `StructuredSchema` payload (object/string/enum/integer/number/boolean/array, requiredProperties) to `DynamicGenerationSchema` and `GenerationSchema`; `SessionRegistry.respondStructured` calls `respond(to:schema:includeSchemaInPrompt:options:)` and returns `GeneratedContent.jsonString` parsed into `structuredValue`. The plugin now routes `generateStructured` to it (previously it silently ran plain `respond`).
- `prewarm` (iOS 26+): `SessionRegistry.prewarm` calls `languageSession.prewarm(promptPrefix:)`; the plugin method is no longer a no-op.
- `cancelActiveRequest`: the plugin tracks respond/structured tasks (`requestTasks`) and stream tasks (`streamTasks`) per sessionId; cancel and dispose cancel them, and Swift `CancellationError` maps to the stable `cancelled` code in `ErrorMapper`. This also fixed concurrent streams clobbering the previous single `streamTask` var.
- Content tagging (iOS 26+): `SessionOptions.useCase` (`FoundationModelsUseCase.general|contentTagging` in `lib/src/session.dart`) selects `SystemLanguageModel(useCase: .contentTagging)` for local sessions.
- Live transcription upgraded: `LiveTranscriptionService.swift` now prefers `SpeechAnalyzer` + `SpeechTranscriber` on iOS 26+ (supported-locale check, `AssetInventory` install, `bestAvailableAudioFormat` + `AVAudioConverter`, `AsyncStream<AnalyzerInput>`, volatile results merged as finalized+volatile snapshots) and falls back to `SFSpeechRecognizer` on older systems, unsupported locales, analyzer setup failure, or explicit `server` mode. Event metadata includes `engine: speechAnalyzer|sfSpeech`. File transcription still uses SFSpeech (SpeechAnalyzer adoption pending there).
- Example: added demo `DeviceTimeTool` (`get_current_time`) wired through `FoundationModelsDefaults.tools` so the chat exercises native tool calling.
- Docs: README gained Tool Calling, Structured Output, and Performance sections and an updated capability matrix; `implementation_for_agents.md` file map updated to the SPM paths; CHANGELOG 0.1.0 extended with Added/Fixed entries for this pass.
- Pending after this pass: direct Photos picker, `tokenCount(for:)` (iOS 26.4, API shape unverified), SpeechAnalyzer for file transcription, Dynamic Profiles, iOS 27 `LanguageModel` protocol bridge.
- Validations: `flutter analyze` clean at root and example; `flutter build ios --no-codesign` with Xcode 27 beta succeeded; `dart pub publish --dry-run` only warns about the dirty git tree. No tests were created.

## Implemented on 2026-07-03, fix: streaming EventChannel never closed (chat stuck after first message)

- Bug: `SessionRegistry.stream` (Swift) emitted the `completed` event but never sent `FlutterEndOfEventStream`, so the Dart `EventChannel` stream never closed. `FoundationModelsChatSession.sendStream` awaited the native stream forever, the `OrchestratedChatCompletionEvent` never fired, and the example chat stayed in `_sending = true` after the first message (input blocked, bubble stuck streaming). Error paths had the same leak.
- Fix in `ios/cupertino_fundations_models/Sources/cupertino_fundations_models/SessionRegistry.swift`: emit `FlutterEndOfEventStream` after `completed`, after every error emission (session-not-found, modelUnavailable, catch), matching the pattern `LiveTranscriptionService.swift` already used.
- Defensive fix in `lib/src/platform/method_channel_cupertino_foundation_models.dart` `stream()`: the transformer now closes the sink when a `CompletionEvent` or `FailureEvent` arrives (mirrors the `isFinal` close in `liveTranscription`), so Dart unblocks even if a native path forgets end-of-stream; closing also cancels the EventChannel subscription (native `onCancel`).
- Validations: `flutter analyze` clean at root and example; `flutter build ios --no-codesign` with Xcode 27 beta. No tests were created.

## Implemented on 2026-07-03, UX pass: refusals/short answers, backend selector, SpeechAnalyzer locale matching

- Reported symptoms: the demo model refused creative requests and answered in short English one-liners; PCC was never used (local always won); no way to verify live transcription used the SpeechAnalyzer AI model vs legacy SFSpeech.
- Root causes: the example's session instructions literally demanded "concise ... short responses" in English with `maximumResponseTokens: 400`; the `hybrid` routing policy tries `appleLocal` first so PCC is unreachable while local is available; `LiveTranscriptionService` required an exact BCP-47 locale match (regional locales like `es_CO` silently fell back to SFSpeech) and the example never passed a locale (native default `en_US`).
- `lib/src/orchestration.dart`: new `FoundationModelsRoutingPolicy.privateCloudFirst({allowLocalFallback, allowExternalFallback})` factory (PCC route first). PCC still requires iOS 27 (`PrivateCloudComputeLanguageModel` in `SessionRegistry.swift`).
- `LiveTranscriptionService.swift`: locale matching now falls back to any supported variant of the same language (exact BCP-47 first), so regional Spanish/English locales keep the SpeechAnalyzer engine; only truly unsupported languages fall back to SFSpeech. Event metadata already reports `engine`.
- `example/lib/main.dart`: rewrote instructions (same-language, creative requests allowed, complete answers), raised `maximumResponseTokens` to 2000, `Platform.localeName` used for orchestrator defaults, availability, diagnostics, and live transcription; new `ChatBackend` enum + AppBar popup selector (Auto hybrid / Apple on-device / Private Cloud Compute / Gemini, Gemini disabled without API key) that rebuilds orchestrator+chat and clears history; AppBar subtitle shows active backend; while listening, a caption under the chat shows locale + engine (`speechAnalyzer` vs `sfSpeech`); removed hardcoded `en_US` MaterialApp locale.
- Validations: `flutter analyze` clean at root and example; `flutter build ios --no-codesign` with Xcode 27 beta. No tests were created.

## Implemented on 2026-07-03, example: disable LLDB debugging for wireless iOS runs

- `example/pubspec.yaml`: added `flutter.config.enable-lldb-debugging: false` because LLDB attach over Wi-Fi on iOS 27 stalls `flutter run` at "Installing and launching..."; Flutter falls back to the Xcode-automation launch path. Dart-side debugging (hot reload, DevTools, Dart breakpoints) is unaffected; only native LLDB attach is skipped. Remove the flag (or use USB) when native breakpoints are needed.
- The "CocoaPods integration" hint printed by `flutter run` remains the known optional cleanup from the SPM migration; the example Podfile is non-standard so the migration is manual and still pending by choice.

## Implemented on 2026-07-06, fix: GenerationOptions init label differs per compiler (sampling: vs samplingMode:)

- Bug: `makeGenerationOptions` in `ios/cupertino_fundations_models/Sources/cupertino_fundations_models/SessionRegistry.swift` had a shared fallback that called `GenerationOptions(samplingMode:...)` outside any compiler guard. Xcode 27 beta (Swift compiler 6.4 / iOS 27 SDK) renamed the init label from `sampling:` to `samplingMode:`, so the old label breaks on Xcode 27 and the new label breaks on Xcode 26.
- Fix: the whole return path is now split by `#if compiler(>=6.4)` — under 6.4 the iOS 27 runtime branch adds `toolCallingMode:` and the runtime fallback uses `samplingMode:`; under older compilers the single return uses the iOS 26 SDK label `sampling:`. Same conditional-compilation pattern already shipped in the app-repo vendored copy of 0.0.3 (see release-pipeline.md there); publish as 0.0.4/0.1.0 to retire that vendored override.
- Validations: `flutter analyze` clean at root and example; `flutter build ios --no-codesign` with Xcode 27 beta succeeded (the `#else` branch could not be compiled locally — only Xcode-beta is installed — but it matches the documented iOS 26 SDK signature and the app-repo build that already passed). No tests were created.
- Release: `pubspec.yaml` bumped 0.1.0 → 0.1.1 (0.1.0 was never published to pub.dev; both ship together as 0.1.1) and `CHANGELOG.md` got a `## 0.1.1` Fixed entry describing the dual-toolchain compilation fix. Publishing 0.1.1 retires the vendored 0.0.3 copy + `dependency_overrides` in the app repo.

## Implemented on 2026-07-07, docs: complete 0.1.1 release notes before publishing

- `CHANGELOG.md` 0.1.1 previously only documented the Xcode 26/27 compilation fix; added the missing entries: `privateCloudFirst()` routing policy (Added), SpeechAnalyzer language-variant locale matching and example backend-selector UX pass (Changed), and the streaming end-of-stream hang fix (Fixed).
- `README.md`: added `privateCloudFirst()` to the built-in policies list.
- Validations: `flutter analyze` clean at root and example; `dart pub publish --dry-run` clean. Published 0.1.1 to pub.dev, committed and pushed. No tests were created.

## Regla de mantenimiento de contexto

Cada cambio futuro debe actualizar esta seccion con:

- Archivos creados/modificados.
- Responsabilidad de cada archivo.
- Capacidades Apple cubiertas.
- Version minima Apple requerida.
- Limitaciones o decisiones pendientes.
