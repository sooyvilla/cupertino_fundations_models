# Cupertino Foundation Models - Contexto vigente

## Iteración 2026-09-21

- Alcance: se añadió `FoundationModelSession.streamStructured` y el schema opcional al transporte interno de streaming; la ruta textual conserva sus snapshots y respuesta terminal.
- Decisiones: Swift valida cualquier schema presente, usa `ResponseStream<GeneratedContent>`, emite `rawContent.jsonString` acumulativo y sólo decodifica el último contenido completo. iOS 26 usa `includeSchemaInPrompt`; iOS 27 usa `ContextOptions`.
- Entrega: versión vigente 0.3.1 en pubspec, podspec y lock local del ejemplo, publicada en pub.dev y GitHub/main; documentación pública explica snapshots JSON parciales, `parsingFailure`, iOS 26 y los requisitos PCC existentes.
- Documentación ampliada por petición del usuario: guía PCC con elegibilidad, solicitud oficial, Account Holder, entitlement, perfiles/firma, opt-in y límites; enlazada desde todas las guías públicas pertinentes, con históricos preservados y marcados.
- Validaciones: lectura de fuentes, SDK instalado y diff; Terra y Sol ejecutaron cada uno una vez `git diff --check` sin salida fuera del alcance pedido. No tests, analyze, format, builds, app, simulador ni dispositivo; runtime iOS 26/27 y PCC sin validar. `dart pub publish` realizó las comprobaciones integradas de publicación sin advertencias; no se ejecutó dry-run separado.
- Equipo Astra: Luna medium recuperó firmas del SDK; Terra medium implementó; Sol high revisó de forma independiente el código sin defectos confirmados. Astra decidió el contrato y amplió documentación/entrega. Roles/modelos según configuración; el cliente no expone metadatos suficientes para verificar el modelo/esfuerzo del principal.
- Commit de entrega `95685736b30005f9e20f5f08dcfbfdddd3973293`; push a origin/main y SHA remoto confirmados. Pub.dev aceptó el upload y su API confirmó `latest=0.3.1`, fecha `2026-09-21T08:01:10.512941Z`, archive SHA-256 `6588dd3f788c72433780ab8e8f9b610e602ec4fd496c1a0c6f72ed2133010937`. Archive anunciado de 124 KB, incluye guía PCC y docs actualizadas. Este cierre documental no cambia el contenido del paquete publicado.
- Solo existe el checkout principal, sin worktrees adicionales ni ramas creadas. La app consumidora aún debe resolver 0.3.1 y reconstruir su host iOS; no se modificó ni ejecutó AI My Money.

## Iteración 2026-09-19

- Objetivo: auditar fuentes, documentación, ejemplo, fallos históricos y SDK oficial 27.2; preparar la próxima entrega sin publicar ni aumentar todavía la versión.
- Estado inicial: `main` en `080aa00`, 31 archivos modificados y tres nuevos de trabajo previo. Se preservó esa base; copia de fuentes/configuración/documentación en `/tmp/cfm-audit-2026-09-19-baseline`, sin archivos de entorno.
- Versión vigente **0.3.0**, publicada y verificada en pub.dev el 2026-09-19 (Bogotá; 2026-09-20 UTC), y entregada a GitHub/main. Incompatible con 0.2.x por retirar API híbrida. No se declara 1.0: faltan validaciones de runtime y contrato estable.
- Toolchain observado: Flutter 3.47.4 / Dart 3.13.3, Xcode 27.2 beta `27B5019j`, SDK iOS 27.2, Swift 6.4. Deployment target iOS 15; generación exige 26+ y funciones nuevas 27+ con guards de SDK/runtime.
- Git: `main` para entregas expresamente autorizadas; política confirmada en la continuación de entrega. La auditoría inicial no creó commits ni publicó. No pruebas ni app/simuladores/dispositivos en esta iteración.

## Contrato y arquitectura actuales

