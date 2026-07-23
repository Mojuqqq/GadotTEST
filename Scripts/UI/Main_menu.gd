extends CanvasLayer

func _ready():
	# Показываем курсор (если скрыт)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_quit_button_pressed():
	get_tree().quit()

func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")
