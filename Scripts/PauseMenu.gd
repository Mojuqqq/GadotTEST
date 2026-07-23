extends CanvasLayer

func _ready():
	visible = false
	# Попробуем найти кнопки по имени и подключить сигналы
	process_mode = PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause():
	visible = !visible
	get_tree().paused = visible

func _on_continue_button_pressed():
	print("Continue pressed")
	toggle_pause()

func _on_replay_button_pressed():
	GameManager.restart_game()

func _on_menu_button_pressed():
	GameManager.return_to_menu()
