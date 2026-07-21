extends CanvasLayer

func _ready():
	visible = false
	# Попробуем найти кнопки по имени и подключить сигналы
	process_mode = PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause():
	visible = !visible
	get_tree().paused = visible

func _on_continue_button_pressed():
	print("Continue pressed")
	toggle_pause()

func _on_replay_button_pressed():
	get_tree().paused = false
	GameManager.reset_game_state()
	get_tree().reload_current_scene()

func _on_menu_button_pressed():
	get_tree().paused = false
	GameManager.reset_game_state()
	get_tree().change_scene_to_file("res://Scenes/Main_menu.tscn")
