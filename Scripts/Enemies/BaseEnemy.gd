extends CharacterBody2D
class_name BaseEnemy

# === Сигналы ===
signal died(victim: Node)

# === Параметры здоровья ===
@export var hp: int = 3
@export var max_hp: int = 3
@export_group("Damage Feedback")

# Можно вручную указать основной спрайт.
# При пустом значении он будет найден автоматически.
@export var damage_visual_path: NodePath

@export var damage_tint: Color = Color(
	1.0,
	0.22,
	0.22,
	1.0
)

@export_range(0.0, 32.0, 1.0)
var damage_bounce_height: float = 10.0

@export_range(0.1, 0.5, 0.01)
var damage_feedback_duration: float = 0.24

# === Состояние ===
var is_dead: bool = false
var room_limits: Rect2
var hp_bar: ProgressBar = null
var is_active: bool = false
var damage_visual: Node2D = null
var damage_feedback_tween: Tween = null

var damage_visual_base_scale: Vector2 = (
	Vector2.ONE
)

var damage_visual_base_position: Vector2 = (
	Vector2.ZERO
)

var damage_visual_base_modulate: Color = (
	Color.WHITE
)

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
	_initialize_damage_visual()

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

func take_damage(
	amount: int
) -> void:
	if is_dead:
		return

	if amount <= 0:
		return

	var actual_damage: int = mini(
		amount,
		hp
	)

	if actual_damage <= 0:
		return

	_play_damage_visual_response()

	hp = maxi(
		hp - actual_damage,
		0
	)

	if hp_bar != null:
		hp_bar.value = hp

		var fill_style := StyleBoxFlat.new()

		if hp <= max_hp * 0.25:
			fill_style.bg_color = Color.RED
		elif hp <= max_hp * 0.5:
			fill_style.bg_color = Color.YELLOW
		else:
			fill_style.bg_color = Color.GREEN

		hp_bar.add_theme_stylebox_override(
			"fill",
			fill_style
		)

	if hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	# Враг больше не атакует и не сталкивается,
	# но остаётся на экране для hit-анимации.
	set_process(
		false
	)

	set_physics_process(
		false
	)

	collision_layer = 0
	collision_mask = 0

	_set_detection_areas_enabled(
		false
	)

	# Счётчик врагов не должен ждать
	# окончания визуальной реакции.
	remove_from_group(
		&"Enemies"
	)

	if hp_bar != null:
		hp_bar.queue_free()
		hp_bar = null

	died.emit(
		self
	)

	_drop_loot()

	await get_tree().create_timer(
		maxf(
			damage_feedback_duration,
			0.05
		)
	).timeout

	queue_free()

func _initialize_damage_visual() -> void:
	if not damage_visual_path.is_empty():
		damage_visual = (
			get_node_or_null(
				damage_visual_path
			)
			as Node2D
		)

	if damage_visual == null:
		damage_visual = (
			_find_damage_visual_recursive(
				self
			)
		)

	if damage_visual == null:
		push_warning(
			"У врага "
			+ name
			+ " не найден Sprite2D "
			+ "или AnimatedSprite2D "
			+ "для реакции на урон."
		)

		return

	damage_visual_base_scale = (
		damage_visual.scale
	)

	damage_visual_base_position = (
		damage_visual.position
	)

	damage_visual_base_modulate = (
		damage_visual.modulate
	)


func _find_damage_visual_recursive(
	node: Node
) -> Node2D:
	for child in node.get_children():
		if (
			child is AnimatedSprite2D
			or child is Sprite2D
		):
			return child as Node2D

		var nested_visual: Node2D = (
			_find_damage_visual_recursive(
				child
			)
		)

		if nested_visual != null:
			return nested_visual

	return null

func _play_damage_visual_response() -> void:
	if not is_instance_valid(
		damage_visual
	):
		return

	if (
		damage_feedback_tween != null
		and damage_feedback_tween.is_valid()
	):
		damage_feedback_tween.kill()

	# При быстром повторном попадании сначала
	# возвращаем исходное состояние.
	damage_visual.scale = (
		damage_visual_base_scale
	)

	damage_visual.position = (
		damage_visual_base_position
	)

	damage_visual.modulate = (
		damage_tint
	)

	var total_duration: float = maxf(
		damage_feedback_duration,
		0.1
	)

	var squash_duration: float = (
		total_duration * 0.22
	)

	var bounce_duration: float = (
		total_duration * 0.34
	)

	var settle_duration: float = (
		total_duration
		- squash_duration
		- bounce_duration
	)

	var bounce_delay: float = (
		squash_duration
	)

	var settle_delay: float = (
		squash_duration
		+ bounce_duration
	)

	var squash_scale: Vector2 = (
		damage_visual_base_scale
		* Vector2(
			1.18,
			0.82
		)
	)

	var stretch_scale: Vector2 = (
		damage_visual_base_scale
		* Vector2(
			0.9,
			1.15
		)
	)

	var impact_position: Vector2 = (
		damage_visual_base_position
		+ Vector2(
			0.0,
			4.0
		)
	)

	var bounce_position: Vector2 = (
		damage_visual_base_position
		+ Vector2(
			0.0,
			-damage_bounce_height
		)
	)

	damage_feedback_tween = create_tween()

	damage_feedback_tween.set_parallel(
		true
	)

	# Сжатие от попадания.
	damage_feedback_tween.tween_property(
		damage_visual,
		"scale",
		squash_scale,
		squash_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	damage_feedback_tween.tween_property(
		damage_visual,
		"position",
		impact_position,
		squash_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	# Подпрыгивание.
	damage_feedback_tween.tween_property(
		damage_visual,
		"scale",
		stretch_scale,
		bounce_duration
	).set_delay(
		bounce_delay
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	damage_feedback_tween.tween_property(
		damage_visual,
		"position",
		bounce_position,
		bounce_duration
	).set_delay(
		bounce_delay
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	# Возвращение к нормальной форме.
	damage_feedback_tween.tween_property(
		damage_visual,
		"scale",
		damage_visual_base_scale,
		settle_duration
	).set_delay(
		settle_delay
	).set_trans(
		Tween.TRANS_BOUNCE
	).set_ease(
		Tween.EASE_OUT
	)

	damage_feedback_tween.tween_property(
		damage_visual,
		"position",
		damage_visual_base_position,
		settle_duration
	).set_delay(
		settle_delay
	).set_trans(
		Tween.TRANS_BOUNCE
	).set_ease(
		Tween.EASE_OUT
	)

	# Красный оттенок плавно исчезает
	# на протяжении всей реакции.
	damage_feedback_tween.tween_property(
		damage_visual,
		"modulate",
		damage_visual_base_modulate,
		total_duration
	)

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
	loot_name: String,
	local_offset: Vector2 = Vector2.ZERO
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

	if not is_instance_valid(
		pickup_parent
	):
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

	# Позицию задаём до добавления в дерево.
	# Смещение позволяет разбрасывать несколько наград.
	pickup.position = (
		pickup_parent.to_local(
			global_position
		)
		+ local_offset
	)

	if pickup.has_method(
		"setup"
	):
		pickup.setup(
			amount
		)

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
