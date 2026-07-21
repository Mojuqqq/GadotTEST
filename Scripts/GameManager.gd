extends Node

# ===== СИГНАЛЫ ДЛЯ UI =====
signal player_hp_changed(hp, max_hp)
signal room_changed(room_name, room_index)
signal enemies_changed(count)
signal game_over(victory: bool)
signal stats_changed(stats)

enum GameState { MENU, PLAYING, GAME_OVER, VICTORY }
var state: GameState = GameState.MENU

var is_transitioning: bool = false
var boss_scene: PackedScene

# ===== СОСТОЯНИЕ ИГРОКА =====
var player: Node2D = null
var player_hp: int = 5
var player_max_hp: int = 5

# ===== ХАРАКТЕРИСТИКИ ИГРОКА =====
var player_stats = null

# ===== КОМНАТЫ =====
var room_instances: Array[Node2D] = []
var current_room_index: int = 0

# ===== НАСТРОЙКИ ГЕНЕРАЦИИ =====
var room_width: int = 1280
var room_height: int = 1024
var room_spacing: int = 50
var min_rooms: int = 2
var max_rooms: int = 4

var start_room_scene: PackedScene
var end_room_scene: PackedScene
var room_pool: Array[PackedScene] = []
var enemy_pool: Array[PackedScene] = []
var all_items: Array[ItemData] = []

@export var min_enemies_per_room: int = 4
@export var max_enemies_per_room: int = 10
@export var enemies_in_start_room: int = 0
@export var enemies_in_end_room: int = 4

func _ready():
	init_items()

# ===== УПРАВЛЕНИЕ СОСТОЯНИЕМ =====
func start_game():
	state = GameState.PLAYING
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Main.tscn")

# Переименовано, чтобы не конфликтовать с сигналом
func trigger_game_over(victory: bool = false):
	state = GameState.GAME_OVER if not victory else GameState.VICTORY
	get_tree().paused = true
	var scene_path = "res://Scenes/Game_over.tscn" if not victory else "res://Victory.tscn"
	var instance = load(scene_path).instantiate()
	get_tree().current_scene.add_child(instance)
	# Можно также испустить сигнал, если кто-то подписан
	emit_signal("game_over", victory)

func restart_game():
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main_menu.tscn")

# ===== МЕТОДЫ УПРАВЛЕНИЯ ИГРОКОМ =====
func set_player(player_node: Node2D):
	player = player_node
	player_hp = player_max_hp
	emit_signal("player_hp_changed", player_hp, player_max_hp)

func set_player_stats(stats):
	player_stats = stats
	player_hp = stats.max_hp
	player_max_hp = stats.max_hp
	emit_signal("player_hp_changed", player_hp, player_max_hp)
	emit_signal("stats_changed", stats)
	if player and player.has_method("update_speed"):
		player.update_speed(stats.speed)

func upgrade_stat(stat_name: String, amount: float):
	if player_stats == null:
		return
	match stat_name:
		"max_hp":
			player_stats.max_hp += int(amount)
			player_max_hp = player_stats.max_hp
			player_hp = min(player_hp + int(amount), player_max_hp)
			emit_signal("player_hp_changed", player_hp, player_max_hp)
		"damage":
			player_stats.damage += int(amount)
		"speed":
			player_stats.speed += amount
			if player and player.has_method("update_speed"):
				player.update_speed(player_stats.speed)
		"fire_rate":
			player_stats.fire_rate = max(0.05, player_stats.fire_rate - amount)
		"egg_speed":
			player_stats.egg_speed += amount
	emit_signal("stats_changed", player_stats)

func take_damage(amount: int):
	player_hp -= amount
	if player_hp < 0:
		player_hp = 0
	emit_signal("player_hp_changed", player_hp, player_max_hp)
	if player_hp <= 0:
		emit_signal("game_over", false)
		if player and player.has_method("die"):
			player.die()

func heal(amount: int):
	player_hp = min(player_hp + amount, player_max_hp)
	emit_signal("player_hp_changed", player_hp, player_max_hp)