- Paquete Flutter iOS; Dart tipa contratos y administra sesiones/streams. Swift integra FoundationModels, Speech, Vision, PDFKit y picker. Cero dependencias runtime externas; CocoaPods y Swift Package Manager conservados.
- Se retira `orchestration.dart` y el proveedor Gemini del ejemplo. La aplicación consumidora decide API/local y conserva consentimiento, credenciales, historial, reintentos e idempotencia.
- Local por defecto; PCC requiere política explícita, opt-in Info.plist, entitlement de Apple y disponibilidad. El flag de opt-in no prueba el entitlement. Automatic + whenExplicit no selecciona cloud. Cada request puede restringir a never pero no cambiar el backend de una sesión.
- Un request por sesión; cancelación/disposal esperados. Callbacks de streams por request; transporte predeterminado compartido. Sesión con cancelación fallida debe recrearse.
- StructuredSchema soporta raíz objeto y subset acotado; validación estricta de tipos/constraints. Tools con timeout/budget y resultados pequeños. Autorización y efectos externos son responsabilidad de la app.
- Speech posee política separada (onDevice/automatic/server), verificación de textos de privacidad y limpieza serializada; solo una suscripción de micrófono por transporte.
- Adjuntos: extracción UTF-8/PDF y Vision para imágenes. Attachment multimodal nativo y getters PCC de idiomas/capabilities siguen bloqueados por crashes históricos; no se habilitan en 27.2 sin evidencia física.
- APIs nuevas 27.2 DataAttachment/DataEntry verificadas en referencia Apple y SDK, documentadas pero no expuestas. Dynamic Profiles/Core AI/model executors/transcript import no implementados.

## Mapa de documentación

- `README.md`: entrada pública, compatibilidad, privacidad y ejemplos breves.
- `implementation_for_agents.md`: contrato de implementación con API existente y límites.
- `doc/usage.md`: funcionalidades y semántica completa.
- `doc/app-owned-routing.md`: coordinación aplicación/API/local.
- `doc/migration-0.3.0.md`: migración de la API híbrida eliminada.
- `doc/troubleshooting.md`: bugs/crashes recuperados, mitigaciones y evidencia.
- `doc/ios-27.2-audit-2026-09-19.md`: investigación oficial y auditoría actual.
- `CHANGELOG.md`: notas definitivas de 0.3.0 primero, seguidas de las versiones históricas; sin encabezado Unreleased vacío.

## Validaciones y pendientes

- Formato sin cambios; `flutter analyze --no-pub` sin incidencias. Ocho snippets Dart de documentación analizados correctamente en workspace temporal, sin ejecutarlos.
- Build Release sin firma del example con plugin SPM y Xcode 27.2 correcto. Build separado del target CocoaPods con podspec real correcto. Ambos con `SWIFT_STRICT_CONCURRENCY=complete` y `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`; hubo avisos de sistema de build/AppIntents, no errores Swift.
- `git diff --check` y enlaces locales de 13 documentos correctos. Los archivos de tests coinciden byte por byte con el snapshot inicial.
- `dart pub publish --dry-run` generó archive de 119 KB, exit 65 por dos advertencias Git: archivos modificados y router eliminado aún indexado (Pub lo reporta como ignored). Archive revisado: sin router, AGENTS/context ni tests; incluye guías y nuevas fuentes nativas. No se publicó.
- Revisión independiente Sol cerrada sin defectos prioritarios confirmados pendientes. Corrigió la observación de schemas malformados y detectó una regresión temporal del nombre opcional de tools, también corregida antes de builds finales.
- Sin ejecución de tests, app, simuladores ni dispositivos; la matriz física beta 8 del 1 de septiembre es histórica y no valida runtime 27.2 ni PCC.
- Pendiente de futura autorización: validación física 27.2, regresión runtime iOS 26, permisos/assets/Speech, PCC con entitlement y pruebas automatizadas. El versionado y la entrega Git/pub.dev de 0.3.0 se completaron en la continuación autorizada de abajo.
- Evidencia local: `/tmp/cfm-final-analyze.log`, `/tmp/cfm-final-native-build.log`, `/tmp/cfm-cocoapods-build.log`, `/tmp/cfm-doc-examples-analyze.log`, `/tmp/cfm-publish-dry-run.log`.

Equipo Astra invocado por el usuario: Luna low para fuentes oficiales, Terra medium para retirar híbrido/migrar example, Sol high para revisión independiente de solo lectura. Principal previsto Astra/high por la skill, sin metadatos de cliente suficientes para verificar modelo/esfuerzo.

## Preparación de entrega 0.3.0 - 2026-09-19

