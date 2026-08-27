# EcoStudent - Godot 3.6

Prototipo 2D educativo donde un estudiante recorre un escenario y recoge basura.

## Requisitos
- Godot 3.6 estándar (GDScript, no hace falta Mono).

## Ejecutar
1. Abre Godot 3.6.
2. Importa la carpeta `EcoStudent_Godot36` como proyecto.
3. Pulsa F5 para ejecutar.
4. Usa flechas o WASD para moverte.
5. Toca la basura para recogerla.
6. Pulsa `1` para usar la estudiante femenina y `2` para usar el estudiante masculino.

## Personajes reales integrados
Los cuatro spritesheets suministrados se copiaron a `assets/characters/` con nombres simples:

- `female_idle.png`
- `female_walk.png`
- `male_idle.png`
- `male_walk.png`

Cada spritesheet mide **192x384 px** y está organizado como:

- **4 columnas** de frames.
- **8 filas** de direcciones.
- Cada frame ocupa **48x48 px**.

Direcciones configuradas:

1. izquierda
2. derecha
3. abajo
4. arriba
5. abajo-izquierda
6. abajo-derecha
7. arriba-izquierda
8. arriba-derecha

El jugador utiliza `AnimatedSprite` de Godot 3.6 y genera automáticamente 16 animaciones por personaje:

- 8 animaciones `idle_*`
- 8 animaciones `walk_*`

## Incluye
- `KinematicBody2D` para el jugador.
- Animación real de niña y niño en 8 direcciones.
- Idle y Walking.
- Cambio de personaje en ejecución con teclas 1/2.
- Cámara que sigue al jugador.
- Escenario isométrico construido con los PNG suministrados.
- Casa, árboles, arbustos, piedras y pasarela de madera.
- YSort para que el jugador pase visualmente delante/detrás de los objetos según su posición.
- Colisiones básicas.
- Basura coleccionable: papel, plástico y lata.
- HUD con contador.
- Objetivo completado al recoger toda la basura.
- Pixel art sin filtrado desde los scripts.
- Código modular separado por jugador, mundo, basura, UI y estado del juego.

## Assets de escenario
- `Terrain.png`: 416x384.
- `Objects.png`: 192x96.
- `Trees.png`: 288x192.
- `Wooden Slabs.png`: 128x128.
- `House.png`: 160x160.

## Estructura
```text
EcoStudent_Godot36/
├── project.godot
├── assets/
│   ├── characters/
│   └── farm/
├── scenes/
│   ├── player/
│   ├── trash/
│   └── ui/
└── scripts/
    ├── player/
    ├── systems/
    ├── trash/
    ├── ui/
    └── world/
```

## Próximo paso sugerido
Construir la escuela y reemplazar la basura temporal dibujada por sprites reales de papel, botella, lata y residuos orgánicos.
