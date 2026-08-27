extends Node

# Música ambiental: reproduce la canción completa, espera 5 segundos
# y vuelve a iniciarla. El archivo de audio no se incluye en este parche.
const MUSIC_PATH = "res://assets/music/Morning_High_Score.mp3"

onready var music_player = $MusicPlayer
onready var restart_delay = $RestartDelay

func _ready():
    if not ResourceLoader.exists(MUSIC_PATH):
        push_error("No se encontró la música: " + MUSIC_PATH)
        return

    music_player.stream = load(MUSIC_PATH)
    _play_music()

func _play_music():
    if music_player.stream == null:
        return
    restart_delay.stop()
    music_player.play(0.0)

func _on_music_finished():
    # Cuando termina naturalmente, dejamos 5 segundos de silencio.
    if restart_delay.is_stopped():
        restart_delay.start(5.0)

func _on_restart_delay_timeout():
    _play_music()
