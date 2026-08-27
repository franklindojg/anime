extends KinematicBody2D

signal character_changed(character_name)

export var speed = 115.0
export(String, "female", "male") var character = "female"

const FRAME_W = 48
const FRAME_H = 48
const FRAMES_PER_ANIMATION = 4

# El spritesheet viene en 8 filas, una dirección por fila.
# 0 izquierda, 1 derecha, 2 abajo, 3 arriba,
# 4 abajo-izquierda, 5 abajo-derecha,
# 6 arriba-izquierda, 7 arriba-derecha.
const DIRECTION_ROWS = {
    "left": 0,
    "right": 1,
    "down": 2,
    "up": 3,
    "down_left": 4,
    "down_right": 5,
    "up_left": 6,
    "up_right": 7
}

var female_idle = preload("res://assets/characters/female_idle.png")
var female_walk = preload("res://assets/characters/female_walk.png")
var male_idle = preload("res://assets/characters/male_idle.png")
var male_walk = preload("res://assets/characters/male_walk.png")

onready var animated_sprite = $AnimatedSprite

var facing_name = "down"
var moving = false
var _female_frames = null
var _male_frames = null
var _mobile_joystick = null

func _ready():
    _disable_texture_filtering()
    _female_frames = _build_sprite_frames(female_idle, female_walk)
    _male_frames = _build_sprite_frames(male_idle, male_walk)
    set_character(character)
    _play_current_animation()
    update()

func _physics_process(_delta):
    var direction = Vector2.ZERO

    if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
        direction.x -= 1.0
    if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
        direction.x += 1.0
    if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
        direction.y -= 1.0
    if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
        direction.y += 1.0

    # En Android el joystick táctil usa la misma lógica de movimiento y conserva
    # las 8 direcciones del spritesheet. Teclado/WASD siguen funcionando en PC.
    var mobile_direction = _get_mobile_direction()
    if mobile_direction.length() > 0.0:
        direction = mobile_direction

    moving = direction.length() > 0.0

    if moving:
        facing_name = _direction_to_name(direction)
        direction = direction.normalized()
        move_and_slide(direction * speed)

    _play_current_animation()

func _get_mobile_direction():
    if not is_instance_valid(_mobile_joystick):
        var joysticks = get_tree().get_nodes_in_group("mobile_joystick")
        if joysticks.size() > 0:
            _mobile_joystick = joysticks[0]

    if is_instance_valid(_mobile_joystick) and _mobile_joystick.has_method("get_direction"):
        return _mobile_joystick.get_direction()

    return Vector2.ZERO

func _unhandled_input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        if event.scancode == KEY_1:
            set_character("female")
        elif event.scancode == KEY_2:
            set_character("male")

func set_character(value):
    character = value if value == "male" else "female"
    if animated_sprite == null:
        return

    if character == "male":
        animated_sprite.frames = _male_frames
        emit_signal("character_changed", "Niño")
    else:
        animated_sprite.frames = _female_frames
        emit_signal("character_changed", "Niña")

    _play_current_animation(true)

func _play_current_animation(force_restart = false):
    if animated_sprite == null or animated_sprite.frames == null:
        return

    var prefix = "walk" if moving else "idle"
    var animation_name = prefix + "_" + facing_name

    if force_restart or animated_sprite.animation != animation_name:
        animated_sprite.play(animation_name)

func _direction_to_name(direction):
    var sx = int(sign(direction.x))
    var sy = int(sign(direction.y))

    if sx < 0 and sy < 0:
        return "up_left"
    if sx > 0 and sy < 0:
        return "up_right"
    if sx < 0 and sy > 0:
        return "down_left"
    if sx > 0 and sy > 0:
        return "down_right"
    if sx < 0:
        return "left"
    if sx > 0:
        return "right"
    if sy < 0:
        return "up"
    return "down"

func _build_sprite_frames(idle_texture, walk_texture):
    var frames = SpriteFrames.new()
    frames.remove_animation("default")

    var direction_names = [
        "left", "right", "down", "up",
        "down_left", "down_right", "up_left", "up_right"
    ]

    for direction_name in direction_names:
        var row = DIRECTION_ROWS[direction_name]
        _add_animation(frames, "idle_" + direction_name, idle_texture, row, 4.0)
        _add_animation(frames, "walk_" + direction_name, walk_texture, row, 8.0)

    return frames

func _add_animation(frames, animation_name, texture, row, fps):
    frames.add_animation(animation_name)
    frames.set_animation_loop(animation_name, true)
    frames.set_animation_speed(animation_name, fps)

    for column in range(FRAMES_PER_ANIMATION):
        var atlas = AtlasTexture.new()
        atlas.atlas = texture
        atlas.region = Rect2(column * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
        frames.add_frame(animation_name, atlas)

func _disable_texture_filtering():
    # Pixel art nítido en Godot 3.x.
    female_idle.flags = 0
    female_walk.flags = 0
    male_idle.flags = 0
    male_walk.flags = 0

func _draw():
    # Sombra debajo de los pies. El sprite real se dibuja como hijo.
    var points = PoolVector2Array()
    var steps = 20
    for i in range(steps):
        var angle = TAU * float(i) / float(steps)
        points.append(Vector2(cos(angle) * 10.0, sin(angle) * 4.0))
    draw_colored_polygon(points, Color(0, 0, 0, 0.18))
