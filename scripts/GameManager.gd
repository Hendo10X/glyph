extends Node
## Project G.L.Y.P.H. — GameManager autoload (singleton).
##
## Owns the menu↔level flow, level progression, the respawn point, and the coin
## tally. Levels are plain PackedScenes listed in LEVELS; winning advances to the
## next and seamlessly swaps the scene. Death is zero-penalty: the player snaps
## back to the current level's SpawnPoint with momentum cleared — no reload.

signal level_changed(index: int, total: int)
signal player_died
signal game_completed
signal coins_changed(count: int)
signal lives_changed(lives: int, max_lives: int)
signal game_over

const MENU_SCENE := "res://scenes/StartMenu.tscn"

## Ordered scenes. Index 0 is the tutorial; 1..20 are the numbered levels.
const LEVELS: PackedStringArray = [
	"res://scenes/levels/Tutorial.tscn",
	"res://scenes/levels/Level01.tscn",
	"res://scenes/levels/Level02.tscn",
	"res://scenes/levels/Level03.tscn",
	"res://scenes/levels/Level04.tscn",
	"res://scenes/levels/Level05.tscn",
	"res://scenes/levels/Level06.tscn",
	"res://scenes/levels/Level07.tscn",
	"res://scenes/levels/Level08.tscn",
	"res://scenes/levels/Level09.tscn",
	"res://scenes/levels/Level10.tscn",
	"res://scenes/levels/Level11.tscn",
	"res://scenes/levels/Level12.tscn",
	"res://scenes/levels/Level13.tscn",
	"res://scenes/levels/Level14.tscn",
	"res://scenes/levels/Level15.tscn",
	"res://scenes/levels/Level16.tscn",
	"res://scenes/levels/Level17.tscn",
	"res://scenes/levels/Level18.tscn",
	"res://scenes/levels/Level19.tscn",
	"res://scenes/levels/Level20.tscn",
]

## Lives. A hit costs one and snaps the player back to the level's spawn point;
## running out sends the whole run back to Level 1. Lives refill on every level
## load, so the level itself is the checkpoint.
const MAX_LIVES := 3
## Grace period after a hit. Without it a single spike field or a death plane the
## player is still overlapping would eat all three lives in consecutive frames.
const INVULN_TIME := 1.4

var current_index := 0
var coins := 0
var lives := MAX_LIVES
var _player: Node = null
var _spawn_point := Vector2.ZERO
var _hud: CanvasLayer = null
var _invuln := 0.0


func _ready() -> void:
	# A persistent HUD lives under this autoload, so it survives scene swaps.
	_hud = preload("res://scripts/HUD.gd").new()
	add_child(_hud)
	_hud.visible = false  # hidden on the menu; shown once a level loads


func _process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln = maxf(0.0, _invuln - delta)


## True while the player is in post-hit grace. The Player reads this to flash.
func is_invulnerable() -> bool:
	return _invuln > 0.0


## Start a fresh run from the menu.
func start_game() -> void:
	current_index = 0
	coins = 0
	lives = MAX_LIVES
	_invuln = 0.0
	coins_changed.emit(coins)
	lives_changed.emit(lives, MAX_LIVES)
	_change_to(LEVELS[0])


func go_to_menu() -> void:
	_hud.visible = false
	_change_to(MENU_SCENE)


## Pop the on-screen "RANDOMIZED!" flash when the Chaos timer forces a shift.
func notify_randomized() -> void:
	if is_instance_valid(_hud):
		_hud.flash_randomized()


func collect_coin() -> void:
	coins += 1
	coins_changed.emit(coins)


## The active level registers its spawn marker here on load. Also re-homes the
## player immediately so the first frame starts on the spawn point.
func set_spawn(pos: Vector2) -> void:
	_spawn_point = pos
	# Every level load is a checkpoint: lives come back full.
	lives = MAX_LIVES
	_invuln = 0.0
	lives_changed.emit(lives, MAX_LIVES)
	if is_instance_valid(_player):
		_player.reset_to(pos)
	if is_instance_valid(_hud):
		_hud.visible = true
	level_changed.emit(current_index, LEVELS.size())


## The player announces itself on _ready so hazards/goals can find it indirectly.
func register_player(p: Node) -> void:
	_player = p


## Take a hit: costs a life and snaps back to spawn with momentum cleared. Hits
## during the grace window are ignored, so one spike field can't drain every life.
## Losing the last life restarts the run from Level 1.
func respawn() -> void:
	if _invuln > 0.0:
		return
	_invuln = INVULN_TIME

	lives -= 1
	lives_changed.emit(lives, MAX_LIVES)
	player_died.emit()

	if lives <= 0:
		game_over.emit()
		# Back to Level 1 — or restart the tutorial if that's where we were.
		go_to(0 if current_index == 0 else 1)
		return

	if is_instance_valid(_player):
		_player.reset_to(_spawn_point)


## Win: advance to the next level and swap the scene. After the last level the
## run completes and returns to the menu.
func win_level() -> void:
	current_index += 1
	if current_index >= LEVELS.size():
		game_completed.emit()
		current_index = 0
		go_to_menu()
		return
	_change_to(LEVELS[current_index])


## Jump straight to a level index (debug / level select).
func go_to(index: int) -> void:
	current_index = clampi(index, 0, LEVELS.size() - 1)
	_change_to(LEVELS[current_index])


func _change_to(path: String) -> void:
	# Deferred: never swap the scene tree from inside a physics/signal callback.
	get_tree().call_deferred("change_scene_to_file", path)
