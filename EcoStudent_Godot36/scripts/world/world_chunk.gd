extends Node2D

# Un chunk solo existe mientras está cerca de la cámara/jugador.
# El contenido es determinista: volver a un sector genera el mismo terreno.

const TrashScene = preload("res://scenes/trash/Trash.tscn")
const WORLD_SEED = 260821

# Densidad visual del mundo. Separado en constantes para poder ajustarla fácilmente.
const TREE_CHANCE = 0.018
const BUSH_CHANCE = 0.022
const STONE_CHANCE = 0.014

# Mantiene una zona limpia alrededor de las casas para evitar que árboles,
# arbustos, piedras o basura aparezcan atravesando el edificio.
const HOUSE_CLEAR_MARGIN = 2
const HOUSE_ROAD_MARGIN = 3
const HOUSE_WATER_MARGIN = 2

# Estanques procedurales. Se calculan con coordenadas globales para que
# continúen correctamente aunque crucen el borde entre chunks.
const POND_REGION_SIZE = 36
const POND_CHANCE_PERCENT = 58

# Basura global: el total visible en HUD es exactamente el total que existe.
# Se reparte de forma determinista por una zona amplia alrededor de la escuela,
# en vez de crear 2-3 residuos por cada chunk cargado.
const TRASH_WORLD_RADIUS_CHUNKS = 5 # zona de búsqueda de 11x11 chunks
const TRASH_SLOT_STEP = 47          # coprimo con 121 para no repetir chunks
const TRASH_SLOT_OFFSET = 23

var chunk_coord = Vector2.ZERO
var chunk_size = 12
var world_ysort = null

var terrain_tex = null
var trees_tex = null
var objects_tex = null
var slabs_tex = null
var house_tex = null

var ground = null
var collisions = null
var external_nodes = []
var blocked_cells = {}
var tree_cells = {}
var pond_region_cache = {}

func setup(coord, size, ysort, p_terrain, p_trees, p_objects, p_slabs, p_house):
    chunk_coord = coord
    chunk_size = size
    world_ysort = ysort
    terrain_tex = p_terrain
    trees_tex = p_trees
    objects_tex = p_objects
    slabs_tex = p_slabs
    house_tex = p_house

func build():
    ground = Node2D.new()
    ground.name = "Ground"
    add_child(ground)

    collisions = Node2D.new()
    collisions.name = "Collisions"
    add_child(collisions)

    _build_ground()
    _build_props()
    _spawn_trash()

func destroy():
    for node in external_nodes:
        if is_instance_valid(node):
            node.queue_free()
    external_nodes.clear()
    queue_free()

func cell_to_screen(cell):
    return Vector2((cell.x - cell.y) * 16.0, (cell.x + cell.y) * 8.0)

func atlas_region(texture, rect):
    var atlas = AtlasTexture.new()
    atlas.atlas = texture
    atlas.region = rect
    return atlas

func _sprite_from_region(texture, rect, pos, z = 0):
    var sprite = Sprite.new()
    sprite.texture = atlas_region(texture, rect)
    sprite.position = pos
    sprite.z_index = z
    return sprite

func _build_ground():
    var grass_rect = Rect2(160, 0, 32, 32)
    var dirt_rect = Rect2(128, 0, 32, 32)

    for ly in range(chunk_size):
        for lx in range(chunk_size):
            var global_cell = _global_cell(lx, ly)
            var road = _is_road(global_cell)
            var river = _is_river(global_cell)
            var pond = _is_pond(global_cell)
            var water = river or pond
            # El puente ya no ocupa todo el ancho de la carretera. Solo se
            # dibuja sobre la linea central del camino para evitar esos bloques
            # gigantes de madera cuando un estanque cruza una carretera ancha.
            var bridge = water and _is_bridge_cell(global_cell)

            var rect = grass_rect
            if road:
                rect = dirt_rect
            if water:
                rect = _water_tile_rect(global_cell, pond)

            var pos = cell_to_screen(global_cell)
            ground.add_child(_sprite_from_region(terrain_tex, rect, pos, -100))

            # En los estanques usamos los recortes irregulares de césped que ya
            # trae Terrain.png para romper el borde geométrico del agua. La orilla
            # se dibuja sobre el agua y se decide por los vecinos del mundo, por
            # eso también continúa correctamente entre chunks.
            if pond and not bridge:
                _add_pond_shore(global_cell, pos)

            if bridge:
                # El puente mantiene transitable el cruce de carretera/agua y
                # se orienta segun el eje del camino.
                _add_bridge(global_cell, pos)
            elif water:
                # Ríos y estanques no son transitables. Los colliders solo existen
                # mientras el chunk está cargado.
                _add_static_rect(pos + Vector2(0, 2), Vector2(25, 9))

            # Los estanques reciben decoración del mismo atlas: ondas y nenúfares.
            if pond:
                _decorate_pond(global_cell, pos)


