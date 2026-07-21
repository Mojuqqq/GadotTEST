extends CharacterBody2D

# === Параметры ===
@export var follow_distance: float = 80.0
@export var speed: float = 150.0
@export var attack_range: float = 150.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0
@export var detection_range: float = 400.0  # дальность поиска врагов

var player: Node2D = null
var target_enemy: Node2D = null
var can_attack: bool = true
var attack_timer: Timer = null
var search_timer: Timer = null

func _ready():
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_cooldown_end)
	add_child(attack_timer)
	
	# Таймер для поиска врагов (чтобы не искать каждый кадр)
	search_timer = Timer.new()
	search_timer.wait_time = 0.5
	search_timer.one_shot = false
	search_timer.timeout.connect(_search_for_enemy)
	add_child(search_timer)
	search_timer.start()
	
	# Подключаем сигналы от AttackArea (для атаки)
	var attack_area = $AttackArea
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)
	
	apply_range_multiplier()

func apply_range_multiplier():
	if GameManager.player_stats:
		var mult = GameManager.player_stats.attack_range_multiplier
		attack_range = 150.0 * mult
		var attack_area = $AttackArea
		if attack_area:
			var shape = attack_area.get_node("CollisionShape2D").shape
			if shape is CircleShape2D:
				shape.radius = attack_range

func _physics_process(_delta):
	if player == null:
		var nodes = get_tree().get_nodes_in_group("Player")
		if nodes.size() > 0:
			player = nodes[0]
		else:
			return
	
	# Выбираем цель: враг (если есть) или игрок
	var target = target_enemy if target_enemy and is_instance_valid(target_enemy) else player
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Расстояние до цели
	var distance_to_target = global_position.distance_to(target.global_position)
	
	# Если цель — враг, подходим на расстояние атаки
	if target == target_enemy:
		if distance_to_target > attack_range:
			var direction = (target.global_position - global_position).normalized()
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
			# Если можно атаковать — атакуем
			if can_attack and target.has_method("take_damage"):
				attack()
	else:
		# Цель — игрок, следуем с дистанцией
		if distance_to_target > follow_distance:
			var direction = (target.global_position - global_position).normalized()
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
	
	move_and_slide()

# === Поиск врагов ===
func _search_for_enemy():
	if player == null:
		return
	
	# Ищем всех врагов в радиусе detection_range
	var all_enemies = get_tree().get_nodes_in_group("Enemies")
	var closest = null
	var closest_dist = detection_range
	
	for enemy in all_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			var dist = global_position.distance_to(enemy.global_position)
			if dist < closest_dist:
				closest_dist = dist
				closest = enemy
	
	# Если найден враг и он не мертв, ставим его целью
	if closest and is_instance_valid(closest) and not closest.is_queued_for_deletion():
		target_enemy = closest
	else:
		target_enemy = null

# === Атака ===
func attack():
	if target_enemy == null or not is_instance_valid(target_enemy):
		target_enemy = null
		return
	
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(damage)
		print("Компаньон атакует! Урон: ", damage)
	
	can_attack = false
	attack_timer.start()

# === Сигналы от AttackArea (для атаки при приближении) ===
func _on_attack_area_body_entered(body):
	if body.is_in_group("Enemies"):
		if target_enemy == null or not is_instance_valid(target_enemy):
			target_enemy = body

func _on_attack_area_body_exited(body):
	if body == target_enemy:
		# Не сбрасываем цель сразу, так как она может быть ещё жива
		# Поиск обновит цель, если враг ушёл
		pass

func _on_attack_cooldown_end():
	can_attack = true
	# Если враг всё ещё рядом, атакуем снова
	if target_enemy and is_instance_valid(target_enemy):
		attack()

# === Метод для установки игрока ===
func set_player(p: Node2D):
	player = p
