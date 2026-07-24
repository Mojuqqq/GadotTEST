extends Node


signal game_over(victory: bool)


enum GameState {MENU,PLAYING,GAME_OVER,VICTORY}

const MAIN_SCENE_PATH := "res://Scenes/Core/Main.tscn"
const MENU_SCENE_PATH := "res://Scenes/UI/Main_menu.tscn"
const VICTORY_SCENE_PATH := "res://Scenes/UI/Victory.tscn"
const GAME_OVER_SCENE_PATH := "res://Scenes/UI/Game_over.tscn"


var state: int = GameState.MENU
var game_over_started: bool = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS


# =========================================================
# ЗАПУСК ИГРЫ
# =========================================================

func start_game(reset_callback: Callable):
	_call_reset(reset_callback)

	game_over_started = false
	state = GameState.PLAYING

	get_tree().paused = false

	call_deferred("_change_scene",MAIN_SCENE_PATH)


# =========================================================
# ПОБЕДА И ПОРАЖЕНИЕ
# =========================================================

func trigger_game_over (victory: bool, player: Node2D):
	if game_over_started:
		return

	game_over_started = true

	if victory:
		state = GameState.VICTORY
	else:
		state = GameState.GAME_OVER

	# При поражении вызываем смерть игрока.
	# При победе игрока убивать не нужно.
	if not victory:
		_kill_player(player)

	var overlay_path := (
		VICTORY_SCENE_PATH
		if victory
		else GAME_OVER_SCENE_PATH
	)

	var overlay_scene := load(overlay_path) as PackedScene

	if overlay_scene == null:
		push_error("Не удалось загрузить финальную сцену: " + overlay_path)

		game_over_started = false
		return

	var current_scene := get_tree().current_scene

	if current_scene == null:
		push_error("Нельзя показать финальный экран: "+ "текущая сцена отсутствует.")

		game_over_started = false
		return

	var overlay := overlay_scene.instantiate()

	current_scene.add_child(overlay)

	get_tree().paused = true

	game_over.emit(victory)


# =========================================================
# ПЕРЕЗАПУСК
# =========================================================

func restart_game(reset_callback: Callable):
	_call_reset(reset_callback)

	game_over_started = false
	state = GameState.PLAYING

	get_tree().paused = false

	call_deferred("_change_scene",MAIN_SCENE_PATH)


# =========================================================
# ВОЗВРАТ В ГЛАВНОЕ МЕНЮ
# =========================================================

func return_to_menu(reset_callback: Callable):
	_call_reset(reset_callback)

	game_over_started = false
	state = GameState.MENU

	get_tree().paused = false

	call_deferred("_change_scene",MENU_SCENE_PATH)


# =========================================================
# СБРОС СОСТОЯНИЯ FLOW
# =========================================================

func reset():
	game_over_started = false
	state = GameState.MENU


# =========================================================
# ВНУТРЕННИЕ МЕТОДЫ
# =========================================================

func _kill_player(player: Node2D):
	if not is_instance_valid(player):
		return

	if player.is_queued_for_deletion():
		return

	if player.has_method("die"):
		player.die()


func _call_reset(reset_callback: Callable):
	if reset_callback.is_valid():
		reset_callback.call()


func _change_scene(scene_path: String):
	if scene_path.is_empty():
		push_error("Путь к сцене не указан.")
		return

	if not ResourceLoader.exists(scene_path):
		push_error("Сцена не найдена по пути: "+ scene_path)
		return

	var error := get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("Не удалось загрузить сцену: "+ scene_path+ ". Код ошибки: "+ str(error))

func go_to_next_floor() -> void:
	game_over_started = false
	state = GameState.PLAYING

	get_tree().paused = false

	call_deferred(
		"_change_scene",
		MAIN_SCENE_PATH
	)
