extends CanvasLayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = PROCESS_MODE_ALWAYS

func _on_menu_button_pressed():
	GameManager.return_to_menu()

func _on_button_pressed() -> void:
	GameManager.restart_game()
