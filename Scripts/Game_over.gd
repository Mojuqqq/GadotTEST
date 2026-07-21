extends CanvasLayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = PROCESS_MODE_ALWAYS

func _on_restart_button_pressed():
	get_tree().paused = false
	GameManager.reset_game_state()
	get_tree().reload_current_scene()

func _on_menu_button_pressed():
	get_tree().paused = false
	GameManager.reset_game_state()
	get_tree().change_scene_to_file("res://Scenes/Main_menu.tscn")
