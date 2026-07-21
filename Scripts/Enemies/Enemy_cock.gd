extends BaseEnemy

# === Параметры босса ===
@export var speed: float = 80.0
@export var melee_range: float = 300.0
@export var melee_damage: int = 3
@export var melee_cooldown: float = 1.0
@export var ranged_damage: int = 2
@export var ranged_cooldown: float = 2.0
@export var bullet_scene: PackedScene
@export var bullet_speed: float = 350.0

var player: Node2D = null
var is_melee_mode: bool = false
var attack_timer: Timer = null

func _ready():
	# Устанавливаем HP босса (можно изменить в инспекторе)
	hp = 20
	max_hp = 20
	super()  # создаёт HP bar
	
	add_to_group("Enemies")
	print("Босс готов, игрок найден: ", player != null)
	
	# Увеличиваем HP bar для босса (делаем больше)
	if hp_bar:
		hp_bar.size = Vector2(150, 20)
		hp_bar.position = Vector2(-75, -80)
		# Можно изменить стиль (цвет, шрифт)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color(0.8, 0.1, 0.1)  # красный
		hp_bar.add_theme_stylebox_override("fill", fill_style)
	
	attack_timer = Timer.new()
	attack_timer.wait_time = ranged_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distance = global_position.distance_to(player.global_position)
	var direction = (player.global_position - global_position).normalized()
	
	if distance <= melee_range:
		is_melee_mode = true
		velocity = direction * speed * 0.3
	else:
		is_melee_mode = false
		velocity = direction * speed
	
	move_and_slide()
	
	if room_limits != Rect2():
		global_position.x = clamp(global_position.x, room_limits.position.x + 10, room_limits.position.x + room_limits.size.x - 10)
		global_position.y = clamp(global_position.y, room_limits.position.y + 10, room_limits.position.y + room_limits.size.y - 10)

# === Управление активностью комнаты ===
func set_active(active: bool):
	super(active)  # вызывает базовую версию (управляет HP bar и физикой)
	if active:
		if not attack_timer.is_stopped():
			attack_timer.stop()
		attack_timer.start()
	else:
		attack_timer.stop()

# === Атака ===
func _on_attack_timer_timeout():
	if not is_active or is_dead or player == null:
		attack_timer.wait_time = 0.5
		attack_timer.start()
		return
	
	if is_melee_mode:
		melee_attack()
	else:
		ranged_attack()
	
	attack_timer.wait_time = melee_cooldown if is_melee_mode else ranged_cooldown
	attack_timer.start()

func melee_attack():
	if player and player.has_method("take_damage"):
		player.take_damage(melee_damage)

func ranged_attack():
	if player == null or bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	var dir = (player.global_position - global_position).normalized()
	bullet.setup(dir, bullet_speed, ranged_damage)