# ===== ГЕНЕРАЦИЯ ПОДЗЕМЕЛЬЯ =====
func generate_dungeon(root_node: Node):
	# Безопасно очищаем старые комнаты
	for room in room_instances:
		if is_instance_valid(room):
			room.queue_free()
	room_instances.clear()
	
	if start_room_scene == null or end_room_scene == null or room_pool.size() == 0:
		print("Ошибка: не назначены сцены комнат!")
		return

	var intermediate_count = randi_range(min_rooms, max_rooms)
	print("Генерация: ", intermediate_count, " промежуточных комнат")

	var prev_room: Node2D

	var start_room = start_room_scene.instantiate()
	start_room.name = "StartRoom"
	root_node.add_child(start_room)
	start_room.global_position = Vector2(0, 0)
	room_instances.append(start_room)
	prev_room = start_room
	spawn_enemies_for_room(start_room, 0)

	for i in range(intermediate_count):
		var random_scene = room_pool[randi_range(0, room_pool.size() - 1)]
		var room = random_scene.instantiate()
		room.name = "Room" + str(i + 1)
		root_node.add_child(room)
		room.global_position = prev_room.global_position + Vector2(room_width + room_spacing, 0)
		room_instances.append(room)
		prev_room = room
		spawn_enemies_for_room(room, i + 1)

	var end_room = end_room_scene.instantiate()
	end_room.name = "EndRoom"
	root_node.add_child(end_room)
	end_room.global_position = prev_room.global_position + Vector2(room_width + room_spacing, 0)
	room_instances.append(end_room)

	if boss_scene != null:
		var boss = boss_scene.instantiate()
		end_room.add_child(boss)
		boss.position = Vector2(room_width / 2.0, room_height / 2.0)
		if boss.has_method("set_room_limits"):
			var limits = Rect2(end_room.global_position.x, end_room.global_position.y, room_width, room_height)
			boss.set_room_limits(limits)
		boss.set_physics_process(false)
		print("Босс создан в конечной комнате")
	else:
		spawn_enemies_for_room(end_room, room_instances.size() - 1)
		
	connect_rooms()
	disable_unconnected_doors()
	enter_room(0)

# ===== РАБОТА С КОМНАТАМИ =====
func connect_rooms():
	for i in range(room_instances.size() - 1):
		var left_room = room_instances[i]
		var right_room = room_instances[i + 1]
		var left_door = find_child_recursive(left_room, "DoorRight")
		var right_door = find_child_recursive(right_room, "DoorLeft")
		if left_door and right_door:
			if left_door.has_method("set_open") and right_door.has_method("set_open"):
				left_door.linked_door = right_door
				right_door.linked_door = left_door
				left_door.target_room_node = right_room
				right_door.target_room_node = left_room
				print("Связаны комнаты ", i, " и ", i+1)
			else:
				print("Ошибка: на дверях нет скрипта Door.gd в комнатах ", i, " и ", i+1)
		else:
			print("Нет дверей для соединения комнат ", i, " и ", i+1)

func disable_unconnected_doors():
	for room in room_instances:
		var doors = []
		collect_doors(room, doors)
		for door in doors:
			if door.has_method("set_open"):
				if door.target_room_node == null:
					door.set_open(false)
					door.monitoring = false
					door.monitorable = false
					print("Отключена дверь: ", door.name, " в комнате ", room.name)
				else:
					print("Дверь ", door.name, " в комнате ", room.name, " ведёт в ", door.target_room_node.name)

