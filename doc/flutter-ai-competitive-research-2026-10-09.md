# Investigación competitiva de IA para Flutter y mejoras opcionales

Fecha de corte: **9 de octubre de 2026**. Base local: `cupertino_fundations_models` **0.5.0**, commit `751705eb844bd7a0679ef46ad7e2790896b0ae54`.

Este documento conserva la investigación de la base 0.5.0. La implementación
posterior prepara F01–F10 en núcleo 1.9.0 local, con generador compatible 1.8.0; consultar `usage.md` y `CHANGELOG.md` para
el contrato y estado actual. La serie F01–F10 está preparada; mejoras posteriores siguen fuera de esta entrega.

## Decisión principal

Conviene potenciar primero la extracción estructurada en iOS y macOS: restricciones de valores, más formas de esquema, importación de un subconjunto explícito de JSON Schema y conversión a tipos Dart. Después, historial restaurable y seguimiento de disponibilidad. Son mejoras que pueden reducir motivos concretos para elegir otro puente de Foundation Models sin cambiar el motor ni exigir dependencias de terceros en el núcleo.

**Los esquemas escritos a mano y la generación de código Dart deben ser alternativas.** Sebastián confirmó que su reserva se refería a generar código Dart, pero acepta ofrecerlo si aporta valor. Un generador separado tendría sentido en proyectos con muchos tipos; para unas pocas extracciones, la vía manual es más sencilla. La IA que integre el paquete deberá preguntar cuál prefiere el usuario, respetando una elección previa. La sección de flujo de integración incluye la pregunta y sus condiciones.

También existen razones válidas para elegir otro paquete que no se resuelven añadiendo métodos al puente Apple: Android/Windows/Linux/web, pesos propios, uso en equipos sin Apple Intelligence, embeddings y motores multimodales alternativos. La decisión recomendada es facilitar integraciones opcionales y mantener el núcleo Apple local/PCC. Convertirlo en un runtime universal sería otro proyecto, con dependencias, distribución de modelos y mantenimiento por plataforma.

La investigación original contiene decisiones propuestas; su elaboración **no implementó esas mejoras**. Las notas de estado posteriores identifican F01–F10 ya preparados. Tampoco establece que un competidor sea más rápido, preciso o estable: no se hicieron comparaciones de ejecución ni investigación con usuarios.

## Método y límites de la evidencia

- Búsquedas de paquetes en pub.dev, documentación de sus mantenedores, repositorios y referencias oficiales Apple, Google y Microsoft.
- Consulta directa de `https://pub.dev/api/packages/<paquete>` para fijar versiones, fechas y manifiestos. Los resultados de buscadores tenían versiones antiguas y fechas relativas inconsistentes.
- Lectura en memoria de archives publicados para los competidores Apple principales y para precisar esquemas de `llamadart`, `flutter_edge_ai` y `flutter_local_llm`. No se instalaron paquetes ni ejecutó su código.
- Contraste con los contratos Dart y Swift actuales de este repositorio. Se consultaron README, changelog, contexto y manifiestos.
- **M**: evidencia de manifiesto/registro. **D**: capacidad declarada en documentación. **C**: contrato o ruta correspondiente localizado en código. Ninguna de estas letras significa prueba runtime en una app consumidora.

El catálogo cubre los competidores encontrados y relevantes para la decisión, incluyendo sus sucesores y alternativas adyacentes. No es una garantía de haber enumerado todo paquete existente. Los repositorios `main` pueden avanzar respecto de un release; las conclusiones de código se anclan al archive indicado cuando se inspeccionó.

## Qué ya tenemos y no hay que reinventar

La base se comprobó en [la API de esquemas](../lib/src/schema.dart), [sesiones](../lib/src/session.dart), [generación](../lib/src/generation.dart), [la fachada](../lib/src/cupertino_foundation_models.dart), [disponibilidad](../lib/src/availability.dart) y [el mapper Swift](../darwin/cupertino_fundations_models/Sources/cupertino_fundations_models/SchemaMapper.swift).

| Capacidad actual | Alcance relevante para la comparación |
| --- | --- |
| iOS/iPadOS y macOS | Fuente Swift compartida en `darwin/`, CocoaPods y SwiftPM; deployment iOS 15/macOS 12, generación desde OS 26 y disponibilidad nativa. |
| Esquemas guiados en runtime | Objetos, strings, enums de strings, enteros, números, booleanos, arrays y objetos anidados; no requiere generador. |
| Resultado estructurado | JSON final y `ModelResponse.structuredValue` de tipo `Object?`; falta una comodidad pública genérica de decodificación a `T`. |
| Streaming estructurado | `streamStructured()` y `stream(schema: ...)`; snapshots de texto JSON acumulativo y resultado terminal decodificado. |
| Herramientas | Registro tipado, validación/resolución y límites de llamadas; la app sigue siendo dueña de autorización y efectos. |
| Ciclo de vida | Single-flight por sesión, cancelación/disposal esperados, terminación tipada y plazos de primera respuesta, inactividad y total. |
| Tokens y diagnóstico | Presupuesto por componentes y precisión explícita; conteo local desde OS 26.4 con SDK compatible; contadores ausentes desconocidos. |
| Variantes | Modelo general y content tagging al crear sesión; prewarm y sampling ya expuestos. |
| Privacidad | Local por defecto; PCC explícito con requisitos propios. No hay routing externo automático. |
| Documentos y voz | Extracción de texto/PDF, Vision para imágenes, Speech de archivo y micrófono. Vision no equivale a comprensión visual nativa del LLM. |

La API pública de `StructuredSchema` solo permite una raíz objeto. `SchemaProperty.object` no permite configurar campos requeridos en cada objeto anidado. El mapper admite tipos básicos, pero rechaza constraints fuera de su subconjunto; no expone rangos, patrones, límites de arrays, uniones, `null` ni referencias. Ordena las propiedades alfabéticamente. La sesión conserva historial nativo, pero la API pública no permite exportarlo/restaurarlo.

En plataformas sin plugin, el transporte ya convierte `MissingPluginException` en `FoundationModelsException.unsupportedPlatform`; no es correcto decir que falta todo manejo de plataforma no compatible. Sí puede resultar más cómodo devolver un estado consultable desde disponibilidad.

## Catálogo y cobertura de plataformas

En esta tabla **sí** significa soporte declarado/registrado, sujeto a hardware, SDK, motor y modelo; **cond.** o **exp.** señalan restricciones importantes. Web no implica Safari ni todos los navegadores. iOS incluye iPadOS cuando se usa ese target. No se ejecutó ninguno de estos backends.

