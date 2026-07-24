extends CanvasLayer

@onready var losses_label: Label = %LossesLabel

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	process_mode = PROCESS_MODE_ALWAYS
	_refresh_losses()

func _on_restart_button_pressed():
	GameManager.restart_game()

func _on_menu_button_pressed():
	GameManager.return_to_menu()

func _refresh_losses() -> void:
	if not is_instance_valid(losses_label):
		return

	var lost_gold: int = GameManager.last_lost_gold
	var lost_keys: int = GameManager.last_lost_keys
	var saved_gold: int = GameManager.banked_gold

	losses_label.text = (
		"Потеряно за этот забег:\n"
		+ "Золото: "
		+ str(lost_gold)
		+ "\n"
		+ "Ключи: "
		+ str(lost_keys)
		+ "\n\n"
		+ "Ранее сохранённое золото осталось: "
		+ str(saved_gold)
	)
