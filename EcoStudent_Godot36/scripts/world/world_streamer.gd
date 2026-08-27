extends Node2D

# EcoStudent - streaming suave de mundo por chunks para Godot 3.6.
# La idea es que NUNCA se cargue un chunk justo cuando ya entró en cámara:
# 1) mantenemos una zona segura completa alrededor del jugador,
# 2) precargamos hacia donde se está moviendo,
# 3) cargamos la precarga poco a poco para evitar tirones,
# 4) descargamos más lejos que la distancia de carga (histeresis).

signal stream_stats_changed(chunk_x, chunk_y, loaded_chunks)

const WorldChunk = preload("res://scripts/world/world_chunk.gd")

const CHUNK_SIZE = 12
const STREAM_CHECK_INTERVAL = 0.08
const OBJECTIVE_TRASH = 30

# Radio mínimo que debe estar completamente construido alrededor del jugador.
# Para una ventana ~1366x768 normalmente termina siendo 2 => 5x5 chunks seguros.
const MIN_SAFE_RADIUS = 2
const MAX_SAFE_RADIUS = 3

# Distancia, en píxeles de mundo, usada para anticipar hacia dónde camina el jugador.
const PREFETCH_DISTANCE = 300.0

# Cuántos chunks de precarga se construyen por frame. Mantener bajo evita microparones.
const PREFETCH_BUILDS_PER_FRAME = 1

onready var chunks_root = $Chunks
onready var world_ysort = $WorldYSort
onready var player = $WorldYSort/Player

var terrain_tex = preload("res://assets/farm/Terrain.png")
var trees_tex = preload("res://assets/farm/Trees.png")
var objects_tex = preload("res://assets/farm/Objects.png")
var slabs_tex = preload("res://assets/farm/Wooden Slabs.png")
var house_tex = preload("res://assets/farm/House.png")

var loaded_chunks = {}
var pending_chunks = []
var pending_keys = {}

var current_chunk = Vector2(999999, 999999)
var predicted_chunk = Vector2(999999, 999999)
var stream_timer = 0.0

var safe_radius = MIN_SAFE_RADIUS
var unload_radius = MIN_SAFE_RADIUS + 1

var last_player_position = Vector2.ZERO
var movement_direction = Vector2.ZERO

func _ready():
	_disable_texture_filtering()
	_calculate_stream_radii()
	GameState.reset(OBJECTIVE_TRASH)

	# Punto inicial cerca del edificio escolar provisional.
	player.position = cell_to_screen(Vector2(7, 7))
	last_player_position = player.global_position

	# En el arranque sí construimos completa la zona segura. El pequeño costo inicial
	# es preferible a ver terreno aparecer durante los primeros segundos.
	_refresh_stream(true)

func _process(delta):
	_update_motion_prediction()

	# La precarga se reparte entre frames. Como ocurre fuera de cámara, el jugador
	# no ve aparecer el contenido y tampoco recibe un pico grande de CPU.
	_process_prefetch_queue()

	stream_timer += delta
	if stream_timer < STREAM_CHECK_INTERVAL:
		return
	stream_timer = 0.0

	var next_chunk = screen_to_chunk(player.global_position)
	var next_predicted = _get_predicted_chunk()

	# Actualizamos también cuando cambia el sector pronosticado, no solamente cuando
	# el jugador cruza una frontera. Así los chunks ya existen ANTES de llegar a ellos.
	if next_chunk != current_chunk or next_predicted != predicted_chunk:
		_refresh_stream(false)

func cell_to_screen(cell):
	return Vector2((cell.x - cell.y) * 16.0, (cell.x + cell.y) * 8.0)

func screen_to_cell(screen_pos):
	var a = screen_pos.x / 16.0
	var b = screen_pos.y / 8.0
	return Vector2((a + b) * 0.5, (b - a) * 0.5)

func screen_to_chunk(screen_pos):
	var cell = screen_to_cell(screen_pos)
	return Vector2(
		int(floor(cell.x / float(CHUNK_SIZE))),
		int(floor(cell.y / float(CHUNK_SIZE)))
	)

func _calculate_stream_radii():
	# Un chunk de 12x12 celdas ocupa aproximadamente 384x192 px en proyección iso.
	# Calculamos un radio que cubra la ventana completa más margen fuera de cámara.
	var viewport_size = get_viewport_rect().size
	var chunk_screen_width = float(CHUNK_SIZE) * 32.0
	var chunk_screen_height = float(CHUNK_SIZE) * 16.0

	var radius_x = viewport_size.x / max(1.0, chunk_screen_width * 2.0)
	var radius_y = viewport_size.y / max(1.0, chunk_screen_height * 2.0)
	safe_radius = int(ceil(max(radius_x, radius_y)))
	safe_radius = int(clamp(safe_radius, MIN_SAFE_RADIUS, MAX_SAFE_RADIUS))

	# Histeresis: conservamos una corona extra al descargar. Esto evita que un chunk
	# se destruya y vuelva a crearse al caminar cerca de un borde.
	unload_radius = safe_radius + 1

func _update_motion_prediction():
	var now_pos = player.global_position
	var delta_pos = now_pos - last_player_position
	last_player_position = now_pos

	if delta_pos.length_squared() > 0.04:
		var instant_direction = delta_pos.normalized()
		if movement_direction == Vector2.ZERO:
			movement_direction = instant_direction
		else:
			movement_direction = movement_direction.linear_interpolate(instant_direction, 0.28).normalized()
	else:
		# La predicción desaparece gradualmente cuando el jugador se detiene.
		movement_direction = movement_direction.linear_interpolate(Vector2.ZERO, 0.12)
		if movement_direction.length_squared() < 0.0025:
			movement_direction = Vector2.ZERO

