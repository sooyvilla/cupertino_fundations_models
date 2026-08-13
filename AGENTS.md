# Reglas del proyecto

## Alcance y precedencia

- Raíz: `/Users/villa/Developer/proyectos/cupertino_fundations_models`.
- Estas reglas complementan las instrucciones superiores; cualquier `AGENTS.md` más cercano al archivo tiene prioridad.

## Perfil confirmado

- Proyecto existente: paquete Flutter iOS con API pública Dart y puente nativo Swift.
- La integración nativa debe conservar soporte CocoaPods y Swift Package Manager.
- El deployment target del plugin permanece en iOS 15; cada uso de Foundation Models debe protegerse por SDK y disponibilidad de iOS 26 o iOS 27.
- Mantener cero dependencias runtime de terceros salvo que el usuario autorice expresamente una nueva dependencia.

## Arquitectura y convenciones

- Dart expone contratos tipados y orquestación; Swift integra directamente `FoundationModels`, `Speech` y APIs de plataforma.
- No exponer `MethodChannel` como API pública ni asumir capacidades por modelo de dispositivo; consultar availability y capabilities nativas.
- Mantener límites de privacidad explícitos: local por defecto y PCC/proveedores externos solo según la política solicitada por la app.
- Mantener alineados `pubspec.yaml`, `README.md`, `CHANGELOG.md`, el ejemplo y los manifiestos iOS cuando cambie la API pública.

## Flujo de trabajo

- Git: no existe política de ramas o commits automáticos confirmada. No crear ramas, commits, merges, pushes ni publicaciones sin autorización explícita.
- Validaciones permitidas: `dart format`, `flutter analyze` y builds no interactivos proporcionales. Usar Xcode beta cuando se validen APIs de iOS 27.
- No crear ni ejecutar pruebas salvo petición explícita.
- No ejecutar la aplicación, simuladores o dispositivos salvo petición explícita.

## Documentación

- Mantener `context.md` al final de cada iteración con alcance, decisiones, validaciones, bloqueos y pendientes.
- Guardar investigación o documentación adicional bajo `doc/`, siguiendo la convención publicable de paquetes Dart.
- Consultar `README.md`, `CHANGELOG.md` y `context.md` antes de cambiar contratos públicos o compatibilidad de SDK.