- Usuario solicitó subir la versión con las correcciones del changelog para actualizar la presentación pública.
- Pubspec/podspec sincronizados en 0.3.0. Notas trasladadas a CHANGELOG; eliminado borrador next-release. README, guía de agentes, ejemplo y migración describen la versión concreta.
- Pub.dev confirmó 0.2.1 como latest antes de la entrega y que 0.3.0 aún no existe. Sus enlaces relativos de documentación apuntan a GitHub/main: se requiere sincronizar las fuentes para no publicar enlaces nuevos rotos.
- Metadatos 0.3.0 alineados en pubspec/podspec/lock del example; changelog comienza en 0.3.0 y enlaces locales correctos. `flutter analyze --no-pub` sin incidencias; dry run 119 KB con solo las dos advertencias Git esperadas (árbol modificado y router eliminado aún indexado). No hay cambios de código ni ejecución de tests/app en esta continuación.
- `origin/main` comprobado por ls-remote en `080aa0004e6bcde2b76b650b1bb1010e3bcba2ad`, coincide con el HEAD de partida. Usuario confirmó: «Subirlo, tanto a git como a pub.dev». Se documenta política `main` para entregas autorizadas y se ejecutó commit/push y publicación de 0.3.0.
- Logs de esta preparación: `/tmp/cfm-030-analyze.log` y `/tmp/cfm-030-dry-run.log`.
- Commit de entrega: `bc17a6fe5b13b53bc103a8f32b905ab72b005834` (`release: 0.3.0 native sessions and stability hardening`), push exitoso a `origin/main`; SHA remoto comprobado después del push.
- Tras el commit, `dart pub publish --dry-run` pasó con **0 warnings**; archive 119 KB. `dart pub publish --force` completó el upload con aceptación explícita del servidor.
- API de pub.dev verificó `latest=0.3.0`, publicación `2026-09-20T02:45:04.664972Z` y archive SHA-256 `0c9967b8ddca4cdfc82a72d9a403ca07ee1fef2d774bc6c80583cbcea5779f81`. Hash del archivo descargado coincide; nueve archivos clave coinciden byte por byte con las fuentes locales, router eliminado ausente, AGENTS/context excluidos.
- Página pública de changelog verificada: primer h2 0.3.0, sin encabezado Unreleased. README/guías de 0.3.0 subidos a GitHub para que funcionen los enlaces relativos de pub.dev.
- Evidencia adicional: `/tmp/cfm-030-clean-dry-run.log` y `/tmp/cfm-030-publication.log`. Solo existe el checkout principal en los worktrees registrados; no se creó ni eliminó otro worktree. Este cierre se registra en un commit documental posterior, sin cambiar el contenido publicado.

## Historial conservado

Las secciones siguientes son registros fechados, no la especificación vigente. Sus referencias a híbrido, proveedores externos, versiones beta o APIs deshabilitadas describen aquel estado. Para comportamiento actual, prevalece el contrato de arriba y la documentación vigente.

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
- Pending after this pass: direct Photos picker, SpeechAnalyzer for file transcription, Dynamic Profiles, iOS 27 `LanguageModel` protocol bridge.
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

## Implemented on 2026-08-12, iOS 27 beta 5 API alignment, 0.2.0

- Official research: `doc/ios-27-beta-5-foundation-models.md` distinguishes beta 5 fixes from the broader iOS 27 API additions. Apple beta 5 resolves six Foundation Models defects and does not introduce a separate beta-5-only API family. The local SDK interface from Xcode 27 beta 5 build `27A5194q` was used to verify current symbols and deprecations.
- Breaking Dart alignment: `ToolCallingMode.allowed|required|disallowed` replaces `ToolCallingPolicy`; reasoning values are `light|moderate|deep`; cumulative streaming uses `TextSnapshotEvent`; `structuredValue` is `Object?`; `contextSizeExceeded` replaces `contextExceeded`; PCC quota state is typed; `ModelCapability.externalProvider` was removed because the Dart adapter is not a native Apple capability.
- New Dart APIs: `CupertinoFoundationModels.countTokens(Prompt)`, `FoundationModelSession.countTokens()`, typed `ModelUsage`, sampling top-K/probability/seed controls, `ReasoningLevel.custom()`, and `TranscriptErrorHandlingPolicy`.
- Native Swift: iOS 27 structured generation uses the `ContextOptions` overload; response and stream usage is forwarded; image bytes are decoded into `Attachment<ImageAttachmentContent>`; runtime vision/reasoning capabilities come from `LanguageModelCapabilities`; PCC quota exposes below/approaching/limit/reset state.
- Error bridge: iOS 27 typed errors from `LanguageModelError`, `SystemLanguageModel.Error`, `LanguageModelSession.Error`, `PrivateCloudComputeLanguageModel.Error`, and `GeneratedContent.ParsingError` map to stable Dart codes and safe recovery details. Localized-string parsing remains only as a compatibility fallback.
- Versioning and docs: `pubspec.yaml` and podspec moved from 0.1.1 to 0.2.0; `CHANGELOG.md`, `README.md`, existing test fixtures, `AGENTS.md`, and `context.md` were synchronized. Dynamic Profiles and a native arbitrary `LanguageModelExecutor` bridge remain explicit future work because they require stateful typed Swift integration, not a static channel map.
- Allowed validations: `dart format lib example/lib test`; `flutter analyze` clean at the package root and example; `flutter build ios --no-codesign` from `example/` with Xcode 27 beta 5 succeeded and produced `Runner.app`; `dart pub publish --dry-run` found only the expected dirty-tree warning because no commit was authorized. No tests, simulator, app execution, signing, commit, push, publish, or deployment were performed. The known optional CocoaPods-to-SPM cleanup warning remains.