func _add_bridge(cell, pos):
    var sprite = _sprite_from_region(slabs_tex, Rect2(0, 32, 32, 32), pos, -80)
    # En la cuadricula isometrica hay dos diagonales de carretera. El sprite
    # original del pack sirve para ambas al espejarlo horizontalmente.
    if _road_center_axis(cell) == 1:
        sprite.flip_h = true
    ground.add_child(sprite)

func _is_bridge_cell(cell):
    # La carretera visual tiene tres celdas de ancho, pero el puente debe ser
    # estrecho. Usamos solamente la linea central de cada carretera.
    return _road_center_axis(cell) != 0

func _road_center_axis(cell):
    var gx = int(cell.x)
    var gy = int(cell.y)
    var on_x_center = _positive_mod(gx - 7, 24) == 0
    var on_y_center = _positive_mod(gy - 7, 24) == 0

    if on_x_center and not on_y_center:
        return 1
    if on_y_center and not on_x_center:
        return 2

    if on_x_center and on_y_center:
        # Si justo coincide con una interseccion de caminos, elegimos el eje
        # que atraviesa mas agua para evitar formar un puente en cruz.
        var water_along_x = 0
        if _is_water(cell + Vector2(0, -1)):
            water_along_x += 1
        if _is_water(cell + Vector2(0, 1)):
            water_along_x += 1

        var water_along_y = 0
        if _is_water(cell + Vector2(-1, 0)):
            water_along_y += 1
        if _is_water(cell + Vector2(1, 0)):
            water_along_y += 1

        return 1 if water_along_x >= water_along_y else 2

    return 0

func _add_pond_shore(cell, pos):
    # Vecinos en la cuadrícula isométrica. Se consulta _is_water() y no solo
    # _is_pond() para que no aparezca una orilla artificial donde un estanque
    # conecta con el río.
    var nw_land = not _is_water(cell + Vector2(-1, 0))
    var ne_land = not _is_water(cell + Vector2(0, -1))
    var se_land = not _is_water(cell + Vector2(1, 0))
    var sw_land = not _is_water(cell + Vector2(0, 1))

    if not nw_land and not ne_land and not se_land and not sw_land:
        return

    var shore_rect = null

    # Las piezas vienen del bloque verde irregular de Terrain.png (filas 1 y 2).
    # Primero resolvemos bordes amplios; si solo toca tierra por una arista usamos
    # las tiras diagonales del atlas.
    if sw_land and se_land:
        # Costa hacia la parte inferior de la pantalla.
        shore_rect = Rect2(160, 32, 32, 32) # tile 5,1
    elif nw_land and sw_land:
        # Costa lateral izquierda.
        shore_rect = Rect2(288, 32, 32, 32) # tile 9,1
    elif ne_land and se_land:
        # Costa lateral derecha.
        shore_rect = Rect2(320, 32, 32, 32) # tile 10,1
    elif nw_land and ne_land:
        # Costa hacia la parte superior.
        shore_rect = Rect2(352, 64, 32, 32) # tile 11,2
    elif sw_land:
        shore_rect = Rect2(192, 32, 32, 32) # tile 6,1
    elif se_land:
        shore_rect = Rect2(224, 32, 32, 32) # tile 7,1
    elif nw_land:
        shore_rect = Rect2(288, 64, 32, 32) # tile 9,2
    elif ne_land:
        shore_rect = Rect2(320, 64, 32, 32) # tile 10,2

    if shore_rect != null:
        ground.add_child(_sprite_from_region(terrain_tex, shore_rect, pos, -94))

    # En esquinas muy expuestas agregamos una segunda pieza pequeña. Esto hace
    # que la silueta del lago pierda el aspecto de escalones de 32 px.
    var exposed = int(nw_land) + int(ne_land) + int(se_land) + int(sw_land)
    if exposed >= 3:
        var h = _cell_hash(int(cell.x), int(cell.y), 811) % 2
        var corner_rect = Rect2(160, 64, 32, 32) if h == 0 else Rect2(192, 64, 32, 32)
        ground.add_child(_sprite_from_region(terrain_tex, corner_rect, pos, -93))

