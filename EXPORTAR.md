# Como exportar SURFER World Tour a .exe

Ya deje el preset de exportacion configurado (export_presets.cfg).
Solo tienes que hacer esto en Godot:

## Paso 1 — Descargar las plantillas (SOLO LA PRIMERA VEZ)
1. Abre el proyecto en Godot
2. Menu **Editor → Administrar plantillas de exportacion...**
3. Boton **Descargar e instalar** (pesa ~700 MB, tarda unos minutos)
4. Cuando termine, cierra esa ventana

## Paso 2 — Exportar
1. Menu **Proyecto → Exportar...**
2. Ya deberia aparecer el preset **"Windows Desktop"** en la lista
3. Boton **Exportar proyecto** (abajo)
4. IMPORTANTE: destilda **"Exportar con depuracion"** (abajo del dialogo)
5. Boton **Guardar**

## Resultado
Se crea la carpeta **SURFER-WorldTour-v1.0** al lado de godot-surfer,
con el archivo **"SURFER World Tour.exe"** — un solo archivo con todo
adentro (juego, sprites, musica). Doble clic y a jugar.

## Para compartirlo
- Comprime la carpeta como .zip y mandala por donde quieras
- El .exe corre en cualquier Windows 10/11 de 64 bits, sin instalar nada
- Nota: Windows puede mostrar el aviso azul "Windows protegio tu equipo"
  la primera vez (porque el .exe no esta firmado digitalmente — normal
  en juegos independientes). Se soluciona con
  **Mas informacion → Ejecutar de todas formas**

## Para las proximas versiones
1. Seguimos editando el proyecto normalmente con Claude
2. Cuando quieras una nueva version: Proyecto → Exportar → Exportar proyecto
3. Puedes cambiar el nombre de la carpeta de salida en el campo
   "Ruta de exportacion" del preset (ej: v1.1, v2.0...)

## El progreso de los jugadores
Se guarda automaticamente en la carpeta del usuario de Windows
(%APPDATA%/Godot/app_userdata/SURFER World Tour/), asi que actualizar
el .exe NO borra los records ni las estrellas de nadie.