## Iteracion 2026-08-12 - Estabilidad de chat y transcripcion en iOS 27 beta 5

- Sintomas reportados: el `example` podia cerrarse al enviar mensajes; la transcripcion en vivo podia cerrarse o comportarse de forma irregular; la transcripcion de archivos podia tardar demasiado. No habia reportes `.ips`/`.crash` de Runner disponibles localmente, por lo que no se atribuye una pila concreta sin evidencia de dispositivo.
- Causas comprobadas en codigo: el ejemplo activaba `_sending` despues de esperar la cancelacion del microfono, permitiendo dos envios durante esa ventana; las sesiones Dart no impedían solicitudes superpuestas aunque Apple solo admite una por sesion; `GenerationOptions.timeout` y `AudioTranscriptionRequest.timeout` no se aplicaban; un arranque asincrono de microfono podia continuar despues de cancelar su suscripcion; el fallback de `AVAudioEngine` instalaba un tap sin validar sample rate ni channel count, condicion que puede terminar el proceso dentro de AVFoundation.
- Estabilidad de generacion: `FoundationModelSession` y `FoundationModelsChatSession` ahora son single-flight, reportan `concurrentRequests`, protegen sesiones ya descartadas y cancelan la solicitud nativa cuando vence `GenerationOptions.timeout`. El ejemplo marca el envio antes de detener la voz y captura fallos asincronos no tipados para mostrarlos en la burbuja.
- Speech moderno: `SpeechTranscriptionService.swift` usa `SpeechAnalyzer`/`SpeechTranscriber` para archivos on-device desde iOS 26. En iOS 27 beta 5 usa `AssetInputSequenceProvider`; `server` y runtimes anteriores conservan `SFSpeechURLRecognitionRequest`. `AudioTranscriptionRequest.timeout` cancela la tarea nativa, su continuacion se resuelve una sola vez y Dart recibe `transcriptionTimeout`.
- Captura en vivo: `LiveTranscriptionService.swift` usa `CaptureInputSequenceProvider` en iOS 27 beta 5, invalida inicios tardios con un token por suscripcion y limpia capture/analyzer/tasks al cancelar. iOS 26 conserva conversion manual con validacion de formato; iOS 13+ y modo server conservan SFSpeech.
- Documentacion: `README.md`, `CHANGELOG.md`, `implementation_for_agents.md` y `doc/ios-27-beta-5-foundation-models.md` se alinearon con la arquitectura Speech actual y las reglas de concurrencia/timeout.
- Validaciones permitidas: `dart format lib`; `flutter analyze` limpio en raiz y `example`; `flutter build ios --no-codesign` desde `example/` con Xcode 27 beta 5 build `27A5194q` exitoso y `Runner.app` de 16.8 MB; `git diff --check` limpio; `dart pub publish --dry-run` valido el paquete y solo aviso que el arbol Git tiene cambios sin commit. No se ejecutaron tests, app, simulador ni dispositivo. La comprobacion definitiva del cierre reportado y la latencia real requiere reproduccion manual en el dispositivo afectado o un crash log `.ips`; el codigo y el build por si solos no prueban comportamiento runtime.
- Pendientes ajenos a esta correccion: Dynamic Profiles, bridge nativo arbitrario de `LanguageModelExecutor`, selector directo de Photos y migracion opcional del ejemplo para retirar la integracion CocoaPods residual.

## Iteracion 2026-08-12 - Crash nativo de diagnosticos PCC en iOS 27 beta 5

