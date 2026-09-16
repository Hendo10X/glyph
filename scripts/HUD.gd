extends CanvasLayer
## Minimal, UI-driven HUD that persists across level swaps (it lives under the
## GameManager autoload). Shows level progress, the control legend, and a brief
## flash when the Forced Chaos timer randomizes the player.

var _level_label: Label
var _lives_label: Label
var _coin_label: Label
var _hint_label: Label
var _flash_label: Label
var _flash_t := 0.0
var _lives_pulse := 0.0


func _ready() -> void:
	layer = 10
	_level_label = _make_label(Vector2(24, 18), 22, HORIZONTAL_ALIGNMENT_LEFT)

	# Lives sit directly under the level readout: filled diamonds for what's left,
	# hollow ones for what's gone, so the cost of a hit is visible at a glance.
	_lives_label = _make_label(Vector2(24, 48), 24, HORIZONTAL_ALIGNMENT_LEFT)
	_lives_label.modulate = Color(1, 0.35, 0.45)

	_coin_label = _make_label(Vector2(0, 18), 22, HORIZONTAL_ALIGNMENT_RIGHT)
	_coin_label.anchor_left = 1.0
	_coin_label.anchor_right = 1.0
	_coin_label.offset_left = -180
	_coin_label.offset_right = -24
	_coin_label.modulate = Color(1, 0.85, 0.3)

	_hint_label = _make_label(Vector2(0, 0), 16, HORIZONTAL_ALIGNMENT_CENTER)
	_hint_label.text = "MOVE  A / D     JUMP  SPACE     SHIFT  1 Cube   2 Circle   3 Triangle"
	_hint_label.modulate = Color(1, 1, 1, 0.5)
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_top = -38
	_hint_label.offset_bottom = -14

	_flash_label = _make_label(Vector2(0, 0), 40, HORIZONTAL_ALIGNMENT_CENTER)
	_flash_label.anchor_left = 0.0
	_flash_label.anchor_right = 1.0
	_flash_label.anchor_top = 0.0
	_flash_label.anchor_bottom = 0.0
	_flash_label.offset_top = 90
	_flash_label.offset_bottom = 150
	_flash_label.text = "RANDOMIZED!"
	_flash_label.modulate = Color(1, 0.4, 0.2, 0.0)

	GameManager.level_changed.connect(_on_level_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.game_over.connect(_on_game_over)
	_on_level_changed(GameManager.current_index, GameManager.LEVELS.size())
	_on_coins_changed(GameManager.coins)
	_on_lives_changed(GameManager.lives, GameManager.MAX_LIVES)


func _make_label(pos: Vector2, size_px: int, align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size_px)
	add_child(l)
	return l


func _on_level_changed(index: int, total: int) -> void:
	# Index 0 is the tutorial; numbered levels are 1..total-1.
	if index == 0:
		_level_label.text = "TUTORIAL"
	else:
		_level_label.text = "LEVEL %d / %d" % [index, total - 1]
	# The control legend is teaching text: keep it for the tutorial and Level 1,
	# then get it off the screen.
	_hint_label.visible = index <= 1


func _on_coins_changed(count: int) -> void:
	_coin_label.text = "⬡ %d" % count


func _on_lives_changed(lives: int, max_lives: int) -> void:
	var s := ""
	for i in max_lives:
		s += "◆ " if i < lives else "◇ "
	_lives_label.text = s.strip_edges()
	_lives_pulse = 1.0


func _on_game_over() -> void:
	_flash_label.text = "OUT OF LIVES — BACK TO LEVEL 1"
	_flash_label.modulate = Color(1, 0.25, 0.3, 0.0)
	_flash_t = 1.0


## Call to pop the "RANDOMIZED!" flash (hooked from the player's forced shift).
func flash_randomized() -> void:
	_flash_label.text = "RANDOMIZED!"
	_flash_label.modulate = Color(1, 0.4, 0.2, 0.0)
	_flash_t = 1.0


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t = maxf(0.0, _flash_t - delta * 1.5)
		_flash_label.modulate.a = _flash_t
	# Quick swell on the lives row whenever it changes, so a lost life is felt.
	if _lives_pulse > 0.0:
		_lives_pulse = maxf(0.0, _lives_pulse - delta * 3.0)
		_lives_label.scale = Vector2.ONE * (1.0 + _lives_pulse * 0.25)
