extends Node2D

const TrashScene = preload("res://scenes/trash/Trash.tscn")

onready var ground = $Ground
onready var props = $Props
onready var collisions = $Collisions
onready var player = $Props/Player

var terrain_tex = preload("res://assets/farm/Terrain.png")
var trees_tex = preload("res://assets/farm/Trees.png")
var objects_tex = preload("res://assets/farm/Objects.png")
var slabs_tex = preload("res://assets/farm/Wooden Slabs.png")
var house_tex = preload("res://assets/farm/House.png")

func _ready():
	_disable_texture_filtering()
	_build_ground()
	_build_props()
	_build_boundaries()
	_spawn_trash()
	player.position = iso_to_screen(Vector2(9, 9))

func iso_to_screen(cell):
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
	var grass_rect = Rect2(160, 0, 32, 32)  # Terrain: celda 5,0
	var dirt_rect = Rect2(128, 0, 32, 32)   # Terrain: celda 4,0
	var water_rect = Rect2(0, 256, 32, 32)  # Terrain: celda 0,8

	for y in range(18):
		for x in range(18):
			var rect = grass_rect
			# Camino diagonal hacia el edificio.
			if abs(x - y) <= 1 and x < 12:
				rect = dirt_rect
			# Pequeño estanque decorativo.
			if x >= 13 and x <= 16 and y >= 2 and y <= 5:
				rect = water_rect
			var pos = iso_to_screen(Vector2(x, y))
			var tile = _sprite_from_region(terrain_tex, rect, pos, -100)
			ground.add_child(tile)

func _make_anchor(base_pos):
	var anchor = Node2D.new()
	anchor.position = base_pos
	props.add_child(anchor)
	return anchor

func _add_house(cell):
	var base = iso_to_screen(cell)
	var anchor = _make_anchor(base)
	var sprite = Sprite.new()
	sprite.texture = house_tex
	sprite.position = Vector2(0, -73)
	anchor.add_child(sprite)
	_add_static_rect(base + Vector2(0, -5), Vector2(92, 30))

func _add_tree(cell, green = false):
	var base = iso_to_screen(cell)
	var anchor = _make_anchor(base)
	var rect = Rect2(192, 0, 96, 96) if green else Rect2(96, 0, 96, 96)
	var sprite = _sprite_from_region(trees_tex, rect, Vector2(0, -40), 0)
	anchor.add_child(sprite)
	_add_static_rect(base + Vector2(0, -4), Vector2(20, 14))

func _add_bush(cell):
	var base = iso_to_screen(cell)
	var anchor = _make_anchor(base)
	var sprite = _sprite_from_region(objects_tex, Rect2(160, 64, 32, 32), Vector2(0, -8), 0)
	anchor.add_child(sprite)

func _add_stone(cell):
	var base = iso_to_screen(cell)
	var anchor = _make_anchor(base)
	var sprite = _sprite_from_region(objects_tex, Rect2(64, 64, 32, 32), Vector2(0, -7), 0)
	anchor.add_child(sprite)

func _add_wood_slab(cell):
	var base = iso_to_screen(cell)
	var sprite = _sprite_from_region(slabs_tex, Rect2(0, 32, 32, 32), base, -20)
	ground.add_child(sprite)

func _build_props():
	_add_house(Vector2(4, 4))

	_add_tree(Vector2(2, 11), false)
	_add_tree(Vector2(4, 14), true)
	_add_tree(Vector2(12, 13), false)
	_add_tree(Vector2(15, 9), true)
	_add_tree(Vector2(11, 2), false)

	_add_bush(Vector2(5, 12))
	_add_bush(Vector2(13, 11))
	_add_bush(Vector2(8, 15))
	_add_stone(Vector2(12, 6))
	_add_stone(Vector2(14, 7))

	# Pasarela de madera cercana al estanque.
	_add_wood_slab(Vector2(12, 4))
	_add_wood_slab(Vector2(13, 4))
	_add_wood_slab(Vector2(14, 4))
	_add_wood_slab(Vector2(15, 4))

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

func _build_boundaries():
	# Límites simples para el prototipo.
	_add_static_rect(Vector2(0, 10), Vector2(620, 18))
	_add_static_rect(Vector2(0, 305), Vector2(620, 18))
	_add_static_rect(Vector2(-305, 160), Vector2(18, 300))
	_add_static_rect(Vector2(305, 160), Vector2(18, 300))

func _spawn_trash():
	var cells = [
		Vector2(7, 6), Vector2(10, 7), Vector2(12, 10), Vector2(6, 13),
		Vector2(14, 12), Vector2(9, 15), Vector2(15, 7), Vector2(3, 10)
	]
	var types = ["paper", "plastic", "can"]
	GameState.reset(cells.size())

	for i in range(cells.size()):
		var trash = TrashScene.instance()
		trash.position = iso_to_screen(cells[i])
		trash.trash_type = types[i % types.size()]
		props.add_child(trash)


func _disable_texture_filtering():
	terrain_tex.flags = 0
	trees_tex.flags = 0
	objects_tex.flags = 0
	slabs_tex.flags = 0
	house_tex.flags = 0
