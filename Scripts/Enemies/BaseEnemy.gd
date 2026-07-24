extends CharacterBody2D
class_name BaseEnemy

# === Сигналы ===
signal died(victim: Node)

# === Параметры здоровья ===
@export var hp: int = 3
@export var max_hp: int = 3

# === Состояние ===
var is_dead: bool = false
var room_limits: Rect2
var hp_bar: ProgressBar = null
var is_active: bool = false

# === Лут ===
@export_group("Loot")
@export var gold_pickup_scene: PackedScene = preload("res://Scenes/Interactables/Pickups/GoldPickup.tscn")

@export_range(0, 100, 1)
var gold_drop_chance: float = 100.0

@export var min_gold_drop: int = 1
@export var max_gold_drop: int = 3

@export var key_pickup_scene: PackedScene = preload("res://Scenes/Interactables/Pickups/KeyPickup.tscn")

@export_range(0.0, 100.0, 0.1)
var key_drop_chance: float = 5.0

@export var guaranteed_key_drop: bool = false
@export var can_carry_guaranteed_key: bool = true

var loot_dropped: bool = false

func _ready():
	# Создаём HP bar
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_bar.size = Vector2(60, 10)
	hp_bar.position = Vector2(-30, -50)  # над врагом
	hp_bar.show_percentage = false
	# Стиль (можно настроить)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	hp_bar.add_theme_stylebox_override("background", style)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.0, 0.8, 0.0)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	add_child(hp_bar)
	hp_bar.visible = false  # скрыт, пока комната не активируется

func set_room_limits(limits: Rect2):
	room_limits = limits

func set_active(active: bool) -> void:
	is_active = active

	if active:
		# Сначала возвращаем обработку узла и его детей.
		process_mode = Node.PROCESS_MODE_INHERIT

		set_process(true)
		set_physics_process(true)

		_set_detection_areas_enabled(true)

	else:
		velocity = Vector2.ZERO

		# Отключаем Area2D, чтобы враг не замечал игрока
		# через стену или из соседней комнаты.
		_set_detection_areas_enabled(false)

		set_process(false)
		set_physics_process(false)

		# Останавливает обработку дочерних Timer,
		# Area2D и других узлов врага.
		process_mode = Node.PROCESS_MODE_DISABLED

	if hp_bar != null:
		hp_bar.visible = active

func take_damage(amount: int):
	if is_dead:
		return
	hp -= amount
	if hp < 0:
		hp = 0
	if hp_bar:
		hp_bar.value = hp
		# Меняем цвет в зависимости от здоровья
		var fill_style = StyleBoxFlat.new()
		if hp <= max_hp * 0.25:
			fill_style.bg_color = Color.RED
		elif hp <= max_hp * 0.5:
			fill_style.bg_color = Color.YELLOW
		else:
			fill_style.bg_color = Color.GREEN
		hp_bar.add_theme_stylebox_override("fill", fill_style)
	if hp <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	if hp_bar:
		hp_bar.queue_free()
		hp_bar = null
	died.emit(self)
	_drop_loot()
	queue_free()
	
func is_player_side_target(
	body: Node
) -> bool:
	if not is_instance_valid(body):
		return false

	if not body.has_method("take_damage"):
		return false

	return (
		body.is_in_group("Player")
		or body.is_in_group("Companions")
	)

func _set_detection_areas_enabled(
	enabled: bool
) -> void:
	var area_nodes := find_children(
		"*",
		"Area2D",
		true,
		false
	)

	for node in area_nodes:
		var area := node as Area2D

		if area == null:
			continue

		area.set_deferred(
			"monitoring",
			enabled
		)

func _drop_loot() -> void:
	if loot_dropped:
		return

	loot_dropped = true

	# Гарантированный ключ имеет высший приоритет.
	if guaranteed_key_drop:
		_spawn_pickup(
			key_pickup_scene,
			1,
			"ключ"
		)
		return

	# Обычный случайный ключ.
	var key_roll: float = randf_range(
		0.0,
		100.0
	)

	if key_roll <= key_drop_chance:
		_spawn_pickup(
			key_pickup_scene,
			1,
			"ключ"
		)
		return

	# Если ключ не выпал, проверяем золото.
	var gold_roll: float = randf_range(
		0.0,
		100.0
	)

	if gold_roll > gold_drop_chance:
		return

	var minimum: int = mini(
		min_gold_drop,
		max_gold_drop
	)

	var maximum: int = maxi(
		min_gold_drop,
		max_gold_drop
	)

	var gold_amount: int = randi_range(
		maxi(minimum, 1),
		maxi(maximum, 1)
	)

	_spawn_pickup(
		gold_pickup_scene,
		gold_amount,
		"золото"
	)
	
func _spawn_pickup(
	pickup_scene: PackedScene,
	amount: int,
	loot_name: String
) -> void:
	if pickup_scene == null:
		push_warning(
			"У врага "
			+ name
			+ " не назначена сцена добычи: "
			+ loot_name
		)
		return

	var pickup_parent: Node2D = (
		get_parent() as Node2D
	)

	if not is_instance_valid(pickup_parent):
		push_warning(
			"Не найден родитель для добычи врага"
		)
		return

	var pickup: Area2D = (
		pickup_scene.instantiate() as Area2D
	)

	if pickup == null:
		push_warning(
			"Не удалось создать добычу: "
			+ loot_name
		)
		return

	# Позицию задаём до добавления в дерево,
	# чтобы анимация предмета стартовала правильно.
	pickup.position = pickup_parent.to_local(
		global_position
	)

	if pickup.has_method("setup"):
		pickup.setup(amount)

	# Отложенное добавление защищает от ошибки
	# flushing queries при смерти от столкновения.
	pickup_parent.call_deferred(
		"add_child",
		pickup
	)

	print(
		"Враг ",
		name,
		" выбросил ",
		loot_name,
		": ",
		amount
	)

func can_receive_guaranteed_key() -> bool:
	return (
		can_carry_guaranteed_key
		and not is_dead
	)


func assign_guaranteed_key() -> void:
	guaranteed_key_drop = true

	print(
		"Врагу назначен гарантированный ключ: ",
		name
	)