- Evidencia de dispositivo: los incidentes `93FB4FC2-46CD-47E1-88A0-A4EEAD3D5EFB`, `5FDE2A28-5A57-46CC-9744-2413528DFA90` y `E21C1254-1AB1-4872-8141-C7AEE2760FAB` terminaron el `Example` con `EXC_BAD_ACCESS/SIGSEGV` en `AvailabilityService.diagnostics(arguments:)`, simbolicado en `AvailabilityService.swift:119`, al leer `PrivateCloudComputeLanguageModel.supportedLanguages`.
- Un primer guard por `PrivateCloudComputeLanguageModel.availability == .available` no fue suficiente: los incidentes posteriores de las 21:47 terminaron con `EXC_BAD_ACCESS/SIGBUS` en la misma propiedad, simbolicada en la nueva linea 130. Esto prueba un fallo del runtime de iOS 27 beta 5, no una excepcion Swift recuperable.
- `AvailabilityService.swift` ya no consulta `supportedLanguages`, `supportsLocale` ni `capabilities` sobre PCC. Conserva `availability` y cuota, que completaron correctamente antes del fallo, y devuelve `canReadPrivateCloudLanguageSupport: false`; el diagnostico local sigue reportando idiomas normalmente.
- Validacion en el iPhone fisico `iPhone Sebas` con iOS 27 beta 5 `24A5408d`: build release con Xcode 27 beta 5 exitoso, instalacion y lanzamiento exitosos, consulta automatica de diagnosticos sin nuevo reporte `.ips`, y proceso exacto del bundle `com.example.cupertinoFundationsModelsExample` vivo. La app se dejo abierta para reproducir manualmente envio Hybrid/Offline y transcripcion; esos flujos requieren interaccion del usuario para confirmar si existe una segunda pila independiente.
- No se ejecutaron ni crearon tests. No se hizo commit, push, publicacion ni cambio de version para esta correccion.

## Iteracion 2026-08-12 - Adjuntos y fallback seguro de imagenes

- Evidencia de dispositivo: el incidente `90EBF955-2ACF-4858-9B73-01048EF5393F` termino con `KERN_PROTECTION_FAILURE` en `Attachment(imageURL:)`; `7503E9F2-AFE3-4A27-AA53-291F2C1E4D2B` avanzo hasta `Attachment.label(_:)`; `A2055753-75D3-4A7E-856C-6FFDB0A599E0` termino al convertir `Attachment<ImageAttachmentContent>` en `Prompt`. Las tres rutas apuntan a una pagina nula antes de que Swift pueda lanzar una excepcion recuperable.
- `SessionRegistry.swift` ya no invoca el ABI multimodal nativo defectuoso de iOS 27 beta 5. Las imagenes se validan por contenido, se limitan a 50 MB, se reducen a 4096 px y Vision extrae OCR, clasificaciones y codigos de barras como contexto seguro para Foundation Models.
- Los adjuntos de bytes aceptan tanto `FlutterStandardTypedData` como listas de enteros del codec. Texto, Markdown, JSON y CSV requieren UTF-8 y un maximo de 5 MB; PDFKit extrae PDFs con texto; audio y binarios no compatibles devuelven un error tipado. Ningun adjunto invalido se descarta silenciosamente.
- `AvailabilityService.swift` deja de anunciar el ABI nativo de imagen y reporta `nativeImageAttachmentsUsable: false` junto con `imageFallback: visionPreprocessing`. El ejemplo permite seleccionar cualquier archivo, no solo imagenes.
- El selector conserva el nombre original para UI aunque la copia temporal use UUID. Los errores deterministas de adjuntos sobreviven al agotamiento de rutas Hybrid; `.doc` y `.docx` informan que iOS no tiene importador Office Open XML y piden exportar como PDF con texto o UTF-8, en vez de mostrarse como `modelUnavailable`.
- Validacion en iPhone fisico con iOS 27 beta 5 `24A5408d`: build release con Xcode 27 beta 5 exitoso, instalacion y lanzamiento exitosos, sin un nuevo `.ips` durante la ventana solicitada para reintentar la imagen, y proceso exacto del bundle vivo como PID 1470. La respuesta visual final requiere confirmacion del usuario. No se ejecutaron ni crearon tests; no se hizo commit, push, publicacion ni cambio de version.

## Iteracion 2026-08-12 - Idioma unificado para IA y transcripcion en vivo

