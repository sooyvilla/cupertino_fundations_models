# Reglas del proyecto

## Alcance y precedencia

- Raíz: `/Users/villa/Developer/proyectos/cupertino_fundations_models`.
- Estas reglas complementan las instrucciones superiores; cualquier `AGENTS.md` más cercano al archivo tiene prioridad.

## Perfil confirmado

- Proyecto existente: paquete Flutter iOS/iPadOS y macOS con API pública Dart y puente nativo Swift compartido en `darwin/`.
- La integración nativa debe conservar soporte CocoaPods y Swift Package Manager.
- Los deployment targets del plugin permanecen en iOS 15 y macOS 12; cada uso de Foundation Models debe protegerse por SDK y disponibilidad de iOS/macOS 26 o 27, incluyendo iOS/macOS 26.4 para contar tokens.
- Mantener cero dependencias runtime de terceros salvo que el usuario autorice expresamente una nueva dependencia.

## Arquitectura y convenciones

- Dart expone contratos tipados y orquestación; Swift integra directamente `FoundationModels`, `Speech` y APIs de plataforma.
- No exponer `MethodChannel` como API pública ni asumir capacidades por modelo de dispositivo; consultar availability y capabilities nativas.
- Mantener límites de privacidad explícitos: local por defecto y PCC/proveedores externos solo según la política solicitada por la app.
- El núcleo integra Apple local/PCC. La aplicación consumidora decide la orquestación con APIs externas, consentimiento, historial y reintentos; no agregar routing híbrido implícito al paquete.
- Mantener alineados `pubspec.yaml`, `README.md`, `CHANGELOG.md`, el ejemplo y los manifiestos Apple cuando cambie la API pública o compatibilidad.

## Flujo de trabajo

- Git (`team-defined`, confirmado 2026-09-19): `main` es el destino de las entregas expresamente autorizadas. Una solicitud de subir a Git permite crear el commit de esa entrega y hacer push a `origin/main`, tras revisar los cambios y verificar el remoto. No crear ramas, merges, commits automáticos, pushes ni publicaciones en tareas que no los autoricen. Trabajos paralelos o una rama distinta requieren una instrucción específica; usar `codex/` cuando se autorice una rama de tarea.
- Entregas (confirmado 2026-09-30): terminar el encargo completo y obtener el permiso final del usuario antes de hacer commit, push, despliegue o publicación. No subir avances parciales. Cuando se active el pipeline de pub.dev, un push autorizado a `main` con una versión nueva también inicia la publicación automática; conservar la versión en tareas que no sean una entrega del paquete. Configuración y recuperación en `doc/automated-publishing.md`.
- Validaciones permitidas: `dart format`, `flutter analyze` y builds no interactivos proporcionales. Usar Xcode beta cuando se validen APIs de iOS 27.
- No crear ni ejecutar pruebas salvo petición explícita.
- No ejecutar la aplicación, simuladores o dispositivos salvo petición explícita.

## Documentación

- Mantener `context.md` al final de cada iteración con alcance, decisiones, validaciones, bloqueos y pendientes.
- Guardar investigación o documentación adicional bajo `doc/`, siguiendo la convención publicable de paquetes Dart.
- Consultar `README.md`, `CHANGELOG.md` y `context.md` antes de cambiar contratos públicos o compatibilidad de SDK.

## Serie F01–F10 — acuerdo del 2026-10-09

