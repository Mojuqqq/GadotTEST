extends CanvasLayer

@onready var hp_bar = $HPBar
@onready var room_label = $RoomLabel
@onready var enemy_counter = $EnemyCounter

func _ready():
	# Подключаемся к сигналам GameManager
	GameManager.connect("player_hp_changed", _on_player_hp_changed)
	GameManager.connect("room_changed", _on_room_changed)
	GameManager.connect("enemies_changed", _on_enemies_changed)
	GameManager.connect("game_over", _on_game_over)
	
	# Инициализация
	_on_player_hp_changed(GameManager.player_hp, GameManager.player_max_hp)
	_on_room_changed("", 0)
	_on_enemies_changed(0)

func _on_player_hp_changed(hp, max_hp):
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	# Можно добавить цветовые изменения
	if hp <= max_hp * 0.25:
		hp_bar.modulate = Color.RED
	elif hp <= max_hp * 0.5:
		hp_bar.modulate = Color.YELLOW
	else:
		hp_bar.modulate = Color.GREEN

func _on_room_changed(room_name, index):
	room_label.text = "Комната: " + room_name

func _on_enemies_changed(count):
	enemy_counter.text = "Врагов: " + str(count)

func _on_game_over(victory: bool):
	var text = "ПОБЕДА!" if victory else "ПОРАЖЕНИЕ!"
	# Можно показать всплывающее окно
	print(text)
