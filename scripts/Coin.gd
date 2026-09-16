extends Area2D
## Optional collectible. Bobs gently, and on pickup bumps the run tally, pops a
## quick scale flourish, then frees itself. Coins are score/route incentives —
## never required to finish a level.

@onready var _vis: Node2D = $Vis
var _taken := false
var _t := 0.0
var _home_y := 0.0


func _ready() -> void:
	_home_y = _vis.position.y
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	# Idle bob + slow spin so coins read as "alive" and grab attention.
	_t += delta
	if not _taken:
		_vis.position.y = _home_y + sin(_t * 3.0) * 3.0
		_vis.rotation = sin(_t * 2.0) * 0.5


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	set_deferred("monitoring", false)
	GameManager.collect_coin()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_vis, "scale", Vector2(2.2, 2.2), 0.18)
	tw.tween_property(_vis, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
