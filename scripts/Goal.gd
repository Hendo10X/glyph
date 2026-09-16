extends Area2D
## The win zone. First player body to enter completes the level. A guard flag
## stops a fast body from firing win_level twice before the scene swaps.

var _claimed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _claimed:
		return
	if body.is_in_group("player"):
		_claimed = true
		GameManager.win_level()
