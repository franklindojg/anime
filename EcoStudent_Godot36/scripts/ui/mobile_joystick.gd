extends Control

# Joystick táctil para Android. También acepta mouse para probarlo desde Godot.
export(float) var radius = 48.0
export(float) var knob_radius = 21.0
export(float, 0.0, 0.9) var deadzone = 0.15
export(bool) var show_on_desktop = true

var direction = Vector2.ZERO
var _touch_index = -1
var _mouse_active = false
var _knob_offset = Vector2.ZERO

func _ready():
    add_to_group("mobile_joystick")
    if not show_on_desktop and OS.get_name() != "Android" and OS.get_name() != "iOS":
        visible = false
    update()

func set_control_size(control_size):
    var size = max(80.0, float(control_size))
    rect_size = Vector2(size, size)
    radius = size * 0.39
    knob_radius = size * 0.17

    if _knob_offset.length() > radius:
        _knob_offset = _knob_offset.normalized() * radius
    update()

func get_direction():
    return direction

func reset():
    direction = Vector2.ZERO
    _knob_offset = Vector2.ZERO
    _touch_index = -1
    _mouse_active = false
    update()

func _gui_input(event):
    if event is InputEventScreenTouch:
        if event.pressed and _touch_index == -1:
            _touch_index = event.index
            _set_from_local_position(event.position)
            accept_event()
        elif not event.pressed and event.index == _touch_index:
            reset()
            accept_event()
        return

    if event is InputEventScreenDrag and event.index == _touch_index:
        _set_from_local_position(event.position)
        accept_event()
        return

    if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
        _mouse_active = event.pressed
        if _mouse_active:
            _set_from_local_position(event.position)
        else:
            reset()
        accept_event()
        return

    if event is InputEventMouseMotion and _mouse_active:
        _set_from_local_position(event.position)
        accept_event()

func _set_from_local_position(local_pos):
    var center = rect_size * 0.5
    var offset = local_pos - center
    var length = offset.length()

    if length > radius:
        offset = offset.normalized() * radius

    _knob_offset = offset

    var normalized = offset / max(radius, 1.0)
    if normalized.length() < deadzone:
        direction = Vector2.ZERO
    else:
        direction = normalized

    update()

func _draw():
    var center = rect_size * 0.5
    draw_circle(center, radius + 5.0, Color(0.02, 0.04, 0.05, 0.30))
    draw_circle(center, radius, Color(0.12, 0.18, 0.18, 0.42))
    draw_arc(center, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.28), 2.0, true)

    var knob_center = center + _knob_offset
    draw_circle(knob_center, knob_radius + 3.0, Color(0, 0, 0, 0.24))
    draw_circle(knob_center, knob_radius, Color(0.88, 0.94, 0.92, 0.72))