func _water_tile_rect(cell, pond):
    # Fila 8 del Terrain.png: 0 es agua limpia y 1..3 incorporan pequeñas ondas.
    # En ríos usamos mayormente agua limpia; en estanques añadimos algo de variedad.
    var h = _cell_hash(int(cell.x), int(cell.y), 71) % 100
    if pond:
        if h < 73:
            return Rect2(0, 256, 32, 32)
        elif h < 84:
            return Rect2(32, 256, 32, 32)
        elif h < 93:
            return Rect2(64, 256, 32, 32)
        return Rect2(96, 256, 32, 32)

    if h < 91:
        return Rect2(0, 256, 32, 32)
    return Rect2(32, 256, 32, 32)

func _decorate_pond(cell, pos):
    var h = _cell_hash(int(cell.x), int(cell.y), 907) % 100

    # El Terrain.png incluye nenúfares/lotos transparentes en esta misma fila.
    # Se usan con poca frecuencia para que el agua no se vea saturada.
    if h < 4:
        ground.add_child(_sprite_from_region(terrain_tex, Rect2(320, 256, 32, 32), pos, -90))
    elif h < 6:
        ground.add_child(_sprite_from_region(terrain_tex, Rect2(352, 256, 32, 32), pos, -90))
    elif h == 7:
        ground.add_child(_sprite_from_region(terrain_tex, Rect2(384, 256, 32, 32), pos, -90))

func _build_props():
    var rng = RandomNumberGenerator.new()
    rng.seed = _chunk_seed()

    # Chunk inicial: edificio escolar provisional y patio despejado.
    if int(chunk_coord.x) == 0 and int(chunk_coord.y) == 0:
        _add_house(Vector2(3, 3))
        _reserve_house_area(3, 3)

    # Casas/edificios dispersos para que el mundo tenga puntos de referencia.
    # No basta con revisar la celda central: la casa ocupa varias celdas visuales.
    # Buscamos una parcela completa que quede separada de calles y agua.
    var spawn_building = int(abs(_chunk_seed())) % 7 == 0
    if spawn_building and not (int(chunk_coord.x) == 0 and int(chunk_coord.y) == 0):
        var house_found = false
        var house_lx = -1
        var house_ly = -1
        var house_cell = Vector2.ZERO

        for attempt in range(24):
            var bx = 3 + int(rng.randi() % max(1, chunk_size - 6))
            var by = 3 + int(rng.randi() % max(1, chunk_size - 6))
            var candidate = _global_cell(bx, by)

            if _can_place_house(candidate):
                house_found = true
                house_lx = bx
                house_ly = by
                house_cell = candidate
                break

        if house_found:
            _add_house(house_cell)
            _reserve_house_area(house_lx, house_ly)

    # Vegetación procedural. Se evita saturar caminos, agua y patio inicial.
    for ly in range(chunk_size):
        for lx in range(chunk_size):
            if _is_blocked(lx, ly):
                continue

            var global_cell = _global_cell(lx, ly)
            if _is_road(global_cell) or _is_water(global_cell):
                continue
            if _is_spawn_clear_area(global_cell):
                continue

            var roll = rng.randf()
            if roll < TREE_CHANCE:
                # Evita bosques demasiado compactos: dejamos al menos una celda
                # de separación entre árboles grandes.
                if not _has_nearby_tree(lx, ly, 2):
                    _add_tree(global_cell, rng.randf() > 0.48)
                    _mark_blocked(lx, ly)
                    _mark_tree(lx, ly)
            elif roll < TREE_CHANCE + BUSH_CHANCE:
                _add_bush(global_cell)
            elif roll < TREE_CHANCE + BUSH_CHANCE + STONE_CHANCE:
                _add_stone(global_cell)