| Paquete / versión consultada | iOS | Android | macOS | Windows | Linux | Web | Tipo y límite principal |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Nuestro `cupertino_fundations_models` 0.5.0 | Sí | — | Sí | — | — | — | Foundation Models/Speech; elegibilidad Apple. |
| [apple_foundation_models](https://pub.dev/packages/apple_foundation_models) 0.5.0 | Sí | — | Sí | — | — | — | Puente Apple, esquemas manuales y decoder. |
| [foundation_models](https://pub.dev/packages/foundation_models) 0.1.0 | Sí | — | Sí | — | — | — | Port amplio de contratos Apple, sin codegen obligatorio. |
| [flutter_foundation_models](https://pub.dev/packages/flutter_foundation_models) 0.3.0 | Sí | — | No registrado | — | — | — | README menciona Mac; el manifiesto publicado solo registra iOS. |
| [native_ai_bridge](https://pub.dev/packages/native_ai_bridge) 0.2.0 | Sí | — | — | — | — | — | Puente Apple; generador de tools opcional. |
| [foundation_models_framework](https://pub.dev/packages/foundation_models_framework) 0.2.1 | Sí | — | Sí | — | — | — | Sesiones y transcript; esquema/tools pendientes según su documentación. |
| [flutter_local_ai](https://pub.dev/packages/flutter_local_ai) 0.2.1 | Sí | Cond. | Sí | Cond. | — | Cond. | APIs del OS/navegador; funciones diferentes por backend. |
| [genkit_foundation_models](https://pub.dev/packages/genkit_foundation_models) 0.0.5 | Sí | — | Sí | — | — | — | Proveedor Apple para Genkit, no motor universal por sí solo. |
| [seisei_apple](https://pub.dev/packages/seisei_apple) 0.1.0-dev.10 | Sí | — | Sí | — | — | — | Backend Apple y contrato de proveedor Seisei; prerelease. |
| [flutter_edge_ai](https://pub.dev/packages/flutter_edge_ai) 2.1.1 | Sí | Sí | Sí | Sí | Sí | Cond. | Motores separados LiteRT-LM, MediaPipe, ONNX o built-in. |
| [llamadart](https://pub.dev/packages/llamadart) 0.11.1 | Sí | Sí | Sí | Sí | Sí | Exp. | GGUF/llama.cpp y LiteRT-LM; consultar capabilities del backend. |
| [flutter_local_llm](https://pub.dev/packages/flutter_local_llm) 1.0.0 | Sí | Sí | Sí | Sí | Sí | — | llama.cpp/FFI, modelos GGUF y gramáticas. |
| [llama_cpp_dart](https://pub.dev/packages/llama_cpp_dart) 0.2.2 | Sí | Sí | Sí | Sí | Sí | — | Bindings de menor nivel; integración de librería nativa y pesos. |
| [fllama](https://pub.dev/packages/fllama) 0.0.1 / [fcllama](https://pub.dev/packages/fcllama) 0.0.3 | Sí | Sí | — | — | — | — | Releases publicados del proyecto xuegao-tzx; no confundir con Telosnex. |
| [firebase_ai](https://pub.dev/packages/firebase_ai) 4.0.0 | Sí | Sí | Sí | — | — | Sí | Gemini mediante Firebase AI Logic; inferencia cloud. |
| [langchain](https://pub.dev/packages/langchain) 0.9.0 | Sí | Sí | Sí | Sí | Sí | Sí | Orquestación Dart; el proveedor determina inferencia y privacidad. |

El [proyecto Telosnex/fllama](https://github.com/Telosnex/fllama) declara seis plataformas en su README y es distinto de los paquetes homónimos publicados. No se localizó una opción pública Dart concreta para su claim de JSON Schema. Su [LICENSE](https://github.com/Telosnex/fllama/blob/main/LICENSE) ofrece GPL v2 o licencia comercial mediante acuerdo; el costo comercial no está publicado en las fuentes consultadas. No se recomienda tomarlo como sustituto principal sin aclarar entrega, API y licencia.

### Otros paquetes revisados y por qué no son sustitutos equivalentes

| Paquete | Qué aporta | Cómo usarlo en esta decisión |
| --- | --- | --- |
| [flutter_gemma](https://pub.dev/packages/flutter_gemma) 1.11.4 | Línea anterior de la familia de runtimes Gemma. | La familia actual se publica como `flutter_edge_ai`; no contar ambos nombres como dos motores Apple diferentes. |
| [flutter_edge_ai_builtin_ai](https://pub.dev/packages/flutter_edge_ai_builtin_ai) 0.3.2 | Adapta IA del OS al ecosistema Edge AI. | Su manifiesto depende de `flutter_local_ai` 0.2.1; no es evidencia de una implementación Apple independiente. |
| [flutter_ai_toolkit](https://pub.dev/packages/flutter_ai_toolkit) 1.0.0 | UI de chat, adjuntos y abstracción `LlmProvider`. | Su proveedor Firebase ofrece Android/iOS/macOS/web; una UI no agrega un motor a Windows/Linux por sí sola. |
| [on_device_ai](https://pub.dev/packages/on_device_ai) 0.2.1 | Sentimiento/clasificación mediante APIs Apple y TFLite; targets Android/iOS/macOS. | El archive sitúa streaming LLM en su roadmap. No tratar su ejemplo de streaming como prueba de un chat LLM implementado. |
| [tflite_flutter](https://pub.dev/packages/tflite_flutter) 0.12.1 | Inferencia tensorial y modelos propios en móvil/desktop. | Útil para ML específico; no suministra los contratos de sesión/esquema/tools de Foundation Models. |
| [onnxruntime](https://pub.dev/packages/onnxruntime) 1.4.1 | Runtime ONNX nativo para Android/iOS/macOS/Windows/Linux. | Requiere modelo y pipeline; no equivale a una API conversacional guiada lista para usar. |
| [apple_intelligence](https://pub.dev/packages/apple_intelligence) 0.3.3 | Image Playground y campos nativos con Writing Tools/Genmoji. | Es funcionalidad Apple adyacente. No se propone agregar generación de imágenes o platform views al núcleo de este paquete. |
| [apple_foundation_flutter](https://pub.dev/packages/apple_foundation_flutter) | Nombre anterior de Native AI Bridge. | Su documentación remite al sucesor; no es otra alternativa activa independiente. |
| [core_ai](https://pub.dev/packages/core_ai) 0.1.0 | Proyecto hermano de `foundation_models`. | Se revisó la identidad/manifiesto; no se atribuyen sus capacidades al wrapper `foundation_models` sin un contrato correspondiente. |

### Fechas de los releases que sustentan la comparación

Fechas UTC obtenidas de la API del registro, no del texto relativo del buscador. La fecha indica publicación; no mide estabilidad ni calidad.

| Paquete | Versión | Publicación UTC |
| --- | --- | --- |
| apple_foundation_models | 0.5.0 | 2026-10-08 |
| foundation_models | 0.1.0 | 2026-09-23 |
| flutter_foundation_models | 0.3.0 | 2026-02-06 |
| native_ai_bridge | 0.2.0 | 2026-10-08 |
| foundation_models_framework | 0.2.1 | 2025-11-24 |
| flutter_local_ai | 0.2.1 | 2026-09-27 |
| genkit_foundation_models | 0.0.5 | 2026-07-01 |
| seisei_apple | 0.1.0-dev.10 | 2026-06-11 |
| flutter_edge_ai | 2.1.1 | 2026-10-08 |
| flutter_edge_ai_builtin_ai | 0.3.2 | 2026-10-06 |
| flutter_gemma | 1.11.4 | 2026-10-05 |
| llamadart | 0.11.1 | 2026-10-08 |
| flutter_local_llm | 1.0.0 | 2026-08-19 |
| llama_cpp_dart | 0.2.2 | 2026-01-02 |
| fllama / fcllama | 0.0.1 / 0.0.3 | 2024-11-12 / 2024-11-23 |
| firebase_ai | 4.0.0 | 2026-08-24 |
| flutter_ai_toolkit | 1.0.0 | 2025-12-15 |
| langchain | 0.9.0 | 2026-08-27 |
| on_device_ai | 0.2.1 | 2026-04-30 |
| tflite_flutter | 0.12.1 | 2025-10-28 |
| onnxruntime | 1.4.1 | 2024-03-27 |
| apple_intelligence | 0.3.3 | 2026-09-12 |
| core_ai | 0.1.0 | 2026-09-23 |

## Por qué alguien elegiría otro paquete para iOS

Son escenarios de elección técnica razonada, no resultados de una encuesta de adopción.

| Situación concreta | Alternativa atractiva | Diferencia frente a nosotros | Peso de la diferencia |
| --- | --- | --- | --- |
| Quiero una puntuación 1–5, un identificador con patrón y exactamente tres resultados. | `apple_foundation_models`, `foundation_models`, `flutter_foundation_models`. | Rangos, regex y longitudes mapeados a constraints nativos; los nuestros solo describen tipos y enums. **C** en los archives inspeccionados. | Muy alto para extracción/clasificación. |
| Ya tengo JSON Schema y quiero reutilizarlo sin reconstruir toda la definición. | `foundation_models`, `flutter_local_ai`; `llamadart` con motor propio. | Importación de esquema como datos. Debe precisarse el dialecto y constraints soportados. **C**. | Muy alto para integrar productos existentes. |
| Quiero recibir una clase Dart y no castear mapas en cada pantalla. | `apple_foundation_models`; `flutter_foundation_models` con generador. | Decoder genérico o generación de modelos/conversores. **C**. | Alto; baja fricción y duplicación. |
| Quiero formularios que se llenen progresivamente con objetos parciales. | `flutter_foundation_models`; `seisei_apple`. | Parciales tipados o valores/parches estructurados declarados. Nosotros entregamos JSON parcial como texto y valor decodificado al completar. **C/D** según paquete. | Alto en UI de extracción; menor en procesos sin UI. |
| Quiero cerrar la app y continuar una conversación. | `foundation_models`, `flutter_foundation_models`. | Exportación/restauración de transcript en contrato público. **C**. | Alto para chat; bajo para tareas independientes. |
| Quiero actualizar el botón cuando Apple termine de preparar el modelo. | `apple_foundation_models`. | Stream público de cambios de disponibilidad. **C**. | Alto para primera experiencia y recuperación. |
| Quiero una API cercana al ejemplo Swift, con selección de guardrails o más controles nativos. | `foundation_models`, `flutter_foundation_models`. | Mayor exposición del framework. Algunas opciones son especializadas y no necesarias para una extracción pequeña. **C/D**. | Medio, condicionado al producto. |
| Necesito entender imágenes, no solo leer texto o reconocer etiquetas. | Wrappers con entrada visual nativa OS 27; `llamadart`/Edge AI con modelo compatible. | Nuestra ruta usa Vision y mantiene deshabilitado el adjunto nativo previamente inseguro. | Alto si la imagen es el producto; requiere evidencia runtime nueva. |
| Necesito funcionar sin Apple Intelligence o en un iPhone con OS anterior. | `llamadart`, `flutter_edge_ai`, `flutter_local_llm`, o cloud. | Usan un modelo propio/remoto; no comparten la elegibilidad del modelo del sistema. No garantizan buen rendimiento en todo iPhone. | Determinante; no lo arregla un wrapper Apple más amplio. |
| Necesito la misma integración en Android, Windows, Linux y web. | `flutter_edge_ai` o `llamadart`; `flutter_local_ai` para ciertos backends del OS. | Cobertura y selección de motor. La igualdad de API no significa igualdad de capacidades. | Determinante para una app multiplataforma. |
| Mi app ya usa Genkit/Seisei/LangChain y no quiero otro contrato aislado. | Sus proveedores/adapters. | Integración con mensajes, tools y flujos existentes. | Alto para esos usuarios; no obliga a depender de ellos en el núcleo. |
| Necesito búsqueda semántica sobre documentos y modelos especializados. | Edge AI / `llamadart`, u otro motor de embeddings. | Embeddings, índices/RAG y selección de pesos. | Alto para RAG; costo y superficie distintos. |

### Qué limita realmente a cada alternativa

**Puentes Apple.** Comparten la disponibilidad del modelo Apple para la inferencia local básica. Cambiar de wrapper no hace que el modelo se vuelva más inteligente ni elimina sus límites. `foundation_models_framework` documenta structured output/tools pendientes y requisitos de Mac/Xcode inconsistentes con las APIs oficiales; esas afirmaciones no deben convertirse en ventajas. `flutter_foundation_models` expone una vía manual a nivel de esquema, pero promociona anotaciones/codegen; su Mac anunciado no está registrado en el manifiesto publicado. Fuentes: [framework/changelog](https://pub.dev/packages/foundation_models_framework/changelog), [Flutter Foundation Models](https://pub.dev/packages/flutter_foundation_models), y los manifests del registro.

**flutter_local_ai.** Su atractivo es una fachada sobre backends nativos. En el release inspeccionado, iOS/macOS usan generación guiada y tools, pero Android no ofrece la misma ruta de schema dinámico/tools; Windows declara integración nativa sin validación en hardware elegible y Chrome tiene restricciones de navegador/equipo. Su generative UI es otra superficie, no una razón para ampliar nuestro núcleo. Fuente: [README publicado](https://pub.dev/packages/flutter_local_ai/versions/0.2.1).

**Edge AI.** Permite elegir motores y módulos, gestionar modelos y añadir embeddings/RAG/voz. En el archive 2.1.1 se encontraron schemas para tools, pero no una API pública general de response JSON Schema: no se le atribuye esa ventaja por extrapolación. Los motores y formatos tienen cobertura distinta; LiteRT web es preview y MediaPipe no cubre desktop. Fuente: [release](https://pub.dev/packages/flutter_edge_ai/versions/2.1.1), [documentación de instalación](https://flutteredge.ai/docs/installation) y [repo](https://github.com/DenisovAV/flutter_edge_ai). La ruta de instalación debe comprobarse nuevamente antes de una integración.

**llamadart.** La versión 0.11.1 expone `LlamaStructuredOutput` y conversión de un subconjunto JSON Schema a GBNF, con rechazo de keywords no soportados. Las capabilities del runtime gobiernan structured output/tools; web es experimental y ciertos loops no están disponibles en LiteRT/web cuando no hay terminación fiable. iOS necesita artefactos nativos y pesos; la ruta LiteRT iOS documenta mínimo 16.4. Fuente: [release](https://pub.dev/packages/llamadart/versions/0.11.1), [repo](https://github.com/leehack/llamadart), archive y archivos listados al final.

**flutter_local_llm.** Documenta gramáticas, descargas y control del contexto. El `GrammarHelper` publicado tiene una conversión mucho más limitada que JSON Schema completo: las ramas de arrays/objetos usan reglas genéricas y no convierten recursivamente todas sus restricciones. Tener un helper con ese nombre no demuestra enforcement completo ni calidad de producción. Fuente: [release](https://pub.dev/packages/flutter_local_llm/versions/1.0.0) y su archive, `lib/src/utils/grammar_helper.dart`.

**Genkit/Seisei.** Genkit integra el modelo Apple en su ecosistema, pero su wrapper declara structured output y embeddings no soportados. Seisei declara schemas/parciales más ricos y es prerelease; su puente nativo no implementa PCC según el README. Son referencias de interoperabilidad/ergonomía, no mejoras universales del motor. Fuentes: [Genkit](https://pub.dev/packages/genkit_foundation_models), [Seisei](https://pub.dev/packages/seisei_apple).

**Cloud.** Firebase ofrece schema de respuesta, tools y multimodalidad mediante Gemini; el prompt sale del dispositivo, necesita configuración de servicio y tiene cuotas/costos según proveedor/modelo. Sus schemas también son un subconjunto. LangChain suministra composición y parsers, no una garantía de generación guiada por tener `JsonOutputParser`. Fuentes: [schema Firebase](https://firebase.google.com/docs/ai-logic/generate-structured-output), [tools Firebase](https://firebase.google.com/docs/ai-logic/function-calling), [parsers LangChain](https://pub.dev/documentation/langchain_core/latest/output_parsers/).

## Mejoras seleccionadas para incorporar

Prioridad **P0**: primer incremento recomendado. **P1**: siguiente incremento. **P2**: opcional/especializado. **Condicionada**: propuesta que requiere decidir alcance o obtener evidencia antes de habilitarse. El esfuerzo es una estimación de complejidad por lectura de fuente, no un presupuesto de horas ni una promesa de calendario.

| ID | Mejora | Prioridad | Valor en iOS | Esfuerzo | Decisión |
| --- | --- | --- | --- | --- | --- |
| F01 | Rangos, patrones y longitudes de arrays | P0 | Muy alto | Medio | Incorporar a esquemas guiados. |
| F02 | Raíces adicionales y requeridos anidados | P0 | Alto | Medio | Extender el contrato manteniendo compatibilidad. |
| F03 | Entrada de JSON Schema con subconjunto explícito | P0 | Muy alto | Medio | Ofrecer junto a constructores tipados. |
| F04 | Decoder genérico del resultado final | P0 | Alto | Bajo/medio | Añadir como comodidad opcional. |
| F05 | Parciales estructurados y orden explícito | P1 | Alto en UI | Medio | Extender eventos sin reemplazar el stream actual. |
| F06 | Uniones, null y referencias locales | P1 | Alto en dominios ricos | Medio/alto | Incremental; null necesita OS 26.4. |
| F07 | Exportar/restaurar transcript | P1 | Alto en chat | Alto | Persistencia y selección de historial a cargo de la app. |
| F08 | Disponibilidad observable e idiomas de texto | P1 | Alto | Medio | Complementar los checks actuales. |
| F09 | Generador Dart separado y opcional | P1, tras estabilizar schemas | Alto con muchos modelos | Alto | Ofrecer elección manual/generada; no dependencia obligatoria. |
| F10 | Adapters de ecosistema, recetas y comodidad de streams | P2 | Medio/alto según app | Medio | Integración opcional fuera del núcleo. |
| F11 | Guardrails y selección contextual de tools/modelo | P2 | Medio, especializado | Medio/alto | Solo opciones nativas con selección explícita. |
| F12 | Entrada visual nativa | Condicionada | Muy alto en apps visuales | Alto | No habilitar rutas inseguras por similitud con un competidor. |
| F13 | Embeddings Apple y TTS | P2, condicionada al uso | Medio/alto para búsqueda/voz | Medio/alto | Evaluar API opcional; no simular embeddings del LLM. |
| F14 | Android/Windows/Linux/web y pesos propios | Línea separada | Determinante por cobertura | Muy alto | Facilitar interoperabilidad; no añadir motores por defecto. |

### F01–F03: esquemas más expresivos y dos maneras de definirlos

**Estado local posterior:** F01–F03 están implementados desde la versión local 1.2.0.
El [perfil de importación](usage.md#import-json-schema-definitions) concreta cierre
de objetos, requeridos, precisión, patrones y errores. El diseño siguiente conserva
la justificación de la investigación; no anuncia publicación ni soporte completo
de JSON Schema.

**Caso que justificaría cambiar de paquete:** el cliente ya tiene un schema de catálogo, necesita un rating 1–5 o tres sugerencias exactas y debe reescribirlo o implementar comprobaciones adicionales en nuestra integración.

**Diseño recomendado:** ampliar `SchemaProperty`/`StructuredSchema` existentes; ambos caminos, constructores Dart y JSON Schema como datos, deben converger en el mismo contrato normalizado y mapper. Evitar dos motores de schema con semánticas distintas. Añadir mínimo/máximo numérico, patrón, mínimo/máximo/exacto de elementos, raíces array/primitiva y requeridos configurables por objeto.

Apple ya documenta [GenerationGuide](https://developer.apple.com/documentation/foundationmodels/generationguide) y [arrays dinámicos](https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema/init(arrayof:minimumelements:maximumelements:)) desde OS 26. Los archives de los puentes comparados contienen usos de esas APIs. No se necesita `@Generable` ni compilar una clase Swift para construir un esquema en runtime.

**Compatibilidad necesaria:** preservar el constructor objeto actual y sus defaults. Hoy `requiredProperties: []` en la raíz marca todos los campos opcionales; en los objetos anidados, la ausencia de una lista hace que el mapper marque todos como requeridos. Una ampliación no debe cambiar esos defaults silenciosamente. El adapter JSON deberá respetar la semántica de `required` del dialecto elegido, sin heredar accidentalmente el default interno.

**Subconjunto:** declarar qué se acepta y rechazar con `schemaPath` lo no representable. Comenzar por `type`, `properties`, `required`, `items`, enums de strings, rangos, patrones y límites de arrays; definir el tratamiento de `additionalProperties`. No ignorar `format`, `multipleOf`, `allOf`, condiciones, referencias externas u otros keywords. Un patrón compatible con Dart/ECMAScript no necesariamente es un patrón Swift válido.

**Condición de entrega futura:** un constraint soportado se aplica durante la generación; si SDK/modelo no lo soporta, la solicitud falla explícitamente. Obtener JSON válido no prueba que el importe, la fecha o el dato extraído sean verdaderos. No se sustituye una restricción rechazada por un prompt parecido.

### F04: resultado a un tipo Dart sin perder metadatos

**Estado local posterior:** implementado en 1.3.0 mediante
`generateStructuredDecoded<T>`, `ModelResponse.decodeStructured<T>`,
`DecodedModelResponse<T>` y `StructuredDecodingException`. El
[contrato final](usage.md#decode-final-values-to-dart-types) documenta conversión
síncrona, errores, metadatos y lifecycle. La publicación base sigue en 0.5.0.

**Referencia concreta:** `respondInto<T>` de `apple_foundation_models` recibe un decoder de la app; su código publicado lo invoca sobre la salida estructurada. La idea aporta valor aun sin generar código. Fuente: [archive 0.5.0](https://pub.dev/api/archives/apple_foundation_models-0.5.0.tar.gz), `lib/src/session.dart`.

**Decisión:** proponer un helper genérico sobre `generateStructured()` que reciba un decoder explícito y retenga respuesta, uso, terminación y diagnóstico. El retorno no debería obligar a perder `ModelResponse` para obtener `T`. El decoder puede ser escrito a mano o generado por una herramienta del consumidor.

**Condición de entrega futura:** distinguir fallo de schema, JSON y decoder; aceptar raíces `Object?` compatibles, no solamente mapas. La conversión no autoriza herramientas, escrituras ni reglas de negocio. Los nombres públicos del helper y del resultado están pendientes de implementación; no son APIs disponibles en 0.5.0.

### F05: parciales útiles, final estricto y orden controlado

**Estado local posterior:** implementado en 1.4.0 con snapshots nativos optativos
dentro de TextSnapshotEvent, hojas incompletas retenidas y orden explícito por
objeto. Se conservaron los tipos sellados y defaults para mantener compatibilidad.
El [contrato vigente](usage.md#structured-snapshots-and-property-order) explica
rutas, reemplazo de estado, importación y cancelación; la condición siguiente
conserva la justificación de la investigación, sin anunciar publicación.

**Caso:** un formulario muestra primero nombre, después fecha y luego importe; la app quiere pintar campos confirmados mientras sigue llegando contenido. No debería implementar un parser tolerante distinto en cada pantalla.

**Decisión:** conservar `TextSnapshotEvent` y sumar un evento opcional con estructura parcial segura, campos presentes y estado de completitud. Un decoder parcial debe ser diferente del final. El resultado final sigue usando decodificación estricta y un único terminal. `streamInto` del competidor omite snapshots cuando su decoder lanza una excepción; no conviene copiar ese catch genérico sin distinguir incompletitud de un defecto del decoder.

Agregar una opción explícita de orden de propiedades. Nuestro mapper ordena alfabéticamente; una lista de orden validada permitiría que la app decida qué campos llegan primero, manteniendo el comportamiento anterior cuando no se usa. Apple explica que [las propiedades guiadas se generan en orden](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation). No se deduce una mejora cuantitativa de precisión o latencia.

**Condición de entrega futura:** no ejecutar negocio sobre parciales ni completar artificialmente strings/números. La cancelación de wrappers debe cancelar el stream original. Si se añaden patches, describir rutas reemplazadas/eliminadas; no asumir que toda revisión estructurada es append-only. Parcheo fino es posterior al evento parcial básico.

### F06: alternativas, ausencia y reutilización de tipos

**Estado local posterior:** F06 está implementado en 1.5.0 con nullValue,
anyOf, referencias locales acíclicas y presencia final separada. El
[contrato vigente](usage.md#null-anyof-and-local-references) define guards de
SDK/OS26.4 para null, límites y formatos rechazados, sin anunciar publicación.

**Caso:** una extracción devuelve uno de varios tipos de documento; un dato puede estar ausente o ser explícitamente nulo; varios campos reutilizan una definición.

**Decisión:** ofrecer `anyOf` de schemas, null explícito y referencias locales/dependencias tras el subconjunto básico. No llamar `oneOf` a una unión que solo implementa semántica `anyOf`. Un enum de strings ya existe y no debe contarse como una nueva capacidad.

La documentación Apple sitúa [null explícito](https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema/null) y [representación de nil](https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema/init(name:description:representnilexplicitlyingeneratedcontent:properties:)) en OS **26.4**, mientras [referencias](https://developer.apple.com/documentation/foundationmodels/dynamicgenerationschema/init(referenceto:)) existen desde 26.0. Hace falta proteger cada miembro según SDK y runtime; la disponibilidad del tipo contenedor no basta.

**Condición de entrega futura:** distinguir propiedad omitida, null y valor. Mantener nombres únicos, límites de tamaño/profundidad y errores por ruta. Empezar con referencias locales acotadas; recursión arbitraria y `$ref` remoto no entran en la primera entrega.

### F07: historial exportable y restauración explícita

**Estado local posterior:** F07 está implementado en 1.6.0 con snapshot inmutable,
archivo Codable nativo, exportHistory y restoreSession/SessionOptions.history.
Conserva contexto admitido, opciones/formats, tools y metadatos/reasoning; crea una
sesión nueva sin replay. El perfil inicial exige plataforma/OS/SDK exactos y
contexto/definiciones coincidentes, admite texto/estructura completa y tools
terminadas, rechaza adjuntos/data/parciales/pendientes, y limita 1 MiB/256 entries.
No incluye selección/truncado de entries ni garantiza assets de modelo idénticos.
Almacenamiento, usuario/hilo, cifrado y retención siguen a cargo de la app. Consulta
[contrato actual](usage.md#export-and-restore-session-history). El caso y decisión
originales siguientes documentan la motivación, no un permiso de intercambio general.

**Caso:** continuar un chat tras cerrar la app o crear otra sesión con un subconjunto revisado del historial. Las sesiones de la base 0.5.0 no lo permiten desde Dart aunque nativamente tengan transcript.

**Decisión:** exponer entries tipadas, snapshot serializable con versión y creación de sesión desde historial compatible. Reutilizar `SessionRegistry`, ownership y lifecycle actuales. Apple ofrece [rehidratación desde transcript](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/init(model:tools:transcript:)) desde OS 26; los contratos publicados de `foundation_models` y `flutter_foundation_models` muestran este uso.

**Condición original de entrega:** restaurar historial no ejecuta otra vez las herramientas registradas. No persistir automáticamente ni mezclar sesiones/usuarios. La app decide almacenamiento, cifrado, retención, truncado y resumen. La exportación debe aclarar qué conserva realmente: texto, tools, adjuntos y entries nuevas de OS 27; una versión textual incompleta no se presenta como copia exacta.

La selección de content tagging con historial compartido puede agregarse después. `apple_foundation_models` reconstruye una sesión con el transcript al cambiar variante: es una técnica implementada por ese wrapper, no prueba de mutación en sitio del modelo de Apple ni de costo cero.

### F08: disponibilidad que acompañe al usuario

**Estado local posterior:** F08 está implementado en 1.7.0. watchAvailability
observa la variante local con Observation por defecto o polling explícito de un segundo a cinco minutos;
se pausa fuera de resumed/al pausar y consulta de nuevo al volver. Estado inicial
activo, cambios estructurales sin duplicados y cleanup aislado por watchId. SDK/OS
sin backend o plugin ausente terminan con disponibilidad no disponible; errores
reales permanecen tipados. getTextModelLanguages usa lenguas/etiquetas de la variante
local sin Speech; la intersección previa permanece. No inferencia, descargas, PCC,
progreso ni cadencia garantizada. Consulta [contrato actual](usage.md#observable-local-availability-and-text-languages).

**Caso:** el modelo está descargándose y la interfaz debería habilitar la función al terminar; otra app solo necesita idiomas de texto, sin depender de los idiomas de Speech.

**Decisión:** añadir suscripción opcional a disponibilidad con estado inicial, cambios sin duplicación, cleanup y pausa en background. Si el SDK no tiene observación apropiada, el polling debe ser explícito, con frecuencia acotada y sin prometer un porcentaje de descarga inexistente. `apple_foundation_models` tiene un stream público de estos cambios.

Separar una consulta de idiomas del modelo de `getSupportedLanguages()`, que hoy es la intersección con Speech. Preservar ese contrato para los consumidores existentes. Convertir motivos no compatibles/transitorios en información útil sin afirmar que cada usuario puede reparar el estado. Los diagnósticos actuales ya resuelven parte de esto; se deben reutilizar.

**Condición original de entrega:** no iniciar descargas, PCC, permisos de voz ni solicitudes de generación al suscribirse. Decidir si el estado `unsupportedPlatform` se devuelve como disponibilidad; los errores de uso seguirán siendo tipados.

### F09: codegen opcional, después del contrato manual

**Estado local posterior:** F09 está implementado en 1.8.0 con paquete compañero
optativo, anotaciones propias y archivos *.structured.dart. Produce schemas sobre
constructores existentes, decoder estructural final y vistas parciales tipadas con
flags de presencia/completitud/valor. No tooling runtime en núcleo ni Swift,
inferencia o routing generado. Perfil concreto acíclico y acotado; vías manual e
importada se conservan. Setup y restricciones en [contrato actual](usage.md#optional-dart-generation).

**Qué aporta:** una sola clase puede producir schema, decoder final y representación parcial; evita mantener a mano varios contratos parecidos. Vale más cuando hay numerosos modelos, muchos campos o cambios frecuentes. Para uno o dos schemas pequeños, añade tooling y pasos que pueden no compensar.

**Decisión:** preparar en otra entrega un paquete generador separado, usado como `dev_dependency`. El núcleo conserva las vías manuales y cero dependencias runtime de terceros. El código generado debe consumir exactamente las mismas APIs de schema/decoder; no debe requerir un bridge Swift generado por modelo. La elección no cambia el modo local/PCC.

La referencia son [las anotaciones y guides del competidor](https://pub.dev/packages/flutter_foundation_models) y el [generador opcional de Native AI Bridge](https://pub.dev/packages/native_ai_bridge). No hace falta copiar sus anotaciones o arquitectura: debe elegirse un contrato propio compatible con F01–F08.

**Condición original de entrega:** el generador no ejecuta inferencia, red ni herramientas; errores de anotaciones claros, salida reproducible y rutas manual/generada equivalentes. Deben definirse su SDK, versionado y dependencies de desarrollo antes de autorizar implementación. La implementación F09 autorizada usa tooling de desarrollo en el compañero/ejemplo; no lo instala automáticamente en aplicaciones consumidoras.

## Flujo de integración para una IA que implemente una app consumidora

Regla acordada con Sebastián: preguntar una vez por proyecto/funcionalidad cuando ambas rutas estén disponibles y no exista una preferencia previa. La pregunta sugerida es:

> ¿Prefieres definir los esquemas manualmente en Dart o generar esquemas y decodificadores desde tus clases? La vía manual evita pasos de build; el generador reduce repetición cuando hay muchos modelos. Te recomiendo la vía manual para pocos esquemas y el generador para un dominio grande.

Después de la elección, la IA debe explicar el impacto y continuar por esa vía. No instalar el generador por iniciativa propia ni obligar a migrar schemas existentes. Si el usuario ya pidió una opción, respetarla sin volver a preguntarla. No confundir generar código Dart con la generación guiada de datos por el modelo.

**Aplicación en la base investigada:** en 0.5.0 solo está implementada la vía manual.
Desde la versión local 1.2.0 también existe la importación F03; ambas
rutas evitan generación Dart. Desde 1.8.0 local también existe el generador F09; una IA resuelve ahora la elección
manual/importada/generada si falta esa preferencia. No ofrece estas APIs como
publicadas en 0.5.0 ni instala tooling sin esa selección.

## Mejoras especializadas y límites del núcleo

### F10–F11: interoperabilidad y controles nativos

**Estado local posterior F10:** implementado en core1.9.0 mediante import optativo,
adapter de interfaz app con sesiones propias/prestadas y eventos originales,
TextUpdate append/replace y reconciliación final, con cleanup/cancelación esperados.
Se incluyen ejemplo app probado y recetas actuales Genkit/LangChain sin dependencias
runtime ni providers registrados. Genkit1.0 exige Dart3.12, por encima del mínimo
del núcleo; sus contratos/chunks difieren de LangChain0.9 y de snapshots Apple.
La app negocia esquema/tools, metadatos, historial, consentimiento y cancelación.
F11/guardrails/perfiles nativos permanece fuera de F10. Consulta
[contrato actual](usage.md#optional-adapters-and-stream-updates).

Ofrecer primero recetas/adapters de integración con Genkit, LangChain o una interfaz de la app. Si hay demanda, publicar paquetes compañeros que dependan del núcleo, nunca al revés. Una app elige proveedor, consentimiento y fallback; no se reintroduce routing híbrido automático. Los adapters deben conservar terminales, cancelación, snapshots y contadores desconocidos.

Para consumidores que esperan deltas, un helper puede derivarlos cuando el siguiente texto conserva el prefijo anterior. Si hay una revisión debe devolver reemplazo o un evento explícito, no cortar por longitud y producir un delta incorrecto. Las recetas de resumir/clasificar/extraer tienen valor de onboarding; no necesitan multiplicar métodos nativos para cada prompt.

Exponer guardrails tendría valor para transformaciones legítimas. Ofrecer solo las opciones reales de Apple, como [permissiveContentTransformations](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations), manteniendo el default y sus límites; no adoptar niveles inventados que prometan desactivar las protecciones. La API está documentada desde OS 26.

Tools/instrucciones dinámicas o perfiles pueden reducir contexto y facilitar workflows grandes. Apple documenta [Dynamic Instructions/Profiles](https://developer.apple.com/documentation/foundationmodels/composing-dynamic-sessions-with-instructions-and-profiles); no se propone una máquina de agentes ni cambios silenciosos de local a PCC. Es una prioridad posterior a historial y schemas; se debe fijar disponibilidad por miembro antes de implementar.

### F12: comprensión de imágenes, con una barrera material

La entrada visual nativa puede justificar una migración en apps que comparan fotos, describen escenas o razonan sobre documentos visuales. Nuestro OCR/clasificación no cubre ese caso. `apple_foundation_models`, `foundation_models` y `native_ai_bridge` publican interfaces para imágenes en OS 27; sus claims no validan nuestro puente.

La decisión es diseñar una selección explícita entre extracción Vision y entrada nativa según capabilities, sin reemplazar una vía por otra silenciosamente. **No habilitar ahora** el camino que el proyecto desactivó por fallos nativos. Se necesita una tarea específica con validación solicitada sobre SDK/runtime/dispositivo/modelo, incluyendo lifecycle, orientación, tamaños y cancelación. PCC mantiene su consentimiento y entitlement separados. No se propone generación de imágenes.

### F13: búsqueda semántica y respuesta hablada

Los módulos de Edge AI y las capacidades de `llamadart` pueden atraer a productos de RAG o voz. Foundation Models no ofrece embeddings en la API pública actual de nuestro paquete; generar una lista de números con un prompt no crea un embedding fiable.

Para iOS/macOS hay una alternativa que merece evaluación acotada: [NaturalLanguage NLEmbedding](https://developer.apple.com/documentation/naturallanguage/nlembedding). La [consulta de sentence embeddings](https://developer.apple.com/documentation/naturallanguage/nlembedding/sentenceembedding(for:)) puede devolver `nil` por idioma/disponibilidad. Una futura API opcional debería identificar motor, idioma, dimensión y revisión; los vectores no son los del modelo Foundation Models. El índice y recuperación seguirían a cargo de la app. No se decide incorporarla sin un caso de uso y evaluación de calidad en el idioma objetivo.

Text-to-speech podría complementar Speech de entrada mediante [AVSpeechSynthesizer](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer), con reproducción/cancelación y selección de voces explícitas. Su valor es medio: puede integrarse también con una librería de voz aparte. No se añaden reproducción automática ni permisos de micrófono para leer una respuesta.

Los adapters entrenados del modelo Apple son otra opción especializada. [Apple explica sus requisitos de entrenamiento, distribución y actualización](https://developer.apple.com/jp/apple-intelligence/foundation-models-adapter/). No son equivalentes a importar cualquier GGUF, y su mantenimiento por versión del modelo aumenta el costo. Dejar carga de adapters para una petición con dataset, estrategia de entrega y objetivos definidos.

### F14: todas las plataformas sin falsa paridad

Para una app que necesita todas las plataformas hoy, recomendar un motor multiplataforma o composición en la aplicación es más honesto que prometer que el backend Apple cubre Android/Linux/web. Un paquete compañero podría adaptar nuestros contratos en el futuro, pero debe negociar capabilities, privacidad y terminación por backend.

En [Chrome Prompt API](https://developer.chrome.com/docs/ai/prompt-api) hay schema de respuesta y gestión de sesiones, pero su disponibilidad está limitada; la [tabla oficial de compatibilidad](https://developer.chrome.com/docs/ai/prompt-api-polyfill) no incluye iOS/Android ni Safari/Firefox como soporte equivalente. Android ML Kit tiene su propia [Prompt API](https://developers.google.com/ml-kit/genai/prompt/android), hardware/AICore y contratos distintos. Windows requiere APIs, hardware y distribución propios; [Microsoft documenta una transición de Phi Silica a Aion Instruct](https://learn.microsoft.com/en-us/windows/ai/apis/phi-silica), que no prueba que un plugin ya la implemente.

No convertir lo escrito en nuestra API en una promesa de paridad de schema/tools/streaming entre estos backends. La portabilidad de definiciones puede ser útil, pero un backend que no pueda imponer un constraint debe rechazarlo o declarar explícitamente otro modo elegido por la app.

## Orden de trabajo recomendado

1. **Contrato estructurado básico:** F01–F04. Conserva las APIs actuales y agrega alternativas de schema/decoder sin dependencia de tooling. Es la mejor relación entre utilidad iOS y esfuerzo.
2. **Estructuras avanzadas y UX:** F05–F06, con gates OS 26.4 y extensiones de eventos compatibles.
3. **Dos vías de desarrollo:** F09, después de fijar el contrato anterior. Pregunta manual/generada, paquete separado y guías para agentes alineadas con lo realmente publicado.
4. **Sesiones útiles en una app real:** F07–F08. Historial explícito, recuperación y disponibilidad, sin persistencia automática.
5. **Integraciones especializadas:** F10–F13 según demanda; F12 tiene riesgo material y evidencia pendiente. F14 se planifica aparte si se decide mantener backends no Apple.

No fijar una nueva versión en esta investigación. Antes de cada implementación, definir el contrato de esa entrega y qué comprobaciones autoriza el usuario. Las condiciones descritas aquí son criterios futuros, no pruebas creadas o ejecutadas. Cuando cambie una API, alinear README, changelog, ejemplo, guías para agentes y sitio; SwiftPM/CocoaPods y targets iOS 15/macOS 12 se conservan.

## Cuándo recomendar nuestro paquete y cuándo otro

**Recomendar el actual** para una tarea Apple local acotada, tools/Speech, sin pesos propios y con necesidad de ciclo de vida, presupuestos y frontera de privacidad explícita. El hecho de que otro wrapper use schemas no obliga a cambiar: nosotros ya tenemos generación guiada.

**Recomendar evaluar otro hoy** si la funcionalidad indispensable es un schema que no podemos expresar, transcript restaurable, un motor propio, cobertura no Apple, embeddings o entrada visual nativa. Para schemas nativos, los comparadores más útiles son `foundation_models`, `apple_foundation_models` y `flutter_foundation_models`; para portabilidad, `llamadart`, `flutter_edge_ai` y `flutter_local_ai` con sus diferencias por backend. Para cloud, evaluar proveedor y política en la app.

Tras F01–F09, las razones para cambiar de puente Apple por ergonomía de schemas y sesiones deberían reducirse; esto es una hipótesis de producto. La elección por cobertura, modelo o rendimiento necesita otra decisión/evidencia y no desaparece por ampliar el contrato.

## Fuentes de código para retomar la implementación

Los enlaces de paquete de las tablas llevan a documentación de su mantenedor. Para reproducir la lectura del release, utilizar el archive versionado; estos archivos se inspeccionaron como texto y no se ejecutaron.

| Archive / fuente | Archivos o contrato que sustentan los hallazgos |
| --- | --- |
| [apple_foundation_models 0.5.0](https://pub.dev/api/archives/apple_foundation_models-0.5.0.tar.gz) | `lib/src/schema.dart`, `lib/src/session.dart`; Swift compartido `AppleFoundationModelsPlugin.swift`: guides, arrays, decoder, observación y reconstrucción de sesión. |
| [foundation_models 0.1.0](https://pub.dev/api/archives/foundation_models-0.1.0.tar.gz) | `lib/src/schema.dart`, `lib/src/session.dart`, `lib/src/transcript.dart`, README y manifiesto: schema como datos, referencias y historial. |
| [flutter_foundation_models 0.3.0](https://pub.dev/api/archives/flutter_foundation_models-0.3.0.tar.gz) | `lib/src/generation_schema.dart`, `lib/src/language_model_session.dart`, `GenerationSchema+FromJson.swift`, README y manifiesto. |
| [flutter_local_ai 0.2.1](https://pub.dev/api/archives/flutter_local_ai-0.2.1.tar.gz) | `GenerationSchemaBuilder.swift`, modelos de config/schema y README: schema nativo y matriz desigual de backends. |
| [native_ai_bridge 0.2.0](https://pub.dev/api/archives/native_ai_bridge-0.2.0.tar.gz) | `ios/Classes/StructuredGeneration.swift`, README, manifiesto y capacidades públicas. |
| [llamadart 0.11.1](https://pub.dev/api/archives/llamadart-0.11.1.tar.gz) | `lib/src/core/models/inference/structured_output.dart`, `lib/src/core/grammar/json_schema_converter.dart`, README y companion LiteRT Flutter. |
| [flutter_edge_ai 2.1.1](https://pub.dev/api/archives/flutter_edge_ai-2.1.1.tar.gz) | README, API de tools/function calls y manifiesto; sin contrato localizado de response schema arbitrario. |
| [flutter_local_llm 1.0.0](https://pub.dev/api/archives/flutter_local_llm-1.0.0.tar.gz) | `lib/src/utils/grammar_helper.dart`, README y manifiesto; límites del conversor. |
| [on_device_ai 0.2.1](https://pub.dev/api/archives/on_device_ai-0.2.1.tar.gz) | README y plugins Apple: ML específico; generación LLM en roadmap. |
| [API del registro](https://pub.dev/api/packages/apple_foundation_models) | Mismo endpoint sustituyendo el nombre para cada fila; `latest.version`, `latest.published`, `latest.pubspec` y `archive_url`. |
| [Documentación Apple estructurada](https://developer.apple.com/tutorials/data/documentation/foundationmodels/dynamicgenerationschema.json) | JSON oficial del portal para contrastar declarations y `introducedAt`; se consultaron también GenerationGuide, session y miembros null/array/reference/guardrails. |

No se usaron likes/descargas como prueba de superioridad. No se ejecutaron tests, análisis, formatters, linters, builds, validadores, benchmarks, apps, simuladores, dispositivos ni QA visual. No se cambió código, versión, configuración, dependencias ni archivos de entorno; no se hizo commit, push ni publicación.
