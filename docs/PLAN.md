# Plan de optimización del TV

_Basado en el relevamiento del 2026-11-06 ([`inventory/SUMMARY.md`](../inventory/SUMMARY.md)) y la investigación en [`research/`](research/)._

**Estado (2026-11-09):** etapas 1 y 2 terminadas. Olas 1–6 aplicadas y verificadas automáticamente en el TV (`state/applied-wave` = 6). El launcher ahora es **Plume**, y los botones Netflix, YouTube y engranaje del control vuelven a funcionar. Resultados en la [sección 5](#5-resultados). Quedan los pasos manuales de [`manual.md`](manual.md).

- **Etapa 1** (olas 1–5): optimizar lo que hay hoy, con FLauncher.
- **Etapa 2** (ola 6): cambiar el launcher, medido aparte.

## 1. Diagnóstico

### El cuello de botella es la RAM, no la CPU

| Dato medido | Valor | Qué significa |
|---|---|---|
| RAM total | 2048 MB | — |
| "Lost RAM" (reservada por el SoC para video/imagen) | ~710 MB | Android trabaja con **~1,3 GB**. Es hardware, no se puede cambiar |
| MemAvailable | ~385 MB | Muy justo |
| Apps en caché | **27 MB** (1 proceso) | Casi toda app que abrís arranca en frío; el launcher se recarga seguido |
| Procesos "Visible" + "Perceptible" | **~310 MB** | Memoria que el sistema **no puede liberar** aunque la necesite |
| zram (swap comprimido) | 1 GB, ~420 MB en uso | Ya activo y trabajando |
| CPU | 60–80 % libre, incluso reproduciendo YouTube | No es el problema |
| Load average | 28–31 | **Engañoso**: son hilos del kernel de HDMI/video en estado D, que Linux cuenta como carga |
| Governor de CPU | `performance` fijo a 1,3 GHz | Ya al máximo, no hay nada para ganar |

Esos ~310 MB "intocables" son, sobre todo, servicios de TCL y de Google que corren permanentemente:

| Proceso | RAM | Origen | ¿Hace falta? |
|---|---:|---|---|
| `com.google.android.katniss` (voz/búsqueda) | 66 MB | Google | Solo si usás el micrófono |
| `com.google.android.gms` | 64 MB | Google | Sí (las apps de streaming dependen de él) |
| `com.tcl.settings` | 34 MB | TCL | Sí (menú de imagen/sonido) |
| `com.google.android.apps.mediashell` (Chromecast) | 29 MB | Google | Solo si casteás |
| `com.tcl.dashboard` (panel del botón engranaje) | 23 MB | TCL | Opcional |
| `com.tcl.usercenter` (cuenta TCL) | 20 MB | TCL | No |
| `com.tcl.overseasappshow` (promos de apps) | 20 MB | TCL | No |
| `com.tcl.tv.tclhome_passive` (contenido TCL) | 19 MB | TCL | No |
| `com.tcl.ttvs` (telemetría TCL + actualizaciones) | 18 MB | TCL | Solo para recibir OTA |
| `com.tcl.guard` (TGuard: "limpiador" de memoria) | 16 MB | TCL | No (ver abajo) |
| `com.google.android.tv.remote.service` | 10 MB | Google | Solo si usás el celular como control |
| `com.tcl.miracast` | 8 MB | TCL | Solo si duplicás pantalla |

Además, **43 paquetes se inician solos al arrancar**.

### Otros hallazgos

- **El protector de pantalla está roto.** Aerial Views está configurado, pero falló 12 veces (`Unable to bind dream service`), porque el bloqueador de autoinicio de TCL (`TclAppBoot`) le niega `APP_AUTO_START`. El mismo README de Aerial Views documenta el arreglo. Ojo: Android guarda ese permiso en disco hasta 30 min después, y un `adb reboot` lo pierde. Por eso los scripts fuerzan el guardado (`cmd appops write-settings`) y reinician con `svc power reboot`, el reinicio limpio.
- **Hay dos "matadores" de memoria compitiendo.** TGuard (`com.tcl.guard`) mata apps por su cuenta (`tguard-kill-SystemApp`), además del `lmkd` de Android y del `omm-kill-cached` de TCL.
- **Las animaciones están las tres en 0.** Con `animator_duration_scale=0`, Android desactiva los animadores y algunas apps congelan spinners o efectos de foco. Lo recomendado es dejar ventana y transición en 0 y el animador en 0,5.
- **Hay daemons de IA de Realtek corriendo siempre.** `rtkm_scene` y `rtkm_ultraFace` (detección de escena y de rostros para la imagen) usan ~4 % de CPU y ~20 MB. Seguramente se apagan desde las opciones de imagen "AI"/"Adaptativo" del menú del TV (hay que probarlo).
- **FLauncher 0.18.0 está abandonado**: su última versión es de abril de 2023. La guía manual vieja (`TCL_TV_Setup_Guide.md`, borrada el 2026-11-06; queda en el historial de git) tenía una URL de descarga que da 404 y la actividad equivocada.
- **El firmware está al día.** LF1V652/AR11 con el parche de 2024-12-05 es el último build conocido para esta plataforma.
- **Lo que ya está bien:** FLauncher como home, el launcher de Google TV y `setupwraith` deshabilitados, backup apagado, apps ya compiladas con `speed-profile` y escaneo WiFi permanente apagado.
- **Almacenamiento:** 5 GB libres. Hay ~1,3 GB en cachés (Crunchyroll 470 MB, Immich 243 MB, Spotify 138 MB más 793 MB de datos). No afecta la velocidad, pero se puede limpiar.
- **Uso real en las últimas ~7 semanas:**
  - Se usan: YouTube (140 h, 68 aperturas), Netflix (18 h), FLauncher, Spotify (15 h) y Chromecast (14 h de servicio activo).
  - Ninguna apertura: Crunchyroll, Jellyfin, Prime Video y YouTube Music.
  - **2026-11-06:** se desinstalaron Disney+, Max y Paramount+. También se "desinstaló" Prime Video, pero como es de sistema solo perdió las actualizaciones; queda la versión de fábrica y se deshabilita en la ola 4.

### Qué hay que tener presente

- Es un **build de Google TV** (G03) con el launcher de Google apagado. En este firmware, los botones Netflix, YouTube, Prime y el engranaje del control dependen de ese launcher, así que probablemente no funcionen.
- Existe una lista comunitaria probada en el **mismo firmware exacto** ([cleanyourtv tcl-43c645](https://github.com/Gathin23/cleanyourtv/tree/main/examples/tcl-43c645)). Es la base de las olas TCL de este plan. La confianza es media: son pocas unidades y pocos días de prueba.
- Paquetes que **nunca** hay que tocar, porque rompen HDMI, el control, el WiFi o el arranque: `com.tcl.tv`, `com.tcl.tvinput`, `com.tvos`, `com.tcl.system.server`, `com.tcl.settings`, `com.tcl.suspension`, `com.tcl.providers.config`, `com.tcl.initsetup`, `com.tcl.tcl_bt_rcu_service`, `com.tcl.autopair`, `com.tcl.factory.view`, `com.android.location.fused`, gms/gsf/vending, webview, systemui, tv.settings y shell.

## 2. Principios

1. **El repo es la fuente de verdad.** El estado deseado vive en archivos de `config/`, con un motivo por línea, y los scripts lo hacen cumplir.
2. **Scripts idempotentes.** Cada script lee el estado actual, cambia solo lo que difiere e informa `ok` o `changed`. Correrlo dos veces da el mismo resultado.
3. **Modo prueba por defecto.** Sin `--apply` solo muestra lo que haría.
4. **Todo reversible.** Solo `pm disable-user` (se revierte con `pm enable`), nunca `pm uninstall`. Antes de cada cambio se guarda una foto del estado para poder volver atrás.
5. **Una lista de protegidos fija en el código.** Aunque alguien los ponga en `config/`, los paquetes críticos no se tocan.
6. **Medir antes y después.** Cada ola se compara con la anterior: mediana de 5 corridas, una ola por vez, un commit por ola con los números.
7. **Después de un OTA** (cambio de `ro.build.fingerprint`), `doctor.sh` detecta las diferencias con `config/` y se vuelve a aplicar.

## 3. Estructura

```
config/                          estado deseado; primera columna = ola
  packages.conf      <ola> <paquete> [uninstall]             → deshabilitado (o desinstalado si es app del usuario)
  apps.conf          <ola> <paquete> <versionCode> <sha256> <url> [grants=…]   APK fuera de Play (launcher)
  settings.conf      <ola> <global|secure|system|device_config:ns> <clave> <valor>
  appops.conf        <ola> <paquete> <op> <modo>             (RUN_ANY_IN_BACKGROUND, APP_AUTO_START)
  compile.conf       <ola> <paquete> <speed|speed-profile>
  home.conf          <ola> <componente HOME>
  buttons.conf       <ola> <botón> <código HID> <paquete>    botones del control que verify.sh prueba
  protected.conf     paquetes que jamás se tocan (además de PROTECTED_BUILTIN en lib.sh)
scripts/
  apply.sh [--wave N] [--apply]   backup + apply-{apps,home,packages,appops,settings,compile}.sh
  wave.sh N                       aplicar → reiniciar → verify.sh --ui → rollback si falla
  verify.sh [--ui]                ¿el TV funciona? (con --ui abre apps y prueba botones en pantalla)
  backup.sh / rollback.sh <dir>   foto del estado y vuelta atrás (rollback también en modo prueba)
  doctor.sh                       ¿el TV coincide con config/ hasta la última ola? ¿hubo OTA?
  benchmark.sh <etiqueta> --yes   mediciones → benchmarks/<fecha>-<etiqueta>.md (--quick: ~7 min)
  measure.sh <etiqueta>           reiniciar → verify.sh --ui → benchmark.sh (mediciones comparables)
  collect.sh                      relevamiento completo → inventory/
state/applied-wave                última ola aplicada (la usa doctor.sh)
backups/                          una carpeta por aplicación, con changes.log
benchmarks/                       resultados versionados
```

## 4. Olas

Cada ola: `scripts/wave.sh N` (backup → `apply --wave N --apply` → reinicio → `verify.sh --ui` → rollback automático si falla) → `benchmark` → `collect` → commit.

**Lo que `verify.sh` no puede comprobar solo** (mirarlo la próxima vez que se use el TV):
- [ ] Imagen real en un HDMI y el botón Inputs del control (el script abre la entrada, pero la captura de pantalla sale negra por protección de contenido)
- [ ] Botones físicos del control: Home, Back, volumen (el script verifica que el control está conectado e inyecta teclas). Netflix, YouTube y engranaje sí se prueban, con un control virtual idéntico al real (ver ola 6)
- [ ] Sonido
- [ ] Castear algo desde el celular (el script solo verifica que el servicio de Chromecast corre)
- [ ] Apagar y prender con el control (el arranque rápido)

### Ola 0 — Infraestructura y línea base (no cambia nada del TV)

- ✅ Scripts `apply-*`, `doctor`, `backup`, `rollback`, `benchmark`, `verify` y `wave` implementados y probados.
- ✅ Línea base: [`benchmarks/`](../benchmarks/) (`*-baseline.md`).
- `benchmark.sh` mide:
  - MemAvailable, swap libre, PSS por grupo de prioridad (Persistent/Visible/Perceptible = RAM que el sistema no puede liberar) y apps en caché tras 60 s de reposo en Home, antes y después de la prueba
  - Arranque en frío y en caliente (`am start -W`, mediana de 5) de YouTube, Netflix y Spotify
  - Vuelta a Home: tiempo y cuántas veces el launcher había sido matado
  - Multitarea: abrir 7 apps seguidas, volver a Home y contar cuántas siguen en memoria (3 rondas)
  - Kills por falta de memoria durante la prueba
  - Launcher en reposo: su RAM y su CPU, y la de surfaceflinger (si es alta, el launcher redibuja sin parar)
- **Necesita el TV libre unos 12 minutos**: abre y cierra apps en pantalla.
- Recomendación aparte: reservar la IP `192.168.10.20` para el TV en el router (DHCP estático), para que los scripts no se rompan si cambia.

### Ola 1 — Arreglos y ajustes sin riesgo ✅

| Cambio | Comando | Por qué |
|---|---|---|
| Arreglar el protector de pantalla | `appops set com.neilturner.aerialviews APP_AUTO_START allow` | Hoy falla siempre |
| Animador en 0,5 | `settings put global animator_duration_scale 0.5` | 0 rompe animaciones de algunas apps; ventana y transición quedan en 0 |
| Escaneo BLE permanente apagado | `settings put global ble_scan_always_enabled 0` | Menos trabajo de fondo |
| Sin aviso de redes WiFi | `settings put global wifi_networks_available_notification_on 0` | Menos trabajo de fondo |

**Manual en el menú del TV** (no se puede por ADB; se documenta en `docs/manual.md`):
- Desactivar *Uso y diagnóstico*.
- Ubicación: *Hogar* y modo tienda apagado.
- En Aerial Views, usar videos 1080p SDR (sin Dolby Vision) con "reducir buffers" activado.
- Probar a apagar las opciones de imagen "AI" o "Adaptativo" y ver con `top` si mueren `rtkm_scene`/`rtkm_ultraFace`. Comparar visualmente la imagen antes de decidir.

### Ola 2 — Basura de TCL (probada en este firmware exacto) ✅

Telemetría, promociones y servicios que no usás. Libera ~75 MB de la RAM "intocable".

`com.tcl.bi` · `com.tcl.logkit` · `com.tcl.overseasappshow` · `com.tcl.tv.tclhome_passive` · `com.tcl.usercenter` · `com.tcl.useragreement` · `com.tcl.messagebox` · `com.tcl.esticker` · `com.tcl.channelplus` · `com.tcl.waterfall.overseas` · `com.tcl.browser` · `com.tcl.android.webview` · `com.tcl.ocean.instructions` · `com.tcl.hearaid` · `com.tcl.gamebar` · `com.tcl.magiconnectfree` · `com.tcl.guard` · (`com.tcl.smartalexa` ya está)

- `com.tcl.guard` saca el "limpiador" que compite con Android. El botón Guard del control deja de hacer algo.
- `com.tcl.browser` hace que el botón Web del control, si existe, quede sin uso.

### Ola 3 — Google y AOSP sin uso en un TV ✅

Ganan poca RAM porque casi no corren, pero reducen arranques y tareas programadas.

`com.google.android.onetimeinitializer` · `com.google.android.feedback` · `com.google.android.sss.authbridge` · `android.autoinstalls.config.google.gtvpai` · `com.google.android.partnersetup` · `com.android.camera2` · `com.android.messaging` · `com.android.printspooler` · `org.chromium.webview_shell` · `com.android.hotspot2.osulogin` · `com.android.soundpicker` · `com.android.dreams.basic` · `com.google.android.apps.tv.dreamx` (después de arreglar Aerial Views) · `com.google.android.marvin.talkback` (si no usás accesibilidad)

### Ola 4 — Funciones que decidís vos ✅

Ver [Decisiones](#6-decisiones-tomadas-el-2026-11-06). Cada "no lo uso" libera RAM:

| Si no usás… | Se deshabilita | RAM |
|---|---|---:|
| Voz / botón del micrófono | `com.google.android.katniss`, `com.google.android.tv.assistant`, `com.tcl.assistant`, `com.tcl.micmanager` | ~66 MB, más 22 tareas programadas |
| Chromecast | `com.google.android.apps.mediashell` | ~29 MB |
| Panel del botón engranaje | `com.tcl.dashboard` | ~23 MB |
| Actualizaciones de firmware TCL | `com.tcl.ttvs`, `com.tcl.versionUpdateApp` | ~18 MB y 5 servicios. Para buscar una actualización: `scripts/firmware-update.sh` |
| Celular como control (app Google TV) | `com.google.android.tv.remote.service` | ~10 MB |
| Duplicar pantalla (Miracast) | `com.tcl.miracast` | ~8 MB |
| USB (fotos y videos) / "escuchar solo" con auriculares BT | `com.tcl.gallery`, `com.tcl.ui_mediaCenter`, `com.tcl.t_solo` | Poca; probar HDMI después |
| Apps preinstaladas sin uso | `com.amazon.amazonvideo.livingroom` (Prime Video, **ya decidido**: activo en `config/packages.conf`), `com.google.android.youtube.tvmusic` | Arranque y disco |

Las apps de terceros sin uso (Crunchyroll, Jellyfin) se pueden desinstalar normalmente si sobran.

### Ola 5 — Segundo plano y compilación ✅

- **Restringir el segundo plano** (`RUN_ANY_IN_BACKGROUND ignore`) en Crunchyroll y en cualquier app de streaming que se instale después. No en Spotify (música de fondo), Aerial Views, el launcher ni Jellyfin.
- **Mantener el bloqueo de autoinicio de TCL** (`APP_AUTO_START ignore`) para las apps de streaming. Hoy ya frena tareas de fondo de Spotify, así que juega a favor.
- ~~Compilar en `speed` las apps más usadas~~. **Descartado tras medirlo:** sin mejora medible. Spotify en frío varía mucho entre corridas, con o sin `speed` (680–2100 ms), y SystemUI tampoco cambió. YouTube y Netflix son mayormente código nativo, así que no ganan. Quedan en `speed-profile`, lo que el sistema usa por defecto.
- ~~Experimento A/B: `device_config put activity_manager use_compaction true`~~. **Descartado:** el kernel 4.14 no tiene `process_madvise` ni `/proc/<pid>/reclaim`, así que la compactación no hace nada.
- **Descartado:**
  - `max_cached_processes`, porque empeora los arranques en frío.
  - El congelador de apps, porque el kernel no lo soporta.
  - `wm size`/`wm density`, porque la evidencia es débil y hay riesgo de romper la interfaz.
  - "No mantener actividades".

### Ola 6 (etapa 2) — Launcher ✅

Detalle, mediciones y notas para volver a probar en [`research/launchers.md`](research/launchers.md#trial-on-this-tv-2026-11-09-plume-won).

- **Volver al launcher de Google no conviene.** Ronda los 165–190 MB y redibuja la pantalla 60 veces por segundo, incluso en "Modo solo apps".
- **Se probaron en el TV** FLauncher (el de antes), TV Launcher y Plume, de a uno, con `benchmark.sh --quick`.
- **Ganó Plume:** 0 % de CPU en reposo, 39 MB, y es el único que hace andar los botones Netflix, YouTube y engranaje (este último abre Ajustes). TV Launcher fue el más liviano (26 MB), pero deja esos botones muertos.
- **FLauncher gastaba un núcleo entero sin hacer nada:** 43 % de CPU más 35 % de surfaceflinger, porque redibuja la pantalla 60 veces por segundo aunque nadie la mire.
- FLauncher y TV Launcher se desinstalaron (`packages.conf`, `uninstall`; el backup guarda sus APK). La línea de TV Launcher queda comentada en `apps.conf` para volver a probarlo.
- **Botones del control:** no andaban desde la ola 0. El firmware de TCL se los pasa al launcher de Google (launcherx), que está deshabilitado. Plume los reasigna con su servicio de accesibilidad. Esa asignación vive en los datos de Plume: si se borran, `verify.sh --ui` falla y hay que volver a cargarla (pasos en `launchers.md`).
- **Cómo se prueban sin tocar el control:** `adb shell input keyevent` no pasa por los servicios de accesibilidad, así que no sirve. Los scripts crean un control virtual por `/dev/uhid` idéntico al real (mismo Bluetooth y modelo), cuyas pulsaciones siguen el mismo camino que las de verdad.

### Ola 7 — Mantenimiento

- `doctor.sh` después de cada actualización del sistema y una vez por semana: detecta paquetes rehabilitados, ajustes pisados y OTA.
- `collect.sh` y commit periódicos, para que el historial muestre cómo evoluciona el TV.
- `apply-apps.sh` para las APK fuera de Play (launcher): instala solo si la versión es mayor y el firmante coincide.
- Limpiar las cachés grandes (`pm trim-caches`) y reiniciar de verdad de vez en cuando (Ajustes → Sistema → Reiniciar). El arranque rápido de TCL casi nunca reinicia: este TV lleva 274 arranques en total y ahora 4 días encendido.

## 5. Resultados

Medido con `benchmark.sh` (reposo en Home con las apps de prueba cerradas; detalle en [`benchmarks/`](../benchmarks/)).

| | Línea base (ola 0) | Olas 1–4 | **Final (olas 1–5)** |
|---|---:|---:|---:|
| Paquetes habilitados | 128 | 88 | **88** |
| RAM que el sistema no puede liberar (Persistent + Visible + Perceptible) | 387 MB | 303 MB | **300 MB** (−22 %) |
| RAM de todo lo que no es caché de apps | 872 MB | 733 MB | **719 MB** (−153 MB) |
| Apps guardadas en caché (listas para volver al instante) | 3 (63 MB) | 13 (150 MB) | **13 (176 MB)** |
| Swap libre | 509 MB | 674 MB | **679 MB** |
| Multitarea: apps vivas después de abrir 7 seguidas | 5 de 7 (6, 5, 5) | 6 de 7 (6, 6, 6) | **6 de 7 (6, 6, 6)** |
| Kills por falta de memoria durante la prueba | ≥ 21 (TGuard y `omm` de TCL) | 0 | **1** (el propio `adb shell`) |
| Arranque en frío YouTube / Netflix | 620 / 606 ms | 623 / 596 ms | **617 / 585 ms** |
| Volver a Home | 84 ms, launcher nunca muerto | 89 ms, ídem | **90 ms, ídem** |
| Protector de pantalla | Roto | Anda | **Anda** |

Cómo leerlo:
- **Lo que mejoró:** el sistema gasta ~150 MB menos en servicios fijos y usa esa RAM para mantener **13 apps en caché en vez de 3**. TGuard ya no mata apps (en la línea base mataba FLauncher, YouTube y servicios de Google), y la multitarea pasó de 5 a 6 apps vivas de 7, de forma estable.
- **Lo que no cambió:** los tiempos de arranque en frío (~600 ms). Dependen de CPU y disco, y la CPU ya iba al máximo. Volver a Home ya era instantáneo.
- **MemAvailable bajó** (703 → 586 MB) porque Android usa la RAM liberada para guardar más apps en caché, que no cuentan como "disponibles". Es lo deseado.
- **Advertencia:** la línea base se midió con 4,5 días de encendido y el resto ~15 min después de reiniciar, así que el uso de swap no es del todo comparable.
- **Descartados por medición o por el hardware:** compilar en `speed` (sin mejora) y la compactación de memoria (el kernel 4.14 no la soporta).

### Etapa 2: launcher (2026-11-09)

Medido con `benchmark.sh --quick`, el mismo día y en el mismo estado del TV ([`benchmarks/`](../benchmarks/), `*-launcher-*.md`).

| | FLauncher (antes) | TV Launcher | **Plume (final)** |
|---|---:|---:|---:|
| RAM del launcher en reposo | 48 MB | 26 MB | **39 MB** |
| CPU en reposo: launcher / surfaceflinger | 43 % / 35 % | 0,2 % / 0,1 % | **0 % / 0 %** |
| Volver a Home | 78 ms | 87 ms | **90 ms** |
| Multitarea: apps vivas después de abrir 7 | 6 de 7 | 6 de 7 | **6 de 7** |
| Kills por falta de memoria | 1 | 0 | **0** |
| Botones Netflix / YouTube / engranaje | no andan | no andan | **andan** |

### Bitácora de la ejecución (2026-11-06)

- Cada ola se aplicó con `scripts/wave.sh N`: backup → aplicar → reiniciar → `verify.sh --ui` (abre las 9 apps, una entrada HDMI, Ajustes y el protector).
- **Ola 1, primer intento:** falló la verificación y se revirtió sola, pero eran dos falsas alarmas del verificador, que se corrigió:
  - El control remoto Bluetooth duerme después de reiniciar y no aparece hasta que se toca un botón.
  - `com.tcl.settings` se abre a demanda y Android lo cierra cuando está ocioso.
- **Hallazgo clave:** el permiso de autoinicio de Aerial Views se perdía en cada `adb reboot`, porque Android guarda los app-ops en disco hasta 30 min después. Solución en los scripts: `cmd appops write-settings` después de cambiarlo y reinicio limpio con `svc power reboot`. Verificado: el protector arranca aunque Aerial Views esté cerrado.
- Olas 2, 3, 4 y 5: aplicadas y verificadas al primer intento: 35 chequeos ok; solo se omitió el control dormido.
- Ola 5: `speed` se probó, no mejoró y se volvió a `speed-profile`.

### Bitácora de la etapa 2 (2026-11-09)

- `benchmark.sh` ganó el modo `--quick` (~7 min por launcher en vez de ~17) y la medición de CPU del launcher y de surfaceflinger en reposo.
- Nuevo `apply-apps.sh`: instala APK fuera de Play desde una URL fija, comprobando el SHA-256. Instalar un launcher nuevo borra el HOME elegido, por eso `apply.sh` aplica apps antes que home.
- **Hallazgo:** el servicio de Plume no arrancaba. `apply.sh` activaba el servicio de accesibilidad antes de dar `APP_AUTO_START`; TCL bloqueó el arranque y Android no reintenta. Ahora appops va antes que settings.
- **Hallazgo:** los botones Netflix, YouTube y engranaje no andaban desde la ola 0, al deshabilitar launcherx (el firmware le manda esos botones a él). Plume los reasigna. Se verificó con un control virtual: abren su app desde el inicio y desde otras apps, y mantener apretado el volumen sigue repitiendo normalmente.
- Plume quedó con solo la grilla de apps (fila de "Continue Watching" en *Never*).
- `packages.conf` admite `uninstall` para apps del usuario (nunca del sistema). El backup guarda sus APK para que `rollback.sh` las reinstale.

### Pendiente de comprobar a mano (la próxima vez que se use el TV)

- Que el control responda: el primer botón lo despierta. Home, Back, volumen, Inputs y la imagen real en un HDMI.
- Castear algo desde el celular.
- Los pasos de [`manual.md`](manual.md): *Uso y diagnóstico* apagado, modo *Hogar*, Aerial Views en 1080p SDR con "reducir buffers" y la prueba de las opciones de imagen "AI".
- Con el control real: Netflix y YouTube abren su app, y el engranaje abre Ajustes (probado con el control virtual).
- Sin efecto, como se esperaba: el botón del micrófono (voz deshabilitada) y el botón Guard.

## 6. Decisiones (tomadas el 2026-11-06 y el 2026-11-09)

| # | Tema | Decisión | Efecto en `config/` |
|---|---|---|---|
| 1 | Búsqueda por voz | No se usa | Ola 4: se deshabilitan `katniss`, `tv.assistant`, `tcl.assistant`, `tcl.micmanager` |
| 2 | Chromecast | Se usa | `mediashell` se mantiene |
| 3 | Celular como control | Se usa | `tv.remote.service` se mantiene |
| 4 | Miracast | No se usa | Ola 4: se deshabilita `tcl.miracast` |
| 5 | Panel del engranaje | No se usa | Ola 4: se deshabilita `tcl.dashboard` |
| 6 | USB y "escuchar solo" | Se mantienen | `gallery`, `ui_mediaCenter`, `t_solo` quedan |
| 7 | Firmware de TCL | Deshabilitado, con forma de volver a buscar actualizaciones | Ola 4: `tcl.ttvs` y `tcl.versionUpdateApp` apagados; `scripts/firmware-update.sh` los prende, abre la pantalla de actualización y los vuelve a apagar |
| 8 | YouTube Music, Crunchyroll, Jellyfin | Se quedan | Sin cambios (Prime Video sí se deshabilita) |
| 9 | Launcher | Plume, después de probar TV Launcher y Plume contra FLauncher (2026-11-09) | Ola 6: `home.conf`, `apps.conf`, su servicio en `settings.conf` y `appops.conf` |
| 10 | Botones Netflix/YouTube/engranaje | Que anden, si el launcher lo trae | Plume los reasigna; `buttons.conf` los verifica |
| 11 | Pantalla de inicio | Solo la grilla de apps | Plume: fila de series en *Never* (se configura en Plume) |
| 12 | FLauncher | Desinstalarlo | Ola 6: `uninstall` en `packages.conf` (TV Launcher también) |

La ejecución es desatendida: `scripts/wave.sh N` aplica, reinicia, verifica con `scripts/verify.sh --ui` (abre cada app, una entrada HDMI, Ajustes y el protector de pantalla) y, si algo falla, vuelve atrás solo.

## 7. Riesgos y recuperación

- Todo cambio se revierte con `pm enable <paquete>` mientras ADB responda. `rollback.sh` lo hace a partir de la foto previa.
- Si el TV no arranca después de un cambio:
  1. Esperar unos minutos y reintentar `adb connect`.
  2. Si sigue sin responder, entrar al menú de recuperación (arranca solo tras varios fallos) y hacer un restablecimiento de fábrica.
  3. Si ni eso funciona, flashear el firmware por USB.
- **Antes de cualquier restablecimiento de fábrica, rehabilitar `com.google.android.tungsten.setupwraith`.** Hoy está deshabilitado, y sin él el asistente de configuración inicial puede fallar.
- Los menús de servicio de TCL (Contraste + 1950/9735/6425…) solo se miran: cambiar valores ahí puede inutilizar el TV.