func _spawn_trash():
    # Antes cada chunk creaba 2-3 basuras, por eso el mundo terminaba lleno de
    # residuos aunque el HUD pidiera solo 30. Ahora generamos exactamente
    # GameState.total_trash posiciones globales y cada chunk solo instancia las
    # que realmente le pertenecen.
    var total = max(1, int(GameState.total_trash))
    var types = ["paper", "plastic", "can"]

    for trash_index in range(total):
        var owner_chunk = _trash_chunk_for_index(trash_index)
        if int(owner_chunk.x) != int(chunk_coord.x) or int(owner_chunk.y) != int(chunk_coord.y):
            continue

        var local_cell = _find_trash_local_cell(trash_index)
        if local_cell.x < 0:
            continue

        var trash_id = "world_trash:%d" % trash_index
        if GameState.is_trash_collected(trash_id):
            continue

        var global_cell = _global_cell(int(local_cell.x), int(local_cell.y))
        var trash = TrashScene.instance()
        trash.position = cell_to_screen(global_cell)
        trash.trash_type = types[int(_cell_hash(trash_index, WORLD_SEED, 1201) % types.size())]
        trash.trash_id = trash_id
        world_ysort.add_child(trash)
        external_nodes.append(trash)

func _trash_chunk_for_index(index):
    # 11x11 = 121 chunks posibles. Usamos una permutación modular para que las
    # primeras 30 posiciones queden repartidas por toda la zona y no agrupadas
    # alrededor del origen.
    var side = TRASH_WORLD_RADIUS_CHUNKS * 2 + 1
    var slots = side * side
    var slot = int((index * TRASH_SLOT_STEP + TRASH_SLOT_OFFSET) % slots)
    var cx = int(slot % side) - TRASH_WORLD_RADIUS_CHUNKS
    var cy = int(slot / side) - TRASH_WORLD_RADIUS_CHUNKS
    return Vector2(cx, cy)

func _find_trash_local_cell(trash_index):
    # La posición dentro de su chunk también es determinista. Buscamos primero
    # posiciones aleatorias y luego hacemos un barrido de respaldo para garantizar
    # que no aparezca dentro del agua, en una calle o encima de una casa/árbol.
    var rng = RandomNumberGenerator.new()
    rng.seed = int(WORLD_SEED + trash_index * 104729 + 1709)

    for attempt in range(48):
        var lx = int(rng.randi() % chunk_size)
        var ly = int(rng.randi() % chunk_size)
        if _trash_cell_is_valid(lx, ly):
            return Vector2(lx, ly)

    var start = int(_cell_hash(trash_index, WORLD_SEED, 1301) % (chunk_size * chunk_size))
    for offset in range(chunk_size * chunk_size):
        var flat = int((start + offset) % (chunk_size * chunk_size))
        var lx = int(flat % chunk_size)
        var ly = int(flat / chunk_size)
        if _trash_cell_is_valid(lx, ly):
            return Vector2(lx, ly)

    return Vector2(-1, -1)

func _trash_cell_is_valid(lx, ly):
    if _is_blocked(lx, ly):
        return false

    var global_cell = _global_cell(lx, ly)
    if _is_water(global_cell):
        return false
    if _is_road(global_cell):
        return false

    return true

func _can_place_house(global_cell):
    # La base visual de House.png es mucho mayor que una sola celda isométrica.
    # Dejamos un colchón alrededor para que nunca quede montada encima de una
    # carretera, un cruce o una orilla de agua.
    for dy in range(-HOUSE_ROAD_MARGIN, HOUSE_ROAD_MARGIN + 1):
        for dx in range(-HOUSE_ROAD_MARGIN, HOUSE_ROAD_MARGIN + 1):
            var check_cell = global_cell + Vector2(dx, dy)
            if _is_road(check_cell):
                return false

    for dy in range(-HOUSE_WATER_MARGIN, HOUSE_WATER_MARGIN + 1):
        for dx in range(-HOUSE_WATER_MARGIN, HOUSE_WATER_MARGIN + 1):
            var check_cell = global_cell + Vector2(dx, dy)
            if _is_water(check_cell):
                return false

    return true

func _add_house(global_cell):
    var base = cell_to_screen(global_cell)
    var anchor = _make_anchor(base)
    var sprite = Sprite.new()
    sprite.texture = house_tex
    sprite.position = Vector2(0, -73)
    anchor.add_child(sprite)

    # La colisión anterior era demasiado baja y estrecha, por eso el jugador
    # podía "meterse" visualmente dentro de la casa. Usamos una huella más
    # amplia y alta que cubre mejor el cuerpo del edificio y el techo bajo.
    _add_static_rect(base + Vector2(0, -20), Vector2(104, 56))

