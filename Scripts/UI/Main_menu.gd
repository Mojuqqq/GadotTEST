extends CanvasLayer

func _ready():
	# Показываем курсор (если скрыт)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_settings_button_pressed() -> void:
	pass # Replace with function body.


func _on_new_game_button_pressed() -> void:
	GameManager.start_game()
