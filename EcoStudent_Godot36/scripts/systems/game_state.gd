extends Node

signal trash_changed(current, total)
signal time_changed(elapsed_seconds)
signal level_complete

var trash_collected = 0
var total_trash = 30
var collected_trash_ids = {}
var objective_completed = false

# Cronómetro de la partida. Empieza en reset() y se detiene exactamente
# cuando se recoge el último residuo del objetivo.
var elapsed_time = 0.0
var timer_running = false
var _last_emitted_second = -1

func _process(delta):
    if not timer_running:
        return

    elapsed_time += delta
    var current_second = int(floor(elapsed_time))
    if current_second != _last_emitted_second:
        _last_emitted_second = current_second
        emit_signal("time_changed", current_second)

func reset(total):
    total_trash = max(1, int(total))
    trash_collected = 0
    collected_trash_ids.clear()
    objective_completed = false

    elapsed_time = 0.0
    timer_running = true
    _last_emitted_second = 0

    emit_signal("trash_changed", trash_collected, total_trash)
    emit_signal("time_changed", 0)

func collect_trash(trash_id = ""):
    if trash_id != "" and collected_trash_ids.has(trash_id):
        return false

    if trash_id != "":
        collected_trash_ids[trash_id] = true

    trash_collected += 1
    emit_signal("trash_changed", trash_collected, total_trash)

    if not objective_completed and trash_collected >= total_trash:
        objective_completed = true
        timer_running = false
        # Emitimos una última vez para congelar en pantalla el tiempo final.
        emit_signal("time_changed", int(floor(elapsed_time)))
        emit_signal("level_complete")

    return true

func is_trash_collected(trash_id):
    return trash_id != "" and collected_trash_ids.has(trash_id)

func get_elapsed_seconds():
    return int(floor(elapsed_time))

func get_formatted_time():
    return format_time(get_elapsed_seconds())

func format_time(total_seconds):
    var seconds = max(0, int(total_seconds))
    var hours = int(seconds / 3600)
    var minutes = int((seconds % 3600) / 60)
    var secs = int(seconds % 60)

    if hours > 0:
        return "%02d:%02d:%02d" % [hours, minutes, secs]
    return "%02d:%02d" % [minutes, secs]
