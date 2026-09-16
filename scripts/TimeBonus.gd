extends Area2D
## Power-up that tops up the Forced Chaos timer, buying the player time to hold an
## awkward shape through a puzzle (e.g. standing as the heavy Cube on a plate).

@export var amount := 20.0

@onready var _vis: Node2D = $Vis
var _taken := false
var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if not _taken:
		_vis.rotation = _t * 1.6
		_vis.scale = Vector2.ONE * (1.0 + sin(_t * 4.0) * 0.08)


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player") or not body.has_method("extend_chaos"):
		return
	_taken = true
	set_deferred("monitoring", false)
	body.extend_chaos(amount)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_vis, "scale", Vector2(2.6, 2.6), 0.22)
	tw.tween_property(_vis, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)
