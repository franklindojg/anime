extends Area2D

export(String, "paper", "plastic", "can") var trash_type = "paper"
export(String) var trash_id = ""

func _ready():
    connect("body_entered", self, "_on_body_entered")
    update()

func _on_body_entered(body):
    if body is KinematicBody2D:
        GameState.collect_trash(trash_id)
        queue_free()

func _draw():
    # Sprites temporales de basura hasta integrar el pack específico.
    draw_circle(Vector2(0, 5), 7.0, Color(0, 0, 0, 0.15))
    if trash_type == "plastic":
        draw_rect(Rect2(-3, -8, 6, 15), Color("74b9ff"), true)
        draw_rect(Rect2(-2, -11, 4, 3), Color("dfe6e9"), true)
    elif trash_type == "can":
        draw_rect(Rect2(-5, -7, 10, 13), Color("b2bec3"), true)
        draw_line(Vector2(-4, -6), Vector2(4, -6), Color("636e72"), 1.0)
        draw_line(Vector2(-4, 5), Vector2(4, 5), Color("636e72"), 1.0)
    else:
        var paper = PoolVector2Array([
            Vector2(-7, -6), Vector2(5, -8), Vector2(8, 4), Vector2(-4, 7)
        ])
        draw_colored_polygon(paper, Color("f5f6fa"))
        draw_line(Vector2(-4, -2), Vector2(4, -3), Color("b2bec3"), 1.0)
