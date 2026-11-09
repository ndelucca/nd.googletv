# TCL Smart TV Pro — gestión por ADB

Este repo es la fuente de verdad de cómo se configura el televisor del living:
qué hay instalado, qué está deshabilitado, qué ajustes se tocaron y por qué.
Todo se hace con scripts idempotentes desde la PC (Fedora) por ADB sobre WiFi.

- **TV:** TCL Smart TV Pro (`G03_4K_GB` / `BeyondTV4`), Android TV 11, Realtek RTD288O, 2 GB RAM
- **Launcher:** Plume (reemplaza al launcher de Google TV, que está deshabilitado). Además reasigna los botones Netflix, YouTube y engranaje del control
- **Plan de optimización:** [`docs/PLAN.md`](docs/PLAN.md). Estado: olas 1–6 aplicadas y verificadas (etapa 1 el 2026-11-06, etapa 2 el 2026-11-09)
- **Último relevamiento:** [`inventory/SUMMARY.md`](inventory/SUMMARY.md)

## Requisitos

```bash
sudo dnf install android-tools python3
```

En el TV: Opciones de desarrollador → *Depuración USB* y *Depuración por red* activadas.
La primera conexión muestra un aviso en pantalla: aceptar con **"Permitir siempre"**.

La IP del TV está en [`tv.conf`](tv.conf) (se puede pisar con `TV_HOST=... ./scripts/...`).

## Scripts

| Script | Qué hace | ¿Cambia el TV? |
|---|---|---|
| `scripts/connect.sh` | Conecta (si no lo está) y muestra modelo, Android y launcher | No |
| `scripts/collect.sh` | Relevamiento completo → regenera `inventory/` | No |
| `scripts/apply.sh [--wave N]` | Muestra qué cambiaría para llevar el TV a `config/` | No (modo prueba) |
| `scripts/apply.sh --wave N --apply` | Backup y luego aplica las olas 0..N | **Sí** |
| `scripts/rollback.sh <backup> [--apply]` | Vuelve al estado de un backup | Solo con `--apply` |
| `scripts/doctor.sh` | ¿El TV sigue igual que `config/`? ¿Hubo OTA? ¿Algún protegido deshabilitado? | No |
| `scripts/benchmark.sh <etiqueta> --yes [--quick]` | Mide RAM, CPU del launcher y tiempos de arranque → `benchmarks/` (abre apps en pantalla ~12 min; `--quick` ~7 min, para comparar launchers) | Abre apps |
| `scripts/measure.sh <etiqueta>` | Reinicia, verifica y corre `benchmark.sh`: mediciones comparables entre sí | Reinicia y abre apps |
| `scripts/verify.sh [--ui]` | Prueba automática: arranque, WiFi, entradas HDMI, control, servicios clave, crashes. Con `--ui` abre cada app, una entrada HDMI, Ajustes y el protector, aprieta los botones de `config/buttons.conf` en un control virtual, y guarda capturas en `verify-screens/` | Abre apps con `--ui` |
| `scripts/wave.sh <N>` | Ola completa sin intervención: aplica → reinicia → verifica → si falla, revierte solo | **Sí** |
| `scripts/firmware-update.sh` | Rehabilita el actualizador de TCL, abre la pantalla de actualización y al terminar lo vuelve a deshabilitar | **Sí** |

Flujo de una ola (detalle en [`docs/PLAN.md`](docs/PLAN.md)):

```bash
./scripts/apply.sh --wave 1            # revisar qué va a cambiar
./scripts/wave.sh 1                    # aplicar + reiniciar + verificar (revierte solo si falla)
./scripts/benchmark.sh wave1 --yes && ./scripts/collect.sh
git add -A && git commit -m "TV: ola 1"
```

Mantenimiento: `./scripts/doctor.sh` de vez en cuando y después de cada actualización.
Si marca diferencias: `./scripts/apply.sh --wave $(cat state/applied-wave) --apply`.

El estado deseado vive en `config/` (una línea por cambio, con su motivo y su ola).
Los scripts solo tocan lo que difiere, así que se pueden correr cuantas veces se quiera.
Los paquetes críticos (HDMI, control, WiFi, ADB, arranque) están protegidos en `scripts/lib.sh`.
Los paquetes del sistema solo se deshabilitan, nunca se desinstalan; solo las apps instaladas por el
usuario se pueden desinstalar (`uninstall` en `config/packages.conf`, con copia del APK en el backup).
Las APK que no vienen de Play Store (el launcher) se instalan con `apply-apps.sh` desde una URL fija,
comprobando su SHA-256 (`config/apps.conf`; se cachean en `.cache/`, fuera de git).

`collect.sh` es de solo lectura y se puede correr cuantas veces se quiera: regenera
`inventory/` entero y las listas salen ordenadas, así que `git diff inventory/`
muestra exactamente qué cambió en el TV desde el último relevamiento.
Antes de guardar, enmascara emails, MACs, números de serie e IDs del equipo.

## Estructura

```
tv.conf              IP/puerto del TV
config/              estado deseado del TV (paquetes, apps fuera de Play, settings, appops, compilación,
                     launcher, botones del control)
state/               applied-wave (última ola aplicada), verify-reference.txt (cómo se ve un TV sano)
scripts/             lib.sh (funciones comunes) y los scripts de la tabla
backups/             foto del estado antes de cada aplicación + changes.log
benchmarks/          resultados de benchmark.sh
inventory/           salida de collect.sh (no editar a mano)
  SUMMARY.md         resumen legible: hardware, memoria, CPU, paquetes, ajustes
  packages.tsv       una fila por paquete: estado, versión, RAM, disco, arranque, uso
  device/            hardware, firmware, pantalla, códecs
  packages/          listas de paquetes, receptores de arranque, buckets, appops
  settings/          settings global/system/secure, device_config
  runtime/           memoria, CPU, procesos, kills, errores, uso (volátil)
  raw/               dumpsys completos para análisis profundo
docs/
  PLAN.md            diagnóstico + plan de optimización por olas
  research/          investigación con fuentes (TCL, Android TV 11, launchers/apps)
```
