PAQUETE DE ANIMACIÓN 2D — GODOT 4.7

Este paquete contiene recursos visuales para un personaje 2D de plataformas. Es independiente de cualquier juego o proyecto previo: no contiene un proyecto Godot ni presupone que ya exista un controlador, una escena del jugador o un sistema de escalada.

CONTENIDO
- spritesheets/*.png: hojas PNG RGBA con transparencia real; una fila horizontal por animación.
- frames/<animacion>/*.png: frames individuales de 256x256 px.
- previews/: vistas previas para inspección (no importar como sprites de juego).
- animation_manifest.json: número de frames, FPS, loop y metadatos por animación.
- PROMPT_IMPLEMENTACION_GODOT_ES.txt: prompt para crear una base de juego nueva e integrar el personaje.

ANIMACIONES
- idle: 4 frames, 8 FPS, loop.
- walk: 8 frames, 12 FPS, loop.
- jump: 5 frames, 12 FPS, no loop.
- fall: 2 frames, 8 FPS, loop.
- land: 3 frames, 12 FPS, no loop.
- climb: 8 frames, 12 FPS, loop.

IMPORTACIÓN
- Cada frame mide 256x256 px.
- Cada spritesheet contiene una sola fila. Se puede importar en AnimatedSprite2D/SpriteFrames creando AtlasTexture de 256x256 por frame, o cargando los PNG individuales.
- El personaje mira hacia la derecha. Utilizar flip_h para mirar a la izquierda.
- Los PNG tienen canal alfa; el fondo de tablero de la lámina de referencia no forma parte de los sprites.

NOTAS DE ARTE E INTEGRACIÓN
- El estilo es ilustración monocromática entintada, no pixel art.
- Los frames de CLIMB incluyen una cuerda vertical dibujada junto al personaje. El controlador debe tratarla como parte del recurso visual y alinear con ella el elemento escalable del nivel, o ajustar esos frames si se decide usar una cuerda/ladder dibujada por separado. Evitar mostrar dos cuerdas superpuestas.
- El contenido del personaje ocupa solo una parte de cada celda. El agente debe revisar el pivote y el apoyo de los pies en Godot, y mantener estable la posición del cuerpo al cambiar de animación.
- Los recursos proceden de una extracción rasterizada de una hoja generada. Revisar los bordes y la continuidad visual en el juego antes de considerarlos arte final definitivo.
