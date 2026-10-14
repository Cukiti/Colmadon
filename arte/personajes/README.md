# Caras editables de los siete personajes

Las carpetas `fello`, `yeya`, `chichi`, `nena`, `tito`, `rafa` y `colmadero` contienen sus archivos fuente `caras.aseprite`. Todos conservan la identidad del dibujo del juego, con lienzo 64×64, diez fotogramas etiquetados y capas Piel, Rasgos, Rubor y Detalle 64 - pixel art.

Orden: neutral, parpadeo, guino, hablar, hablar_abierto, enfado, susto, risa, rubor, rubor_parpadeo. Las diez caras son estados que selecciona el juego, no una secuencia que deba reproducirse entera. Los movimientos del cuerpo siguen siendo animaciones 3D.

## Editar y llevar el resultado a Godot

1. Abrir `caras.aseprite` en Aseprite, editar los fotogramas y guardar. Conservar el tamaño, número/orden de frames y etiquetas.
2. Exportar con el ejecutable de Aseprite, desde la carpeta del proyecto:

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe' -b --script-param "root=$((Get-Location).Path.Replace('\','/'))" --script tools/exportar_aseprite.lua
```

3. Abrir/importar el proyecto en Godot. El personaje lee `caras.png` (640×64), con escalado nearest; el archivo `.aseprite` se mantiene como fuente. El compositor B suaviza ligeramente los contornos del render.

`tools/exportar_aseprite.lua` exporta el dibujo editado sin volver a generarlo. `tools/exportar_caras_aseprite.gd` y `tools/crear_caras_aseprite.lua` documentan la migración inicial desde los dibujos de código: El creador conserva los editables que ya existen y el exportador de referencias conserva las fuentes previas. No borrar un editable para regenerarlo si tiene cambios de dibujo. Las imágenes en `fuentes/` son la referencia original.

`tests/prueba_caras_aseprite.gd` verifica las 70 expresiones de 64×64 y que tengan detalles distintos de una ampliación nearest de las referencias 16×16, incluidas carga, expresiones, rubor y retorno a normal. También comprueba habla, emociones, rubor y que los avatares personalizados conserven su funcionamiento.

Los siete presets fijos, incluidos sus retratos de selección, cargan las caras de Aseprite al usar setup(nombre). El editor de avatares y los aspectos personalizados con setup_cfg conservan la generación procedural para respetar los cambios de piel, pelo y vello facial. La configuración de los presets no se modifica al cargarlos. Esta migración usa Aseprite local en modo batch; las herramientas MCP no están cargadas en este chat.

## Ropa de Don Fello, Yeya y Chichí

Cada uno tiene también "ropa.aseprite" (64×64, un frame y capas Tela, Costuras y pliegues, Bordado y detalles, Detalle 64 - pixel art). Sus versiones fijas leen la exportación ropa.png. Los avatares personalizados siguen usando la ropa procedural para conservar sus colores y estampados.

Después de editar y guardar, exportar con Aseprite usando tools/exportar_ropa_aseprite.lua y el mismo parámetro root del ejemplo anterior. tools/crear_ropa_aseprite.lua solo crea editables ausentes; conserva los que existen. La nueva ropa añade alforzas/bolsillos/botones a la guayabera, flores completas y hojas a la blusa, y contorno al número 7 con costuras de camiseta.

## Fuentes de 64 × 64

Las caras y las tres prendas se detallaron a 64×64 en Aseprite, partiendo de sus versiones de 16×16 y añadiendo trazos finos en una capa separada. Los originales se conservan como caras_16.aseprite / caras_16.png y ropa_16.aseprite / ropa_16.png. tools/detallar_64_aseprite.lua realiza esa migración una vez y no sustituye fuentes ya a 64×64. Los exportadores aceptan 16 o 64 y guardan los PNG a su tamaño nativo. El compositor B y la escena de 640×360 conservan el estilo pixel art; una textura 64×64 no cambia la resolución final de la pantalla.

Corrección del habla con bigote: Fello, Tito y colmadero incorporan capa `Bigote sigue al labio` en hablar, hablar_abierto y risa. El bigote acompaña el labio y deja visibles los dientes. tools/corregir_bigote_aseprite.lua aplica esta reparación por capa; para ediciones artísticas posteriores usar el editable y el exportador normal, sin volver a aplicar la reparación sobre un dibujo retocado.