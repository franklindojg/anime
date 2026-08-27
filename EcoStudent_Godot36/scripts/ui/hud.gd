extends Control

# UI adaptable para Android horizontal. El HUD y el joystick se recolocan dentro
# del área segura real del teléfono para evitar notch/cutout y bordes redondeados.
const SAFE_PADDING = 10.0
const TOP_BAR_HEIGHT = 44.0
const TOP_BAR_MAX_WIDTH = 274.0
const TOP_BAR_MIN_WIDTH = 230.0
const JOYSTICK_MIN_SIZE = 108.0
const JOYSTICK_MAX_SIZE = 132.0

onready var top_bar = $TopBar
onready var trash_value = $TopBar/HBox/TrashGroup/TrashValue
onready var time_value = $TopBar/HBox/TimeGroup/TimeValue
onready var mobile_joystick = $MobileJoystick
onready var complete_overlay = $CompleteOverlay
onready var complete_label = $CompleteOverlay/CenterContainer/VBox/CompleteLabel
onready var time_complete_label = $CompleteOverlay/CenterContainer/VBox/TimeCompleteLabel

func _ready():
    if not GameState.is_connected("trash_changed", self, "_on_trash_changed"):
        GameState.connect("trash_changed", self, "_on_trash_changed")
    if not GameState.is_connected("time_changed", self, "_on_time_changed"):
        GameState.connect("time_changed", self, "_on_time_changed")
    if not GameState.is_connected("level_complete", self, "_on_level_complete"):
        GameState.connect("level_complete", self, "_on_level_complete")

    if not get_viewport().is_connected("size_changed", self, "_apply_mobile_layout"):
        get_viewport().connect("size_changed", self, "_apply_mobile_layout")

    _on_trash_changed(GameState.trash_collected, GameState.total_trash)
    _on_time_changed(GameState.get_elapsed_seconds())
    call_deferred("_apply_mobile_layout")

func _on_trash_changed(current, total):
    trash_value.text = "%d / %d" % [current, total]

func _on_time_changed(elapsed_seconds):
    time_value.text = GameState.format_time(elapsed_seconds)

func _on_level_complete():
    top_bar.visible = false
    mobile_joystick.visible = false
    complete_overlay.visible = true
    complete_label.text = "Felicidades Has Limpiado tu ciudad"
    time_complete_label.text = "Tiempo final: %s" % GameState.get_formatted_time()

func _apply_mobile_layout():
    var viewport_size = get_viewport_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return

    var safe_rect = _get_safe_rect_in_viewport(viewport_size)
    var safe_left = safe_rect.position.x + SAFE_PADDING
    var safe_top = safe_rect.position.y + SAFE_PADDING
    var safe_right = safe_rect.position.x + safe_rect.size.x - SAFE_PADDING
    var safe_bottom = safe_rect.position.y + safe_rect.size.y - SAFE_PADDING

    # Barra compacta centrada arriba, pero siempre contenida dentro del área segura.
    var available_width = max(1.0, safe_right - safe_left)
    var bar_width = min(TOP_BAR_MAX_WIDTH, available_width)
    bar_width = max(min(TOP_BAR_MIN_WIDTH, available_width), bar_width)
    top_bar.rect_size = Vector2(bar_width, TOP_BAR_HEIGHT)

    var centered_x = (viewport_size.x - bar_width) * 0.5
    var min_x = safe_left
    var max_x = max(min_x, safe_right - bar_width)
    top_bar.rect_position = Vector2(clamp(centered_x, min_x, max_x), safe_top)

    # Joystick grande para pulgar. Se escala con la altura disponible pero con
    # límites para que no invada demasiado la pantalla en teléfonos pequeños.
    var joystick_size = clamp(viewport_size.y * 0.34, JOYSTICK_MIN_SIZE, JOYSTICK_MAX_SIZE)
    if mobile_joystick.has_method("set_control_size"):
        mobile_joystick.set_control_size(joystick_size)
    else:
        mobile_joystick.rect_size = Vector2(joystick_size, joystick_size)

    mobile_joystick.rect_position = Vector2(
        safe_left + 4.0,
        safe_bottom - joystick_size - 4.0
    )

    # El mensaje de victoria ocupa el centro; le damos márgenes equivalentes al
    # área segura para que tampoco choque con un notch en horizontal.
    var center = $CompleteOverlay/CenterContainer
    center.margin_left = safe_rect.position.x + 14.0
    center.margin_top = safe_rect.position.y + 14.0
    center.margin_right = -(viewport_size.x - (safe_rect.position.x + safe_rect.size.x) + 14.0)
    center.margin_bottom = -(viewport_size.y - (safe_rect.position.y + safe_rect.size.y) + 14.0)

func _get_safe_rect_in_viewport(viewport_size):
    # OS.get_window_safe_area() usa píxeles físicos en Android. Con Stretch 2D
    # debemos convertir esos valores a coordenadas del viewport lógico.
    var safe_pixels = OS.get_window_safe_area()
    var window_size = OS.window_size

    if safe_pixels.size.x <= 0.0 or safe_pixels.size.y <= 0.0:
        return Rect2(Vector2.ZERO, viewport_size)
    if window_size.x <= 0.0 or window_size.y <= 0.0:
        return Rect2(Vector2.ZERO, viewport_size)

    var scale = Vector2(
        viewport_size.x / window_size.x,
        viewport_size.y / window_size.y
    )

    var safe_position = Vector2(
        safe_pixels.position.x * scale.x,
        safe_pixels.position.y * scale.y
    )
    var safe_size = Vector2(
        safe_pixels.size.x * scale.x,
        safe_pixels.size.y * scale.y
    )

    # En escritorio algunos sistemas pueden devolver datos no útiles. Si el área
    # resultante queda fuera del viewport usamos toda la pantalla como fallback.
    if safe_size.x <= 1.0 or safe_size.y <= 1.0:
        return Rect2(Vector2.ZERO, viewport_size)

    safe_position.x = clamp(safe_position.x, 0.0, viewport_size.x)
    safe_position.y = clamp(safe_position.y, 0.0, viewport_size.y)
    safe_size.x = min(safe_size.x, viewport_size.x - safe_position.x)
    safe_size.y = min(safe_size.y, viewport_size.y - safe_position.y)

    return Rect2(safe_position, safe_size)
