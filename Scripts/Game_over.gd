extends CanvasLayer

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_button_pressed() -> void:
	get_tree().reload_current_scene()  # перезапускает текущую игровую сцену


func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main_menu.tscn")
