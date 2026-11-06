# Ajustes manuales (menú del TV)

Cosas que no se pueden hacer por ADB. Marcar con la fecha cuando estén hechas, para que el repo refleje el estado real.
Los nombres de menú son aproximados: varían según el idioma y el firmware.

## Ola 1

- [ ] **Uso y diagnóstico apagado** — Ajustes → Preferencias del dispositivo → Uso y diagnóstico (envío a Google).
- [ ] **Modo hogar / sin modo tienda** — Ajustes → Preferencias del dispositivo → Ubicación/Modo de uso = *Hogar*; "Ajuste automático de tienda" apagado.
- [ ] **Aerial Views liviano** — abrir la app Aerial Views:
  - Calidad: **1080p** y SDR (sin Dolby Vision ni 4K). HEVC está bien porque el TV lo decodifica por hardware; si se traba, H.264.
  - Activar la opción para reducir buffers y RAM (agregada en la 1.8.4).
- [ ] **Imagen "AI" / adaptativa** (experimento) — en Imagen → Inteligente/AI, probar a apagar "Contenido adaptativo", "Brillo adaptativo" o "AI-PQ". Después, desde la PC:
  ```bash
  adb -s 192.168.10.20:5555 shell top -b -n 1 | grep rtkm_
  ```
  Si `rtkm_scene` y `rtkm_ultraFace` desaparecen o bajan a 0 % de CPU, se ganan ~4 % de CPU y ~20 MB. Comparar la imagen a ojo antes de decidir. Si se ve peor, volver a activarlo.

## Mantenimiento

- [ ] **Reinicio real de vez en cuando** — Ajustes → Sistema → Reiniciar. El "arranque rápido" de TCL suspende en lugar de apagar, y el TV puede pasar días sin reiniciar.
- [ ] **Actualizaciones automáticas de Play Store** (opcional) — Play Store → Ajustes → Actualizar apps automáticamente = no. Después de actualizar a mano, correr `scripts/apply.sh --wave <última> --apply`, que vuelve a compilar lo que haga falta.

## Nunca

- Los menús de servicio (Contraste + 1950 / 9735 / 6425 / 9705 / 6405): solo mirar. "Reset Shop" borra todo y un valor mal puesto puede inutilizar el TV.
- Restablecer de fábrica sin rehabilitar antes `com.google.android.tungsten.setupwraith` (`adb shell pm enable com.google.android.tungsten.setupwraith`).