func _add_tree(global_cell, green):
    var base = cell_to_screen(global_cell)
    var anchor = _make_anchor(base)
    var rect = Rect2(192, 0, 96, 96) if green else Rect2(96, 0, 96, 96)
    anchor.add_child(_sprite_from_region(trees_tex, rect, Vector2(0, -40), 0))
    _add_static_rect(base + Vector2(0, -4), Vector2(20, 14))

func _add_bush(global_cell):
    var anchor = _make_anchor(cell_to_screen(global_cell))
    anchor.add_child(_sprite_from_region(objects_tex, Rect2(160, 64, 32, 32), Vector2(0, -8), 0))

func _add_stone(global_cell):
    var anchor = _make_anchor(cell_to_screen(global_cell))
    anchor.add_child(_sprite_from_region(objects_tex, Rect2(64, 64, 32, 32), Vector2(0, -7), 0))

func _make_anchor(base_pos):
    var anchor = Node2D.new()
    anchor.position = base_pos
    world_ysort.add_child(anchor)
    external_nodes.append(anchor)
    return anchor

func _add_static_rect(pos, size):
    var body = StaticBody2D.new()
    body.collision_layer = 2
    body.collision_mask = 1
    body.position = pos

    var shape = RectangleShape2D.new()
    shape.extents = size * 0.5

    var collision = CollisionShape2D.new()
    collision.shape = shape
    body.add_child(collision)
    collisions.add_child(body)

func _global_cell(lx, ly):
    return Vector2(
        int(chunk_coord.x) * chunk_size + lx,
        int(chunk_coord.y) * chunk_size + ly
    )

func _chunk_seed():
    var cx = int(chunk_coord.x)
    var cy = int(chunk_coord.y)
    return int(WORLD_SEED + cx * 73856093 + cy * 19349663)

func _is_road(cell):
    var gx = int(cell.x)
    var gy = int(cell.y)

    # Dos ejes principales cerca de la escuela + red de caminos cada 24 celdas.
    if abs(gx - 7) <= 1 or abs(gy - 7) <= 1:
        return true

    var mx = _positive_mod(gx - 7, 24)
    var my = _positive_mod(gy - 7, 24)
    return mx <= 1 or mx >= 23 or my <= 1 or my >= 23

func _is_water(cell):
    return _is_river(cell) or _is_pond(cell)

func _is_river(cell):
    var gx = int(cell.x)
    var gy = int(cell.y)
    var river_center = 30 + int(round(sin(float(gy) * 0.085) * 5.0))
    return abs(gx - river_center) <= 2

func _is_pond(cell):
    var gx = int(cell.x)
    var gy = int(cell.y)

    # Dejamos el patio inicial limpio y evitamos que un estanque invada la escuela.
    if gx >= -4 and gx <= 15 and gy >= -4 and gy <= 15:
        return false

    # Regla nueva: los lagos no deben tocar ni acercarse demasiado a las calles.
    # Si una celda está en carretera o muy cerca de una, jamás se considera agua.
    if _is_near_road(cell, 2):
        return false

    var region_x = int(floor(float(gx) / float(POND_REGION_SIZE)))
    var region_y = int(floor(float(gy) / float(POND_REGION_SIZE)))

    # Revisamos regiones vecinas porque una laguna puede cruzar el borde de su
    # región lógica y, por tanto, también el borde físico de un chunk.
    for oy in range(-1, 2):
        for ox in range(-1, 2):
            var rx = region_x + ox
            var ry = region_y + oy
            var region = _get_pond_region_data(rx, ry)
            if not region["enabled"]:
                continue
            if region["near_road"]:
                continue

            var center_x = int(region["center"].x)
            var center_y = int(region["center"].y)
            var radius_x = int(region["radius"].x)
            var radius_y = int(region["radius"].y)

            var dx = float(gx - center_x) / float(radius_x)
            var dy = float(gy - center_y) / float(radius_y)
            var ellipse = dx * dx + dy * dy

            # Pequeña irregularidad determinista en el contorno para que no sean
            # elipses matemáticamente perfectas.
            var edge = float(_cell_hash(gx, gy, 487) % 100) / 1000.0
            if ellipse <= 1.0 + edge:
                return true

    return false

