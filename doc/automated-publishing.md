# Publicación automática en pub.dev

Un cambio de código o documentación en `main` no crea una versión. La publicación se inicia cuando el push cambia el campo `version` de `pubspec.yaml` y esa versión todavía no existe en pub.dev.

El workflow `.github/workflows/publish-pub-dev.yml` compara el manifiesto anterior al push con el del commit recibido. Crea el tag `v<version>` sobre ese commit y el evento del tag publica el paquete. Antes de crear el tag o publicar, exige análisis, tests, cobertura Dart completa y compilación de los ejemplos Apple. Después comprueba que el tag coincide con el manifiesto, que el commit pertenece a `main` y que la versión sigue sin publicarse. Si pub.dev falla o responde de forma inesperada, se detiene.

Pub.dev autentica la publicación con OIDC de GitHub; no se guarda una credencial personal de pub.dev. La creación del tag usa un token temporal de una GitHub App limitada a este repositorio. Su clave privada sí se conserva como un secreto de Actions.

## Activación inicial

La configuración externa está guardada y confirmada. La instalación inicial conservó `0.4.4`. El 2 de octubre de 2026 el dueño autorizó ampliar pruebas y cobertura, exigirlas en el pipeline y después entregar `0.5.0`. La primera publicación OIDC quedó confirmada el 2 de octubre de 2026: el [run de v0.5.0](https://github.com/sooyvilla/cupertino_fundations_models/actions/runs/37079180625) terminó en verde y la API de pub.dev registra `0.5.0` publicada a las `23:53:23 UTC`, con targets iOS y macOS. El tag apunta al commit `4c3f074a55e058aa41997772a851962ab6013973`. Tanto el run de main como el del tag pasaron 67 tests Flutter, 29 tests Python, cobertura Dart 1007/1007 y ambos builds Apple; el dry-run de publicación tuvo cero advertencias.

La revisión de fuente del 1 de octubre de 2026 no encontró un fallo concreto en el flujo de publicación ni en su recuperación. No se ejecutaron el script, el workflow ni las comprobaciones de publicación. La configuración de las cuentas se confirmó posteriormente mediante sus pantallas de administración.

### Estado observado y preparación manual — 1 de octubre de 2026

En la preparación inicial, Chrome confirmó que la cuenta `sooyvilla` no tenía GitHub Apps registradas, el repositorio no tenía secretos ni variables de Actions y solo existía el environment `github-pages`. En pub.dev, la publicación desde GitHub Actions estaba deshabilitada. El paquete `0.4.4` pertenece al publisher verificado `aimymoneyapp.com`.

Se dejaron abiertas cinco pantallas: registro de la App detenido en **Confirm access**, nuevo secreto, nueva variable, nuevo environment y Admin de pub.dev. Los nombres y los valores públicos indicados abajo están rellenados donde el formulario lo permite; los valores de las credenciales permanecen vacíos. Son borradores sin guardar: no se pulsaron **Add secret**, **Add variable**, **Configure environment** ni **UPDATE**, ni se creó o instaló una App. Los borradores pueden perderse al recargar o cerrar esas pestañas.

La App se registró posteriormente por petición expresa del dueño: **cupertino-fundations-models**, App ID `5152955`, Client ID `Iv23li6UHm1fEYwDkyEz`. GitHub confirmó **Registration successful**. En ese momento quedaban pendientes la clave privada, la instalación y guardar el Client ID.

### Configuración confirmada después del trabajo manual — 1 de octubre de 2026

El dueño completó la generación de la clave, la instalación, la variable, el secreto y el environment. Chrome confirmó la variable `PUBDEV_RELEASE_APP_CLIENT_ID` con el Client ID correcto, la existencia del secreto de repositorio `PUBDEV_RELEASE_APP_PRIVATE_KEY` y el environment `pub.dev` con regla de tags `v*`, sin revisores obligatorios. No se consultó el contenido de la clave ni se probó su autenticación.

La instalación había quedado en **All repositories**. Se corrigió a **Only select repositories** con únicamente `sooyvilla/cupertino_fundations_models`; GitHub confirmó el guardado. Conserva Contents read/write y Metadata read-only.

El dueño guardó **UPDATE** en pub.dev y autorizó el commit y push del CI/CD a `main`, conservando `0.4.4`. Al recargar Admin se confirmó la persistencia del repositorio, tag, evento y environment del paso 4. La autenticación del secreto y una publicación OIDC siguen sin prueba de ejecución.

### 1. GitHub App registrada

Abrir [ajustes de la App creada](https://github.com/settings/apps/cupertino-fundations-models). No crear otra App. Su configuración de registro es:

| Campo | Valor |
| --- | --- |
| GitHub App name | `cupertino-fundations-models`. GitHub no admite guiones bajos en el nombre de la App; el identificador del paquete se conserva. |
| Description | `Creates version tags for cupertino_fundations_models releases.` |
| Homepage URL | `https://github.com/sooyvilla/cupertino_fundations_models` |
| Callback URL / Setup URL | Vacías. |
| Request user authorization (OAuth) during installation | Desmarcado. |
| Webhook → Active | Desmarcado. |
| Repository permissions → Contents | **Read and write**. |
| Resto de permisos | Sin acceso adicional; Metadata se concede automáticamente. |
| Where can this GitHub App be installed? | **Only on this account**. |

El registro por sí solo no concede acceso al repositorio. La instalación debe limitarse a `cupertino_fundations_models`.

### 2. Generar la clave y guardar los datos en Actions

En **Private keys** de la App, pulsar **Generate a private key**; GitHub descargará un archivo PEM. Este paso lo completa el dueño porque crea una credencial nueva. No se necesita generar un client secret. Después, en **Install App**, instalarla en `sooyvilla`, seleccionar **Only select repositories** y elegir únicamente `cupertino_fundations_models`. Confirmar la instalación. Esto permite a la App crear los tags de entrega en ese repositorio.

| Pantalla | Name ya preparado | Value / Secret que debes introducir |
| --- | --- | --- |
| [Repository variables](https://github.com/sooyvilla/cupertino_fundations_models/settings/variables/actions) | `PUBDEV_RELEASE_APP_CLIENT_ID` | `Iv23li6UHm1fEYwDkyEz`, guardado y confirmado en la lista. |
| [New repository secret](https://github.com/sooyvilla/cupertino_fundations_models/settings/secrets/actions/new) | `PUBDEV_RELEASE_APP_PRIVATE_KEY` | Contenido completo del PEM, incluidas sus líneas BEGIN/END; guardar con **Add secret**. |

Introducir la clave directamente en GitHub y conservarla de forma privada. No enviarla por chat ni guardarla en este repositorio. Son variable y secreto del **repositorio**, porque el job que crea el tag no usa el environment `pub.dev`.

### 3. Crear el environment de publicación

En [New environment](https://github.com/sooyvilla/cupertino_fundations_models/settings/environments/new), el nombre `pub.dev` está preparado. Pulsar **Configure environment**.

En **Deployment branches and tags**, elegir **Selected branches and tags** y añadir una regla de tipo **Tag** con patrón `v*`. No añadir revisores obligatorios si se quiere publicación automática después del push autorizado. La configuración pertenece al nuevo environment `pub.dev`; conservar `github-pages`.

### 4. Guardar la confianza OIDC en pub.dev

En [Admin → Publishing from GitHub Actions](https://pub.dev/packages/cupertino_fundations_models/admin#github-actions), la configuración guardada es:

| Campo | Valor |
| --- | --- |
| Enable publishing from GitHub Actions | Marcado. |
| Repository | `sooyvilla/cupertino_fundations_models` |
| Tag pattern | `v{{version}}` |
| Enable publishing from push events | Marcado. |
| Enable publishing from workflow_dispatch events | Desmarcado. |
| Require GitHub Actions environment | Marcado. |
| Environment | `pub.dev` |

Tras completar GitHub, revisar estos valores y pulsar **UPDATE**. La publicación manual y Google Cloud se conservan como estaban. Guardar este formulario autoriza a los workflows del repositorio que cumplan el tag, evento y environment a publicar nuevas versiones; no publica una versión por sí solo.

### 5. Entregar el pipeline

Avisar cuando los cuatro pasos anteriores estén guardados; no compartir la clave privada. Confirmar la configuración visible y obtener la aprobación final del dueño antes de hacer commit y push del CI/CD a `origin/main`. La subida de esta configuración, con `0.4.4` sin cambios, no publicará otra versión del paquete. Esta aprobación corresponde a la instalación inicial; la ampliación Apple y su entrega posterior se autorizan por separado.

La GitHub App es necesaria porque los tags creados con el `GITHUB_TOKEN` habitual no disparan otro workflow. Pub.dev exige que su autenticación automática provenga del evento de un tag de versión. Las reglas de protección del repositorio deben permitir a la App crear esos tags.

El cierre tiene tres estados distintos: desarrollo local preparado, configuración externa confirmada y publicación automática observada. Subir el pipeline conservando `0.4.4` completa su instalación en el repositorio, pero no demuestra una publicación OIDC. Esa evidencia corresponde a una futura entrega autorizada con una versión nueva, su run de tag exitoso y la versión aceptada en pub.dev.

## Cada entrega

Terminar todo el trabajo antes de subirlo. Preparar la nueva versión y mantener alineados el changelog, el podspec, la versión de diagnóstico y el lock del ejemplo cuando corresponda. Revisar el resultado completo y recibir la aprobación de entrega; después subir el commit final a `main`.

- Misma versión: se ejecutan los controles de calidad y se omite la publicación.
- Versión diferente y aún inexistente: se crea su tag y se inicia la publicación.
- Versión ya publicada: se omite sin intentar reemplazarla.
- Error de configuración o de red: el workflow falla y conserva el código; no continúa a ciegas.

El job `verify` usa Flutter `3.47.5`, ejecuta `flutter analyze --no-pub`, las pruebas Python de los controles de entrega y `flutter test --coverage`. `.github/scripts/check_coverage.py` exige exactamente 100% de líneas ejecutables Dart bajo `lib/`, rechaza informes vacíos, inconsistentes o sin archivos ejecutables y conserva el LCOV como artifact. Los archivos con solo exports o firmas abstractas no tienen líneas ejecutables; no se excluye código ejecutable para alcanzar el umbral. La cobertura no mide Swift ni ramas.

`apple-builds` depende de `verify` y compila el ejemplo iOS Release sin firma y macOS Debug en `macos-latest`. La versión de Xcode corresponde a la imagen del runner; la validación local usa Xcode 27.2 beta para incluir las APIs nuevas. Estos builds no ejecutan apps ni prueban permisos, assets, modelos o PCC firmado.

`prepare` depende de ambos jobs y solo corre en pushes del repositorio principal. Los PR hacia `main` ejecutan los controles con permisos de lectura y no acceden al token de la App ni a OIDC. Los pushes a `main` y los tags vuelven a comprobar el commit recibido; cualquier fallo bloquea los jobs de entrega. El workflow oficial de Dart finalmente ejecuta `dart pub publish --dry-run` y publica dentro de `pub.dev` con OIDC.

## Si una publicación falla

Abrir **Actions → Publish to pub.dev** y revisar el run del **tag**, además del run de `main`. Corregir una configuración externa o un problema temporal y volver a ejecutar los jobs fallidos del run original del tag. Ese run conserva el evento necesario para OIDC.

Si la corrección cambia archivos del paquete, preparar una nueva versión y otro push final a `main`. Los tags existentes no se mueven ni se sobrescriben. Para una versión que pub.dev ya aceptó, cualquier corrección también requiere otra versión.

## Fuentes

- [Publicación automática oficial de Dart](https://dart.dev/tools/pub/automated-publishing)
- [Workflow oficial de publicación, con soporte Flutter](https://github.com/dart-lang/setup-dart/blob/v1/.github/workflows/publish.yml)
- [Eventos creados desde un workflow de GitHub](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)
- [Token temporal de una GitHub App](https://github.com/actions/create-github-app-token)
- [Registrar una GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)
- [Instalar una GitHub App propia](https://docs.github.com/en/apps/using-github-apps/installing-your-own-github-app)
- [Administrar las claves privadas de una GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps)
