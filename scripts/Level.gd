extends Node2D
## Level root. Registers its SpawnPoint with the GameManager so respawns and the
## initial placement land in the right spot. The Player is instanced as a child
## at (or near) the spawn marker.

@onready var _spawn: Marker2D = $SpawnPoint


func _ready() -> void:
	# Player is a child, so its _ready (register_player) has already run by now.
	GameManager.set_spawn(_spawn.global_position)
