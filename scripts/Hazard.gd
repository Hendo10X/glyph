extends Area2D
## A death zone. Any body entering triggers an instant, frictionless respawn.
## Put these below pits, on spikes, or as out-of-bounds floors.


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		GameManager.respawn()