func find_child_recursive(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var result = find_child_recursive(child, target_name)
		if result:
			return result
	return null

func collect_doors(node: Node, list: Array):
	for child in node.get_children():
		if child is Area2D and (child.name == "DoorLeft" or child.name == "DoorRight"):
			list.append(child)
		else:
			collect_doors(child, list)

func enter_room(index: int):
	if index < 0 or index >= room_instances.size():
		print("Ошибка: индекс комнаты вне диапазона: ", index)
		return

	if current_room_index >= 0 and current_room_index < room_instances.size():
		var prev_room = room_instances[current_room_index]
		if prev_room.has_method("set_active"):
			prev_room.set_active(false)

	var room = room_instances[index]
	room.visible = true
	print("Комната ", room.name, " visible = ", room.visible)

	current_room_index = index
	emit_signal("room_changed", room.name, index)

	if room.has_method("on_room_entered"):
		room.on_room_entered()
	else:
		print("У комнаты нет метода on_room_entered")

	print("Вошли в комнату ", index)
	update_enemy_count()

func move_player_to_room(target_room_node: Node2D, _door_position: Vector2) -> int:
	var target_index = room_instances.find(target_room_node)
	if target_index == -1:
		print("Ошибка: целевая комната не найдена!")
		return -1
	enter_room(target_index)
	return target_index

func get_current_room() -> Node2D:
	if current_room_index < room_instances.size():
		return room_instances[current_room_index]
	return null

func get_enemy_count_in_room() -> int:
	var room = get_current_room()
	if room == null:
		return 0
	var count = 0
	var all_enemies = get_tree().get_nodes_in_group("Enemies")
	for enemy in all_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and room.is_ancestor_of(enemy):
			count += 1
	return count

func update_enemy_count():
	var count = get_enemy_count_in_room()
	emit_signal("enemies_changed", count)
	
func spawn_enemies_for_room(room: Node2D, index: int):
	var count = 0
	if index == 0:
		count = enemies_in_start_room
	elif index == room_instances.size() - 1:
		count = enemies_in_end_room
	else:
		count = randi_range(min_enemies_per_room, max_enemies_per_room)
	
	if count > 0 and enemy_pool.size() > 0:
		if room.has_method("spawn_enemies"):
			room.spawn_enemies(count, enemy_pool)
		else:
			print("Внимание: комната не имеет метода spawn_enemies")

func init_items():
	all_items.clear()
	
	var items_data = [
		{"id": "energy", "name": "⚡ Скоростные сапоги", "desc": "+15% скорость", "icon":"res://Export/Item_icons/New_boots.png", "apply": func(stats, gm):
			stats.speed *= 1.15
			if gm.player and gm.player.has_method("update_speed"):
				gm.player.update_speed(stats.speed)
			gm.emit_signal("stats_changed", stats)
	},
		{"id": "eye", "name": "👁 новые очки", "desc": "+ дальность атаки", "icon":"res://Export/Item_icons/New_glasses.png", "apply": func(stats, gm):
			stats.attack_range_multiplier = 1.5
			gm.emit_signal("stats_changed", stats)
	},
		{"id": "golden_egg", "name": "🥚 Золотое яйцо", "desc": "+50% урон", "icon":"res://Export/Item_icons/Gold_egg.png", "apply": func(stats, gm):
			stats.damage = int(stats.damage * 1.5)
			stats.has_golden_egg = true
			gm.emit_signal("stats_changed", stats)
	},
		{"id": "battle_rooster", "name": "🐔 Боевой петух", "desc": "Помощник атакует", "icon":"res://Export/Item_icons/Crazy_chicken.png", "apply": func(stats, gm):
			stats.has_chick = true
			gm.emit_signal("stats_changed", stats)
			if gm.player and gm.player.has_method("spawn_companion"):
				gm.player.spawn_companion("rooster")
	},
		{"id": "omelet", "name": "🍳 Омлет", "desc": "+2 сердца", "icon":"res://Export/Item_icons/Omlet.png", "apply": func(stats, gm):
			stats.max_hp += 2
			gm.player_hp = min(gm.player_hp + 2, stats.max_hp)
			gm.emit_signal("player_hp_changed", gm.player_hp, stats.max_hp)
	},
		{"id": "hot_sauce", "name": "🌶 Острый соус", "desc": "Яйца летят быстрее", "icon":"res://Export/Item_icons/Hot_sauce.png", "apply": func(stats, gm):
			stats.egg_speed *= 1.2
			gm.emit_signal("stats_changed", stats)
	},
		# {"id": "butter", "name": "🧈 Масло", "desc": "Яйца отскакивают от стен", "icon":"res://Export/Item_icons/Butter.png", "apply": func(stats, gm):
		# 	stats.bullet_bounce = true
		# 	gm.emit_signal("stats_changed", stats)
		# },
		{"id": "rotten_egg", "name": "💣 Тухлое яйцо", "desc": "Оставляет ядовитую лужу", "icon":"res://Export/Item_icons/Rotten_egg.png", "apply": func(stats, gm):
			stats.poison_cloud = true
			gm.emit_signal("stats_changed", stats)
	},
		{"id": "chick", "name": "🐣 Цыплёнок", "desc": "Вылупляется и атакует врагов", "icon":"res://Export/Item_icons/Item_chicken.png", "apply": func(stats, gm):
			stats.has_chick = true
			gm.emit_signal("stats_changed", stats)
			if gm.player and gm.player.has_method("spawn_companion"):
				gm.player.spawn_companion("chick")
	}
	]
	
	for data in items_data:
		var item = ItemData.new()
		item.id = data.id
		item.name = data.name
		item.description = data.desc
		if data.has("icon") and data.icon != "":
			item.icon = load(data.icon)
		item.apply = data.apply
		all_items.append(item)
		
func reset_game_state():
	state = GameState.MENU
	get_tree().paused = false
	room_instances.clear()
