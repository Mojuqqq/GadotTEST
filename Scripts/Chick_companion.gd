extends CharacterBody2D

# === Параметры (настраиваются в инспекторе) ===
@export var follow_distance: float = 80.0
@export var speed: float = 150.0
@export var attack_range: float = 150.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0

var player: Node2D = null
var target_enemy: Node2D = null
var can_attack: bool = true
var attack_timer: Timer = null

func _ready():
	# Создаём таймер для перезарядки атаки
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_cooldown_end)
	add_child(attack_timer)
	
	# Подключаем сигналы от AttackArea
	var attack_area = $AttackArea
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

func _physics_process(_delta):
	if player == null:
		# Ищем игрока, если ещё не найден
		var nodes = get_tree().get_nodes_in_group("Player")
		if nodes.size() > 0:
			player = nodes[0]
		else:
			return
	
	# Движение к игроку
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player > follow_distance:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	
	# Атака (если есть цель и можно атаковать)
	if target_enemy != null and can_attack and is_instance_valid(target_enemy):
		attack()

func _on_attack_area_body_entered(body):
	if body.is_in_group("Enemies"):
		# Если цель не задана или текущая цель мертва, выбираем новую
		if target_enemy == null or not is_instance_valid(target_enemy):
			target_enemy = body

func _on_attack_area_body_exited(body):
	if body == target_enemy:
		target_enemy = null

func attack():
	if target_enemy == null or not is_instance_valid(target_enemy):
		target_enemy = null
		return
	
	# Наносим урон
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(damage)
		print("Компаньон атакует! Урон: ", damage)
	
	# Запускаем перезарядку
	can_attack = false
	attack_timer.start()

func _on_attack_cooldown_end():
	can_attack = true

# Метод для установки игрока (если нужно)
func set_player(p: Node2D):
	player = p
