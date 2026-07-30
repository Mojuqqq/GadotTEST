extends CanvasLayer

@onready var continue_button: Button = ($ContinueButton)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE
	)
	_refresh_continue_button()

func _on_continue_button_pressed() -> void:
	GameManager.resume_after_floor_victory()
	queue_free()

func _refresh_continue_button() -> void:
	var can_stay: bool = (
		GameManager.can_stay_on_completed_floor()
	)

	continue_button.disabled = not can_stay

	if can_stay:
		continue_button.tooltip_text = (
			"Вернуться на завершённый этаж"
		)
	else:
		continue_button.tooltip_text = (
			"Все сундуки собраны "
			+ "и все товары куплены"
		)

func _on_next_floor_button_pressed() -> void:
	GameManager.go_to_next_floor()


func _on_menu_button_pressed() -> void:
	GameManager.finish_run_and_return_to_menu()
