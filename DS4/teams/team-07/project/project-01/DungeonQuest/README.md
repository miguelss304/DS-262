# Dungeon Quest

## Descripción
Dungeon Quest es un videojuego 2D de exploración de mazmorras hecho en **Godot 4.6**. El mapa se representa con un **grafo no dirigido y no ponderado**: cada sala es un vértice y cada puerta es el extremo de una arista. El grafo se **genera proceduralmente** en cada partida, y el jugador solo puede pasar de una sala a otra a través de las puertas que el grafo permite.

El proyecto tiene fines académicos (curso de Estructuras de Datos) y busca demostrar el uso de grafos, BFS y conjuntos disjuntos (Union-Find) dentro de un juego funcional.

## Qué hace el juego
- Genera un calabozo de 8 salas con una sala de entrada, una sala de salida y salas intermedias.
- El jugador aparece en la sala de entrada y se mueve con las flechas del teclado.
- Cada puerta lleva a otra sala: el jugador camina hacia el arco, la pantalla se oscurece y aparece en la puerta gemela de la sala destino.
- Cada cruce se valida contra el grafo antes de permitirse.
- Con la tecla de ayuda, la puerta que sigue la ruta más corta hacia la salida brilla (calculada con BFS).
- Al cruzar la puerta de victoria de la sala de salida, aparece la pantalla de victoria.
- Hay pantalla de inicio con las opciones **Jugar** y **Salir**.

## Requisitos
- Godot 4.6 (usa `@export_tool_button`, disponible desde 4.4).
- No requiere complementos ni recursos externos.

## Cómo ejecutar (macOS)

Este proyecto incluye un script de Bash (`ejecutar.sh`) que automatiza por completo la configuración en macOS: descarga e instala **Godot 4.6** de forma automática (si no está instalado), configura los permisos de seguridad del sistema y abre el juego directamente.

### Pasos para iniciar

1. **Dar permisos de ejecución al script**  
   Abre la Terminal en la raíz del proyecto y ejecuta el siguiente comando (solo es necesario hacerlo la primera vez):
   ```bash
   chmod +x ejecutar.sh
   ```

2. **Lanzar el script**  
   Inicia el asistente automático con el comando:
   ```bash
   ./ejecutar.sh
   ```

3. **Indicar la ruta del proyecto**  
   Cuando la Terminal lo solicite, **arrastra la carpeta de este proyecto** directamente a la ventana de la Terminal (o escribe su ruta manualmente) y presiona `Enter`.

El script se encargará de validar tu entorno, solucionar el bloqueo de Gatekeeper de macOS si descarga el motor por primera vez, e iniciará el juego inmediatamente sin necesidad de configurar nada de forma manual.



## Cómo ejecutar
1. Abre Godot.
2. Selecciona **Importar** y elige el archivo `project.godot`.
3. Abre el proyecto.
4. Pulsa **F5** para ejecutar.

## Controles
| Acción | Control |
|---|---|
| Moverse | Flechas del teclado |
| Pista hacia la salida (BFS) | Tecla asignada a la acción `help` |
| Cruzar una puerta | Caminar hacia el arco |

## Estructuras de datos y algoritmos

### Grafo (lista de adyacencia)
Implementado en `scripts/DungeonGraph.gd` con un `Dictionary` que asocia cada sala con un `Array` de vecinas. `add_edge` inserta la conexión en ambos sentidos.

| Operación | Complejidad |
|---|---|
| Consultar vecinos | O(1) |
| ¿Son vecinas `a` y `b`? | O(grado) |
| Agregar arista | O(grado) |

Se eligió lista de adyacencia sobre matriz porque el grafo es disperso (cada sala tiene como máximo 4 vecinas).

### BFS (búsqueda en anchura)
`bfs_path(inicio, meta)` devuelve la ruta con menos conexiones. Usa una cola, un diccionario de visitados y un diccionario de predecesores para reconstruir el camino. Complejidad **O(V + E)**. Se usa para la pista visual de la tecla de ayuda.

