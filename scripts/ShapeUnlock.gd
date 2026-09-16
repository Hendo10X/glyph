extends Area2D
## Power-up that grants a locked shape. Levels can start with a shape locked and
## hide its unlock behind a detour, forcing the player to fetch it before they can
## solve a section that needs that form.

enum { CUBE, CIRCLE, TRIANGLE }

@export var shape := CUBE

const COLORS := {
	CUBE: Color(0.2, 0.5, 1.0),
	CIRCLE: Color(1.0, 0.2, 0.7),
	TRIANGLE: Color(1.0, 0.85, 0.2),
}

@onready var _vis: Node2D = $Vis
@onready var _halo: Polygon2D = $Vis/Halo
var _taken := false
var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var col: Color = COLORS[shape]
	_halo.color = Color(col.r, col.g, col.b, 0.18)
	$Vis/IconCube.visible = shape == CUBE
	$Vis/IconCircle.visible = shape == CIRCLE
	$Vis/IconTriangle.visible = shape == TRIANGLE
	for n in [$Vis/IconCube, $Vis/IconCircle, $Vis/IconTriangle]:
		n.color = col


func _process(delta: float) -> void:
	_t += delta
	if not _taken:
		_halo.rotation = _t * 1.2
		_vis.scale = Vector2.ONE * (1.0 + sin(_t * 4.0) * 0.08)


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player") or not body.has_method("unlock_shape"):
		return
	_taken = true
	set_deferred("monitoring", false)
	body.unlock_shape(shape)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_vis, "scale", Vector2(2.6, 2.6), 0.22)
	tw.tween_property(_vis, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)
