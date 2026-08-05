extends CanvasLayer

@onready var next_floor_button: Button = ($NextFloorButton)
@onready var next_floor_dialog: ConfirmationDialog = ($NextFloorDialog)
@onready var exit_run_dialog: ConfirmationDialog = (%ExitRunDialog)
@onready var close_button: TextureButton = ($CloseButton)
@onready var outside_tap_area: Control = ($black_bg)
@onready var settings_button: Button = ($SettingsButton)
@onready var settings_menu: SettingsMenu = ($SettingsMenu)

var exit_will_save_gold: bool = false

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not GameManager.floor_completed_changed.is_connected(
		_on_floor_completed_changed
	):
		GameManager.floor_completed_changed.connect(
			_on_floor_completed_changed
		)

	_refresh_next_floor_button()
	
	exit_run_dialog.process_mode = (
	Node.PROCESS_MODE_ALWAYS
	)

	if not exit_run_dialog.confirmed.is_connected(
		_on_exit_run_confirmed
	):
		exit_run_dialog.confirmed.connect(
			_on_exit_run_confirmed
		)

	if not close_button.pressed.is_connected(
		_on_close_button_pressed
	):
		close_button.pressed.connect(
			_on_close_button_pressed
		)
	
	if not outside_tap_area.gui_input.is_connected(
		_on_outside_tap_area_gui_input
	):
		outside_tap_area.gui_input.connect(
			_on_outside_tap_area_gui_input
		)
		
	if not settings_button.pressed.is_connected(
		_on_settings_button_pressed
	):
		settings_button.pressed.connect(
			_on_settings_button_pressed
		)

	if not settings_menu.closed.is_connected(
		_on_settings_menu_closed
	):
		settings_menu.closed.connect(
			_on_settings_menu_closed
		)


func _input(
	event: InputEvent
) -> void:
	if not event.is_action_pressed(
		"pause"
	):
		return

	# Удерживание ESC не должно несколько раз
	# открывать и закрывать меню.
	if (
		event is InputEventKey
		and event.echo
	):
		return

	# Пока открыт дебаг, ESC принадлежит ему.
	# PauseMenu не должен реагировать на то же нажатие.
	var debug_menu: Node = (
		get_tree().get_first_node_in_group(
			&"DebugMenu"
		)
	)

	if is_instance_valid(debug_menu):
		get_viewport().set_input_as_handled()
		return

	# Магазин имеет приоритет над паузой.
	# ESC закрывает магазин и не открывает PauseMenu.
	var shop_menu: Node = (
		get_tree().get_first_node_in_group(
			"ShopMenu"
		)
	)

	if is_instance_valid(
		shop_menu
	):
		get_viewport().set_input_as_handled()

		if shop_menu.has_method(
			"close_menu"
		):
			shop_menu.call(
				"close_menu"
			)
		else:
			shop_menu.queue_free()

		return

	# Инвентарь имеет приоритет над паузой.
	# При ESC закрываем его и не открываем PauseMenu.
	var inventory_menu: Node = (
		get_tree().get_first_node_in_group(
			"InventoryMenu"
		)
	)

	if is_instance_valid(
		inventory_menu
	):
		get_viewport().set_input_as_handled()

		if inventory_menu.has_method(
			"close_menu"
		):
			inventory_menu.call(
				"close_menu"
			)
		else:
			inventory_menu.queue_free()

		return

	# На экранах победы и поражения ESC
	# не должен открывать меню паузы
	# и снимать игру с паузы.
	if (
		GameManager.state
		!= GameManager.GameState.PLAYING
	):
		get_viewport().set_input_as_handled()
		return

	get_viewport().set_input_as_handled()

	# ESC закрывает только верхнее открытое окно,
	# а не всё меню паузы сразу.
	if next_floor_dialog.visible:
		next_floor_dialog.hide()
		return

	if exit_run_dialog.visible:
		exit_run_dialog.hide()
		return

	if settings_menu.is_menu_open():
		settings_menu.close_menu()
		return

	toggle_pause()