- Implementar una funcionalidad por objetivo, siguiendo la investigación de `doc/flutter-ai-competitive-research-2026-10-09.md`. F01–F10 están preparados localmente en núcleo 1.9.0; generador compatible 1.8.0. El objetivo actual es F10 y la serie acordada está implementada.
- Preparar una versión local por funcionalidad, comenzando por 1.0.0 desde 0.5.0. Las siguientes entregas compatibles incrementan minor; los cambios incompatibles incrementan major. No commit, push, tag, despliegue ni publicación sin autorización posterior.
- El usuario solicita tests robustos para toda la librería en cada entrega y 100% de cobertura de líneas Dart ejecutables. Probar escenarios cotidianos, errores, lifecycle y la integración nativa pertinente; no excluir código ejecutable ni adaptar comportamiento de producción para maquillar cobertura.
- Distinguir cobertura Dart, cobertura Swift y calidad/runtime del modelo. Un mock de canal no prueba generación Apple. Esta autorización de tests no incluye ejecución de apps, simuladores o dispositivos.
- Mantener documentación en los documentos existentes: API, recetas, changelog, README y guía de IA. Retirar instrucciones actuales obsoletas, conservar historia de versiones y no presentar funciones futuras como implementadas.
- Documentar clases y miembros públicos Dart con Dartdoc natural, contratos, límites y ejemplos útiles. La petición explícita autoriza estos comentarios de documentación; no añadir comentarios explicativos internos por rutina.
- En la guía para IA, preguntar decisiones necesarias de integración y respetar preferencias previas. Ofrecer esquemas manuales o generación Dart solo cuando ambas rutas estén implementadas; el generador será opcional y separado del núcleo.
- Desde F03 ofrecer constructores manuales o importación del subconjunto JSON Schema según el contrato existente/preferencia. No quitar restricciones rechazadas, cerrar objetos abiertos ni asumir equivalencia de patrones ECMA-262/Swift por iniciativa propia.
- Desde F04 reutilizar decoders explícitos de la app sobre valores finales, retener el ModelResponse original y separar errores de conversión de fallos nativos. No ejecutar lógica de negocio sobre snapshots parciales ni inferir autorización o corrección de datos por convertirlos a un tipo Dart.
- Desde F05 los snapshots estructurados son opt-in dentro de TextSnapshotEvent, reemplazables y no terminales; no reparar JSON parcial ni ejecutar el decoder final sobre ellos. PropertyOrder es una permutación completa por objeto; en importación se configura separadamente por ruta de definición. Conservar el orden alfabético/defaults y no añadir variantes selladas por rutina.
- Desde F10 adapters optativos por import separado: ownership explícito, originales/meta/usage preservados, append o reemplazo y cancelación esperada. La app elige framework/proveedor/historial/consentimiento; no reejecutar tools observados, fabricar contadores/terminales ni añadir fallback. Frameworks append-only deben rechazar revisiones; recetas no prueban providers runtime.
- Desde F09 existe packages/cupertino_fundations_models_generator como dev_dependency optativa, con anotaciones propias en el núcleo y cero tooling runtime. Emitir compañeros *.structured.dart sobre APIs existentes; separar decoders finales y vistas parciales no terminales. La IA consulta manual/importado/generado sólo si falta elección; no migrar ni instalar por rutina. Pruebas/gate completos para núcleo y generador separados; publicación del compañero requiere autorización/flujo propio.
- Desde F08 watchAvailability es local por variante, frío y opcional; Observation por defecto o polling explícito acotado, pausa fuera de resumed y cleanup esperado. No iniciar PCC/Speech/inferencia/descargas, ni prometer cadencia o progreso de assets. TextModelLanguage/getTextModelLanguages se separan de la intersección existente con Speech; distinguir lenguas anunciadas, locales admitidos y readiness.
- Desde F07 el historial es optativo y sensible: archivo Codable nativo + descriptores inmutables, sin almacenamiento automático ni replay de herramientas. Restaurar sólo con entorno/ruta/variante/locale/definiciones compatibles y callbacks actuales; no editar descriptores para simular transcript. Rechazar adjuntos/data, parciales y herramientas pendientes; límites de 1 MiB/256 entries.
- Desde F06 separar ausencia, null explícito y valor; usar hasStructuredValue para presencia raíz y containsKey en objetos. AnyOf no implica oneOf. Definiciones/referencias son locales, acíclicas y acotadas; no sustituir contratos rechazados ni bajar null a omisión. La construcción nativa null se resuelve bajo guard SDK/OS26.4 antes de pasarla al mapper.
- Revisión de cierre: null usa compiler>=6.3/SDK Xcode26.4 y OS26.4; no cambiar por esto los guards de APIs OS27/conteo existentes. Por instrucción del 2026-10-10, CI Apple compila con Xcode27.2 en xcode-27/macOS27; distinguir SDK de runtime y pruebas no disponibles antes de macOS27.2. Cobertura Dart100% siempre; cobertura nativa íntegra con excepción explícita y verificada sólo del rechazo de DataEntry en hosts27.0/27.1, sin quitar fuentes del informe; host27.2 exige también esa región. Rechazar precisión perdida en límites number manuales/nativos y preservar descripciones de raíces/items/alternativas/defs sin duplicar el wrapper de propiedades nombradas.
- Registrar alcance, versión local, evidencia de pruebas, límites y próxima funcionalidad en `context.md` para continuar la serie.
