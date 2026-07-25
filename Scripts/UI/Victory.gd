extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE
	)


func _on_continue_button_pressed() -> void:
	GameManager.resume_after_floor_victory()
	queue_free()


func _on_next_floor_button_pressed() -> void:
	GameManager.go_to_next_floor()


func _on_menu_button_pressed() -> void:
	GameManager.finish_run_and_return_to_menu()