func _get_pond_region_data(rx, ry):
    var key = "%d:%d" % [rx, ry]
    if pond_region_cache.has(key):
        return pond_region_cache[key]

    var data = {
        "enabled": false,
        "center": Vector2.ZERO,
        "radius": Vector2.ZERO,
        "near_road": true,
    }

    if not _pond_region_enabled(rx, ry):
        pond_region_cache[key] = data
        return data

    var h1 = _cell_hash(rx, ry, 151)
    var h2 = _cell_hash(rx, ry, 263)
    var h3 = _cell_hash(rx, ry, 379)

    var margin = 8
    var inner = POND_REGION_SIZE - margin * 2
    var center_x = rx * POND_REGION_SIZE + margin + int(h1 % inner)
    var center_y = ry * POND_REGION_SIZE + margin + int(h2 % inner)
    var radius_x = 4 + int(h2 % 4) # 4..7 celdas
    var radius_y = 3 + int(h3 % 3) # 3..5 celdas
    var center = Vector2(center_x, center_y)

    # Los estanques se mantienen separados del río principal.
    if _is_river(center):
        pond_region_cache[key] = data
        return data

    data["enabled"] = true
    data["center"] = center
    data["radius"] = Vector2(radius_x, radius_y)
    # Se descarta la laguna completa si su huella o un pequeño margen toca carretera.
    data["near_road"] = _pond_region_near_road(center_x, center_y, radius_x, radius_y, 2)

    pond_region_cache[key] = data
    return data

func _pond_region_near_road(center_x, center_y, radius_x, radius_y, margin):
    for y in range(center_y - radius_y - margin, center_y + radius_y + margin + 1):
        for x in range(center_x - radius_x - margin, center_x + radius_x + margin + 1):
            var dx = abs(x - center_x)
            var dy = abs(y - center_y)
            # Recortamos las esquinas del rectángulo para no revisar más de la cuenta.
            if dx > radius_x + margin or dy > radius_y + margin:
                continue
            if _is_road(Vector2(x, y)):
                return true
    return false

func _is_near_road(cell, margin):
    for y in range(int(cell.y) - margin, int(cell.y) + margin + 1):
        for x in range(int(cell.x) - margin, int(cell.x) + margin + 1):
            if _is_road(Vector2(x, y)):
                return true
    return false

func _pond_region_enabled(rx, ry):
    return int(_cell_hash(rx, ry, 53) % 100) < POND_CHANCE_PERCENT

func _cell_hash(x, y, salt):
    # Hash entero rápido y determinista. Se mantiene dentro de 31 bits para evitar
    # desbordamientos caros durante la generación de chunks.
    var n = int(x * 374761393 + y * 668265263 + salt * 69069 + WORLD_SEED * 31)
    n = int(n % 2147483647)
    if n < 0:
        n += 2147483647
    n = int((n * 1103515245 + 12345) % 2147483647)
    return n

func _is_spawn_clear_area(cell):
    return cell.x >= 0 and cell.x <= 11 and cell.y >= 0 and cell.y <= 11

func _positive_mod(value, modulus):
    return ((value % modulus) + modulus) % modulus



func _reserve_house_area(lx, ly):
    # La casa ocupa visualmente bastante más que una celda isométrica.
    # Reservamos su huella 2x2 y un margen alrededor para crear un pequeño
    # patio limpio y evitar que copas/troncos se dibujen encima de la casa.
    var min_x = lx - HOUSE_CLEAR_MARGIN
    var max_x = lx + 1 + HOUSE_CLEAR_MARGIN
    var min_y = ly - HOUSE_CLEAR_MARGIN
    var max_y = ly + 1 + HOUSE_CLEAR_MARGIN

    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            _mark_blocked(x, y)

func _mark_tree(lx, ly):
    tree_cells["%d:%d" % [lx, ly]] = true

func _has_nearby_tree(lx, ly, radius = 1):
    for y in range(ly - radius, ly + radius + 1):
        for x in range(lx - radius, lx + radius + 1):
            if x == lx and y == ly:
                continue
            if tree_cells.has("%d:%d" % [x, y]):
                return true
    return false

func _mark_blocked(lx, ly):
    if lx < 0 or ly < 0 or lx >= chunk_size or ly >= chunk_size:
        return
    blocked_cells["%d:%d" % [lx, ly]] = true

func _is_blocked(lx, ly):
    return blocked_cells.has("%d:%d" % [lx, ly])