func toggle_pause() -> void:
	_set_pause_state(
		not visible
	)


func _set_pause_state(
	paused: bool
) -> void:
	var state_changed: bool = (
		visible != paused
	)

	visible = paused
	get_tree().paused = paused

	if not state_changed:
		return

	if paused:
		AudioManager.play_pause()
		_refresh_next_floor_button()
	else:
		AudioManager.play_resume()


func _on_continue_button_pressed() -> void:
	close_pause_menu()


func _on_next_floor_button_pressed() -> void:
	if not GameManager.floor_completed:
		return

	var key_count: int = GameManager.keys

	if key_count > 0:
		next_floor_dialog.dialog_text = (
			"При переходе на следующий этаж "
			+ "будет потеряно ключей: "
			+ str(key_count)
			+ ".\n\n"
			+ "Золото и усиления текущего забега "
			+ "сохранятся.\n\n"
			+ "Перейти на следующий этаж?"
		)
	else:
		next_floor_dialog.dialog_text = (
			"Перейти на следующий этаж?\n\n"
			+ "Золото и усиления текущего забега "
			+ "сохранятся."
		)

	next_floor_dialog.popup_centered()


func _on_next_floor_confirmed() -> void:
	_set_pause_state(false)
	GameManager.go_to_next_floor()


func _on_floor_completed_changed(
	completed: bool
) -> void:
	next_floor_button.disabled = not completed


func _refresh_next_floor_button() -> void:
	next_floor_button.disabled = (
		not GameManager.floor_completed
	)

	if GameManager.floor_completed:
		next_floor_button.tooltip_text = (
			"Начать следующий этаж"
		)
	else:
		next_floor_button.tooltip_text = (
			"Сначала победите босса"
		)


func _on_menu_button_pressed() -> void:
	var run_gold: int = GameManager.run_gold
	var key_count: int = GameManager.keys

	exit_will_save_gold = (
		GameManager.floor_completed
	)

	if exit_will_save_gold:
		exit_run_dialog.dialog_text = (
			"Забег завершён.\n\n"
			+ "Золото текущего забега будет сохранено: "
			+ str(run_gold)
			+ ".\n"
			+ "Ключи будут потеряны: "
			+ str(key_count)
			+ ".\n\n"
			+ "Выйти в главное меню?"
		)
	else:
		exit_run_dialog.dialog_text = (
			"Забег ещё не завершён.\n\n"
			+ "Будет потеряно золота: "
			+ str(run_gold)
			+ ".\n"
			+ "Будет потеряно ключей: "
			+ str(key_count)
			+ ".\n\n"
			+ "Ранее сохранённое золото не пострадает.\n\n"
			+ "Прервать забег и выйти?"
		)

	exit_run_dialog.popup_centered()

func _on_exit_run_confirmed() -> void:
	_set_pause_state(false)

	if exit_will_save_gold:
		GameManager.finish_run_and_return_to_menu()
	else:
		GameManager.abandon_run_and_return_to_menu()
		
func _on_settings_button_pressed() -> void:
	get_viewport().gui_release_focus()
	settings_menu.open_menu()


func _on_settings_menu_closed() -> void:
	get_viewport().gui_release_focus()

func close_pause_menu() -> void:
	if settings_menu.is_menu_open():
		settings_menu.close_menu()
		return

	_set_pause_state(false)
	
func _on_close_button_pressed() -> void:
	close_pause_menu()

func _on_outside_tap_area_gui_input(
	event: InputEvent
) -> void:
	if event is InputEventMouseButton:
		var mouse_event := (
			event as InputEventMouseButton
		)

		if (
			mouse_event.button_index
			== MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			outside_tap_area.accept_event()
			close_pause_menu()

		return

	if event is InputEventScreenTouch:
		var touch_event := (
			event as InputEventScreenTouch
		)

		if touch_event.pressed:
			outside_tap_area.accept_event()
			close_pause_menu()