- Se agrego `CupertinoFoundationModels.getSupportedLanguages()` y el DTO `FoundationModelsLanguage`. La API nativa calcula en runtime la interseccion entre `SystemLanguageModel.supportsLocale(_:)` y `SpeechTranscriber.supportedLocales`, y marca los recursos ya presentes mediante `SpeechTranscriber.installedLocales`; no existe una lista de idiomas codificada a mano.
- `AvailabilityService.swift` concentra la consulta de compatibilidad y nombres localizados. El MethodChannel, la interfaz de plataforma y la fachada Dart exponen el resultado tipado sin dependencias adicionales.
- El `Example` incluye un selector buscable en el AppBar. El locale elegido configura instrucciones y defaults del orquestador para Apple local, PCC/Hybrid y proveedor externo, ademas de availability, diagnostics y `LiveTranscriptionRequest`.
- Cambiar idioma detiene una transcripcion activa, descarta la sesion anterior y limpia los mensajes para impedir que el transcript del idioma previo condicione la nueva respuesta. La hoja indica cuando Speech debe descargar el recurso en el primer uso.
- Documentacion sincronizada en `README.md`, `example/README.md`, `CHANGELOG.md`, `implementation_for_agents.md` y `doc/ios-27-beta-5-foundation-models.md`.
- Validaciones realizadas sin tests: formato Dart, `flutter analyze` limpio, `git diff --check` limpio y build iOS release firmado con Xcode 27 beta 5 exitoso. La compilacion se instalo y se lanzo mediante CoreDevice en `iPhone Sebas` con iOS 27 beta 5; el proceso exacto del bundle siguio vivo como PID 882 y no aparecio un nuevo crash log de Runner durante la comprobacion. El dispositivo estaba bloqueado al capturar la pantalla, por lo que la revision visual de la hoja y el cambio manual de idioma quedan pendientes al desbloquearlo.

## Iteracion 2026-08-12 - Release 0.2.1

- Se preparo la version patch `0.2.1` para distribuir conjuntamente las correcciones de crashes de diagnostics PCC, adjuntos de imagen/archivo, concurrencia y timeouts, Speech moderno y la seleccion unificada de idioma.
- `pubspec.yaml`, el podspec iOS, la dependencia mostrada en `README.md` y `CHANGELOG.md` quedaron sincronizados con `0.2.1`.
- La entrega autorizada tiene como destino directo `main`, `origin/main` y pub.dev. No incluye pruebas nuevas ni ejecucion de tests por la regla del repositorio.
- Validaciones de la candidata: `dart format` sin cambios, `flutter analyze` limpio, `git diff --check` limpio, build iOS release sin firma con Xcode 27 beta 5 exitoso (`Runner.app` de 16.9 MB) y `dart pub publish --dry-run` valido el archivo comprimido de 102 KB. Antes del commit, el unico aviso del dry-run fue el arbol Git modificado esperado.

## Iteracion 2026-09-01 - Auditoria actual iOS 27 y estabilidad integral