### Union-Find (conjuntos disjuntos)
`generate()` usa Union-Find con **compresión de caminos** para construir un árbol de expansión aleatorio entre las salas intermedias, lo que garantiza que todas las salas sean alcanzables. Después agrega aristas extra para crear ciclos y rutas alternativas.

### Generación procedural
1. Se crea un árbol de expansión aleatorio entre las salas intermedias (grado máximo 4).
2. Se agregan aristas extra sin superar el grado máximo.
3. La entrada (sala 1) se conecta a una sala intermedia y la salida (sala n) a la intermedia más lejana según BFS; ambas son hojas.
4. Se usa una **semilla** (`RandomNumberGenerator`), que se imprime en consola: la misma semilla produce el mismo mapa.

### Diccionario de puertas
`Main.gd` guarda las puertas en un `Dictionary` indexado por el par `Vector2i(desde, hacia)`. Al cruzar, la puerta gemela se obtiene con `Vector2i(hacia, desde)`.

## Cómo se construye el mapa
- Cada sala es una plantilla (`EntryRoom`, `ExitRoom`, `RoomA`, `RoomB`) de 480 × 270 px con **10 posiciones posibles de puerta** (`Slot_0` a `Slot_9`) en los bordes.
- Cada plantilla indica qué slots están deshabilitados según su forma (`Disabled Slots`).
- Cada slot tiene una **vista** (frente, atrás, izquierda, derecha) según la pared donde está.
- Para cada arista del grafo, el código instancia una puerta en cada sala. La puerta de llegada se coloca en la pared opuesta cuando es posible.
- La sala de salida solo se conecta por un slot fijo y tiene otro slot fijo para la puerta de victoria (`to_room = 0`, que no forma parte del grafo).
- Las salas se colocan separadas en una cuadrícula; no se conectan caminando, solo por las puertas.

## Estructura del proyecto
```text
DungeonQuest/
├── project.godot
├── README.md
├── assets/
│   ├── README.md
│   └── sprites/
├── scenes/
│   ├── Start.tscn          # pantalla de inicio
│   ├── Main.tscn           # juego
│   ├── Victory.tscn        # pantalla de victoria
│   ├── player.tscn
│   ├── objects/
│   │   ├── Door.tscn
│   │   └── DoorSlots.tscn
│   └── rooms/
│       ├── EntryRoom.tscn
│       ├── ExitRoom.tscn
│       ├── RoomA.tscn
│       └── RoomB.tscn
└── scripts/
    ├── Main.gd             # generación del mapa, cruce de puertas, fade, pista
    ├── DungeonGraph.gd     # grafo, BFS, generación con Union-Find
    ├── door.gd             # puerta: vistas, colisiones, brillo
    ├── door_slot.gd        # slot individual (vista editable en el editor)
    ├── door_slots.gd       # contenedor de slots y slots deshabilitados
    ├── room.gd             # interfaz de una sala
    ├── player.gd
    ├── start.gd
    └── victory.gd
```

## Estado actual
**Implementado**
- Movimiento del jugador con animaciones y colisiones.
- Cámara que sigue al jugador y se limita a la sala actual.
- Puertas con 4 vistas, colisiones por vista y brillo de pista.
- Transición al cruzar: paseo hacia el arco, fundido a negro y fundido de entrada.
- Grafo, BFS y generación procedural con semilla.
- Validación de cada cruce contra el grafo.
- Pantallas de inicio y victoria.

**Pendiente**
- Más plantillas de sala para dar variedad.
- Elegir la salida como la hoja más lejana de la entrada.
- Mostrar la ruta completa en pantalla.
- Pulido visual de los menús.

## Ideas a futuro
- Pila para una tecla de "volver atrás" (historial de salas).
- Implementar la cola de BFS con un arreglo circular propio.
- Tabla hash propia para los datos de cada sala.
- Puertas con costo y búsqueda de ruta ponderada (Dijkstra).
- Árbol de habilidades: ver `IDEA_ARBOL_HABILIDADES.md` (requiere añadir combate, que hoy no existe).

## Alcance
Por ahora no incluye combate, inventario ni enemigos. El objetivo es demostrar que el movimiento entre salas está restringido por un grafo, que BFS calcula la ruta más corta y que Union-Find permite generar mapas siempre conexos.