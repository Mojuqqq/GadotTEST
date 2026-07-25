extends CanvasLayer


@onready var settings_button: Button = (
	$SettingsButton
)

@onready var settings_menu: SettingsMenu = (
	$SettingsMenu
)


func _ready() -> void:
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE
	)

	if not settings_menu.closed.is_connected(
		_on_settings_menu_closed
	):
		settings_menu.closed.connect(
			_on_settings_menu_closed
		)

	settings_button.grab_focus()


func _on_settings_button_pressed() -> void:
	settings_menu.open_menu()


func _on_settings_menu_closed() -> void:
	settings_button.grab_focus()


func _on_new_game_button_pressed() -> void:
	GameManager.start_game()