- La documentacion publica de Apple consultada el 2026-09-01 identifica iOS/iPadOS 27 beta 8 `24A5430a` y Xcode 27 beta 6 `27A5252f` como betas vigentes. El equipo local usa Xcode 27 beta 6 `27A5252f`, SDK iOS 27 `24A5422a` y Swift 6.4; el build local aun no demuestra comportamiento runtime de beta 8.
- Se inspeccionaron las interfaces Swift instaladas para `FoundationModels`, `Speech`, `AVFoundation`, PCC, opciones de generacion, errores tipados, streaming, tools y proveedores de captura. Apple mantiene una sola solicitud activa por `LanguageModelSession`, exige una salida para tool calling `required` y expone finalizacion/cancelacion explicitas en `SpeechAnalyzer`.
- Los streams de generacion ya no comparten un `EventChannel`: `CupertinoFoundationModelsPlugin.swift` y `method_channel_cupertino_foundation_models.dart` multiplexan callbacks por `requestId`, permiten streams simultaneos de sesiones distintas y esperan cancelacion nativa antes de reutilizar o descartar una sesion.
- `SessionRegistry` recibe `ToolBridge` atomicamente en su inicializador; las sesiones permanecen reservadas durante cancelacion; los callbacks terminales liberan tracking antes de notificar a Dart; y un timeout de stream no libera `_requestActive` hasta que la cancelacion Apple termina.
- El tracking nativo usa tokens UUID para impedir que una tarea vieja elimine una nueva. `ToolBridge.swift` resuelve continuaciones una sola vez, tiene timeout/cancelacion nativos y limita la salida; `GenerationOptions.maximumToolCalls` agrega un presupuesto por solicitud de 1 a 128, con default 16.
- `LiveTranscriptionService.swift` prepara el analyzer, conserva y encadena toda limpieza anterior incluso tras `EventChannel.onCancel`, y serializa `AVCaptureSession.startRunning`/`stopRunning`. `SpeechTranscriptionService.swift` prepara el analyzer antes de consumir audio.
- Los adjuntos se limitan antes de leerlos; los PDF acotan texto extraido; las imagenes bajan a 2048 px y ejecutan OCR, clasificacion y codigos en una sola pasada Vision. El ABI nativo de imagen y los getters PCC que provocaron crashes en beta 5 siguen deshabilitados hasta tener evidencia fisica nueva.
- `AvailabilityService.swift` deja de anunciar Dynamic Profiles, que aun no tienen bridge, solo reporta `fullPower` si PCC esta disponible y ya no infiere soporte por la version de iOS cuando el SDK compilador carece de `FoundationModels`. Los motivos PCC usan los casos tipados actuales del SDK instalado.
- Los entry points Flutter/UIKit quedaron aislados en `@MainActor`; `SessionRegistry` conserva el estado de modelos dentro de su actor; `FlutterChannelValue` transporta exclusivamente payloads inmutables del codec; y los callbacks Speech capturan snapshots `Sendable` antes de reanudar trabajo asincrono. SPM y CocoaPods pasan `SWIFT_STRICT_CONCURRENCY=complete` con warnings Swift tratados como errores.
- Flutter estable vigente es 3.47.2 con Dart 3.13.2. Se descargo una copia arm64 temporal, se verifico su SHA-256 oficial y se uso sin modificar el SDK compartido 3.44.4. Flutter 3.47 actualizo las exclusiones del analyzer, sincronizo `example/pubspec.lock` con la version local 0.2.1 y actualizo el checksum Flutter de `example/ios/Podfile.lock`; no se agregaron dependencias runtime.
- Documentacion sincronizada en `README.md`, `CHANGELOG.md`, `implementation_for_agents.md` y `doc/ios-27-current-audit-2026-09-01.md`. No se cambio version, API de deployment iOS 15, dependencias runtime, podspec ni manifiesto SPM.
- Validaciones autorizadas: `flutter analyze` limpio; 26 tests Dart aprobados; build iOS release sin firma exitoso por SPM con Xcode 27 beta 5; SPM y el framework CocoaPods compilan y pasan `xcodebuild analyze` en modo Swift 6, concurrencia completa y warnings como errores; CocoaPods tambien cubre simulador arm64/x86_64 al forzar iOS 15. La copia aislada Flutter 3.47.2 repitio analyze, 26 tests y build release de 17.1 MB. `dart pub publish --dry-run` con Dart 3.13.2 construyo y valido el archivo de 114 KB; su unico warning y codigo de salida 65 corresponden al arbol sin commit esperado. `pod lib lint` sin override queda bloqueado por su fixture Flutter 3.13 con target iOS 11, incompatible con el minimo de simulador de Xcode 27, no por el plugin.
- Apple confirma que `24A5430a` es iOS 27 beta 8. El `iPhone Sebas`, compatible con Apple Intelligence y con Developer Mode activo, sigue `unavailable` en CoreDevice; no se pudo abrir la app ni ejecutar la matriz fisica. Tampoco se abrio simulador porque la politica global exige que el usuario solicite DeviceHub explicitamente.
- Pendiente para afirmar validacion runtime completa: instalar Xcode 27 beta 6 o posterior y ejecutar la matriz descrita en el documento de auditoria sobre un iPhone Apple Intelligence con iOS 27 beta 8 o posterior, incluyendo crashes `.ips`, streams concurrentes/cancelados, PCC, tools, Speech, adjuntos e Instruments.
- No se creo rama, commit, push, publicacion ni despliegue.

## Iteracion 2026-09-01 - Selector Speech y guarda preventiva de PCC

- `example/lib/main.dart` separa visualmente el backend que genera respuestas del motor de transcripcion en vivo. El selector junto al microfono ofrece Automatic, On-device only y Apple Speech server; cambiarlo detiene limpiamente la captura activa sin borrar el texto dictado.
- Automatic prioriza `SpeechAnalyzer` local y conserva el fallback existente; On-device only impide la ruta remota; Apple Speech server usa `SFSpeechRecognizer`, requiere red y no es Private Cloud Compute.
- `PrivateCloudComputeAccess.swift`, `AvailabilityService.swift` y `SessionRegistry.swift` exigen el opt-in `CupertinoFoundationModelsPrivateCloudComputeEnabled=true` antes de inicializar `PrivateCloudComputeLanguageModel`. Sin el opt-in, PCC devuelve `missingEntitlement`; el modo Automatic continua hacia el modelo local.
- El opt-in complementa, pero no reemplaza, el entitlement administrado `com.apple.developer.private-cloud-compute` y la firma/provisioning correspondiente. El example lo mantiene en `false` para fallar de forma recuperable hasta que Apple conceda y se configure el entitlement.
- Documentacion sincronizada en `README.md`, `example/README.md`, `implementation_for_agents.md` y `CHANGELOG.md`. No se agregaron dependencias, no cambio la API Dart publica, el deployment target sigue en iOS 15 y se preservaron los cambios preexistentes sin commit.
- Validaciones de esta iteracion: `dart format example/lib/main.dart` sin cambios; `plutil -lint` limpio; `git diff --check` limpio; `flutter analyze` limpio en raiz y example; build iOS release sin firma exitoso con Xcode 27 beta 6 (`27A5252f`), generando `Runner.app` de 17.0 MB. No se ejecutaron tests, app, simulador ni dispositivo; la confirmacion visual y la reproduccion runtime de PCC/Speech quedan pendientes en hardware con la firma y el entitlement correctos.
- Ejecucion fisica autorizada posterior: Flutter detecto `iPhone Sebas` (`00008150-0012689E3640401C`, iPhone 17 Pro Max), compilo el example en release con firma del team `MYFZ6WK59C`, lo instalo y lo lanzo. Luego CoreDevice relanzo directamente `com.example.cupertinoFundationsModelsExample` y confirmo vivo el ejecutable exacto instalado como PID `6909`. La app quedo abierta; no se hizo una auditoria visual ni se ejercitaron PCC o Speech desde la interfaz.

