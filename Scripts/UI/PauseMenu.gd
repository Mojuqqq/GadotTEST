extends CanvasLayer

@onready var next_floor_button: Button = ($NextFloorButton)
@onready var next_floor_dialog: ConfirmationDialog = ($NextFloorDialog)
@onready var exit_run_dialog: ConfirmationDialog = (%ExitRunDialog)

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



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


func toggle_pause() -> void:
	visible = not visible
	get_tree().paused = visible

	if visible:
		_refresh_next_floor_button()


func _on_continue_button_pressed() -> void:
	toggle_pause()


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
	visible = false
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
	visible = false
	get_tree().paused = false

	if exit_will_save_gold:
		GameManager.finish_run_and_return_to_menu()
	else:
		GameManager.abandon_run_and_return_to_menu()