func _get_predicted_chunk():
	if movement_direction == Vector2.ZERO:
		return screen_to_chunk(player.global_position)

	var predicted_position = player.global_position + movement_direction * PREFETCH_DISTANCE
	return screen_to_chunk(predicted_position)

func _refresh_stream(force):
	var next_chunk = screen_to_chunk(player.global_position)
	var next_predicted = _get_predicted_chunk()

	current_chunk = next_chunk
	predicted_chunk = next_predicted

	# 1. Garantía visual: toda el área que potencialmente puede entrar en cámara
	# debe existir inmediatamente. En movimiento normal ya habrá sido precargada.
	_ensure_safe_area(current_chunk, safe_radius)

	# 2. Precarga predictiva. Se pone en cola por anillos, del centro hacia afuera.
	# El área actual también se encola para completar cualquier corona que falte.
	_queue_area_by_rings(current_chunk, safe_radius)
	_queue_area_by_rings(predicted_chunk, safe_radius)

	# 3. Eliminamos solo chunks realmente lejanos. La corona adicional evita parpadeo
	# y reconstrucciones repetidas al cruzar de un sector a otro.
	_unload_far_chunks()

	# 4. Limpiamos de la cola candidatos que ya dejaron de tener sentido.
	_prune_prefetch_queue()

	emit_signal("stream_stats_changed", int(current_chunk.x), int(current_chunk.y), loaded_chunks.size())

func _ensure_safe_area(center, radius):
	for cy in range(int(center.y) - radius, int(center.y) + radius + 1):
		for cx in range(int(center.x) - radius, int(center.x) + radius + 1):
			var coord = Vector2(cx, cy)
			var key = _chunk_key(coord)
			if not loaded_chunks.has(key):
				_remove_pending_key(key)
				_load_chunk(coord)

func _queue_area_by_rings(center, radius):
	# Ring 0, después 1, después 2... así lo más cercano se prepara primero.
	for ring in range(radius + 1):
		for cy in range(int(center.y) - ring, int(center.y) + ring + 1):
			for cx in range(int(center.x) - ring, int(center.x) + ring + 1):
				if max(abs(cx - int(center.x)), abs(cy - int(center.y))) != ring:
					continue
				_queue_chunk(Vector2(cx, cy))

func _queue_chunk(coord):
	var key = _chunk_key(coord)
	if loaded_chunks.has(key) or pending_keys.has(key):
		return

	pending_chunks.append(coord)
	pending_keys[key] = true

func _process_prefetch_queue():
	var built = 0

	while built < PREFETCH_BUILDS_PER_FRAME and pending_chunks.size() > 0:
		var coord = pending_chunks.pop_front()
		var key = _chunk_key(coord)
		pending_keys.erase(key)

		if loaded_chunks.has(key):
			continue
		if not _should_keep_chunk(coord):
			continue

		_load_chunk(coord)
		built += 1

	# El HUD no necesita actualizarse cada frame, solamente cuando realmente cambió
	# la cantidad de chunks después de una construcción diferida.
	if built > 0:
		emit_signal("stream_stats_changed", int(current_chunk.x), int(current_chunk.y), loaded_chunks.size())

func _unload_far_chunks():
	var to_remove = []

	for key in loaded_chunks.keys():
		var chunk = loaded_chunks[key]
		var coord = chunk.chunk_coord

		# Conservamos chunks próximos al jugador O próximos a la zona pronosticada.
		var far_from_player = _chunk_distance(coord, current_chunk) > unload_radius
		var far_from_prediction = _chunk_distance(coord, predicted_chunk) > safe_radius + 1

		if far_from_player and far_from_prediction:
			to_remove.append(key)

	for key in to_remove:
		var chunk = loaded_chunks[key]
		loaded_chunks.erase(key)
		if is_instance_valid(chunk):
			chunk.destroy()

func _prune_prefetch_queue():
	if pending_chunks.empty():
		return

	var filtered = []
	var new_keys = {}

	for coord in pending_chunks:
		var key = _chunk_key(coord)
		if loaded_chunks.has(key):
			continue
		if not _should_keep_chunk(coord):
			continue
		if new_keys.has(key):
			continue

		filtered.append(coord)
		new_keys[key] = true

	pending_chunks = filtered
	pending_keys = new_keys

func _should_keep_chunk(coord):
	if _chunk_distance(coord, current_chunk) <= unload_radius:
		return true
	if _chunk_distance(coord, predicted_chunk) <= safe_radius + 1:
		return true
	return false

func _chunk_distance(a, b):
	# Distancia Chebyshev: adecuada para áreas cuadradas de chunks.
	return max(abs(int(a.x) - int(b.x)), abs(int(a.y) - int(b.y)))

func _remove_pending_key(key):
	# Normalmente solo se usa como respaldo cuando el área segura necesita un chunk
	# que aún estaba esperando en la cola. pending_chunks se depura después.
	pending_keys.erase(key)

func _load_chunk(coord):
	var key = _chunk_key(coord)
	if loaded_chunks.has(key):
		return

	var chunk = WorldChunk.new()
	chunk.name = "Chunk_%d_%d" % [int(coord.x), int(coord.y)]
	chunks_root.add_child(chunk)
	chunk.setup(
		coord,
		CHUNK_SIZE,
		world_ysort,
		terrain_tex,
		trees_tex,
		objects_tex,
		slabs_tex,
		house_tex
	)
	chunk.build()
	loaded_chunks[key] = chunk

func _chunk_key(coord):
	return "%d:%d" % [int(coord.x), int(coord.y)]

func _disable_texture_filtering():
	terrain_tex.flags = 0
	trees_tex.flags = 0
	objects_tex.flags = 0
	slabs_tex.flags = 0
	house_tex.flags = 0
