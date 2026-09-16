extends Control
## Title / how-to-play screen. Start with the button, Space/Enter, or a shift key.

@onready var _start_btn: Button = $Center/VBox/Buttons/StartButton
@onready var _quit_btn: Button = $Center/VBox/Buttons/QuitButton


func _ready() -> void:
	_start_btn.pressed.connect(_start)
	_quit_btn.pressed.connect(func(): get_tree().quit())
	_start_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		_start()


func _start() -> void:
	GameManager.start_game()
