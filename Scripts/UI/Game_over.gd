extends CanvasLayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = PROCESS_MODE_ALWAYS

func _on_restart_button_pressed():
	GameManager.restart_game()

func _on_menu_button_pressed():
	GameManager.return_to_menu()