## Iteracion 2026-09-01 - Xcode beta 6, runtimes y cierre fisico iOS 27 beta 8

- Se reemplazo la instalacion activa por Xcode 27 beta 6 `27A5252f`, SDK iPhoneOS 27 `24A5422a` y Swift 6.4; `xcode-select` apunta a `/Applications/Xcode-beta.app/Contents/Developer`. La firma y Gatekeeper de la aplicacion descargada fueron validados antes del reemplazo.
- Se instalo el runtime iOS 27 recomendado por ese Xcode, build `24A5423a`, y se elimino el runtime anterior `24A5355p` junto con sus dispositivos viejos. Se crearon simuladores actuales de iPhone 17/17 Pro/17 Pro Max/17e/Air y iPad A16/Air M4/mini A17 Pro/Pro M5. Se preservaron dos simuladores `Codex SemillaX QA` creados y usados por otra tarea concurrente.
- `example/lib/smoke_test.dart` y el flag `CFM_SMOKE_TEST` agregan una matriz release reproducible que persiste su resultado JSON en el contenedor temporal. No cambia la ejecucion normal ni agrega dependencias.
- El iPhone fisico `00008150-0012689E3640401C`, iPhone 17 Pro Max con iOS 27 beta 8 `24A5430a`, completo la matriz final en 7.886 segundos: capabilities, 29 idiomas, diagnostics, availability, audio por `SpeechAnalyzer`, inicio/cancelacion de captura en vivo, tokenizacion, prewarm/respuesta/usage, structured output, una tool real, stream completo, cancelacion y reutilizacion, dos streams simultaneos, content tagging e imagen por Vision. Todas las comprobaciones ejecutables aprobaron.
- PCC devolvio `missingEntitlement`, comportamiento esperado del example sin el entitlement administrado de Apple; no se afirma una generacion PCC. El ABI nativo de imagen y los getters PCC que fallaron en beta 5 permanecen deshabilitados, usando Vision y diagnosticos protegidos.
- Se encontro un `.ips` de Runner de las 14:00 anterior a la matriz final, con `SIGTRAP`/assert de cancelacion dentro del framework Foundation Models de Apple. Las matrices endurecidas posteriores no generaron un `.ips` nuevo; el resultado verde corresponde a esas ejecuciones posteriores.
- Validaciones finales: `flutter analyze` limpio, 26 tests Dart aprobados, build y analyze SPM/CocoaPods con Swift 6 strict concurrency y warnings como errores, build iOS release firmado de 17.1 MB, e instalacion de la ejecucion normal `0.0.1` en el iPhone mediante CoreDevice. No se hizo commit, push, publicacion ni cambio de version del paquete.
- Limpieza: queda una sola seleccion activa de Xcode y un solo runtime iOS 27. Los artefactos descargados y la copia vieja propiedad del usuario actual fueron retirados. macOS impidio retirar una copia historica oculta propiedad de UID 502 y el XIP beta 4 protegido en Descargas sin elevacion o confirmacion de Finder; ninguno esta seleccionado ni registrado como toolchain activo.

## Regla de mantenimiento de contexto

Cada cambio futuro debe actualizar esta seccion con:

- Archivos creados/modificados.
- Responsabilidad de cada archivo.
- Capacidades Apple cubiertas.
- Version minima Apple requerida.
- Limitaciones o decisiones pendientes.
