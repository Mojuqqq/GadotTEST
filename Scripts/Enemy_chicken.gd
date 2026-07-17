#extends CharacterBody2D
#
#@export var hp: int = 3
#@export var speed: float = 100.0
#@export var damage: int = 1
#@export var attack_cooldown: float = 1.0
#
#signal died
#var can_attack: bool = true
#var player: Node2D = null
#var is_player_in_range: bool = false   # флаг, что игрок в зоне атаки
#var attack_timer: Timer = null
#
#func _ready():
	#add_to_group("Enemies")
	#find_player()
	#
	## Создаём таймер для перезарядки атаки
	#attack_timer = Timer.new()
	#attack_timer.wait_time = attack_cooldown
	#attack_timer.one_shot = false       # будет работать циклически
	#attack_timer.timeout.connect(_on_attack_timer_timeout)
	#add_child(attack_timer)
	#
	## Подключаем сигналы от AttackArea
	#var attack_area = $AttackArea
	#if attack_area:
		#attack_area.body_entered.connect(_on_attack_area_body_entered)
		#attack_area.body_exited.connect(_on_attack_area_body_exited)
#
#func find_player():
	#var nodes = get_tree().get_nodes_in_group("Player")
	#if nodes.size() > 0:
		#player = nodes[0]
		#
#
#func _physics_process(_delta):
	#if player == null:
		#find_player()
		#return
	## Движение к игроку
	#var direction = (player.global_position - global_position).normalized()
	#velocity = direction * speed
	#move_and_slide()
#
## Когда игрок входит в зону атаки
#func _on_attack_area_body_entered(body):
	#
	#if body.is_in_group("Player"):
		#is_player_in_range = true
		## Если таймер не запущен, запускаем
		#if not attack_timer.is_stopped():
			#attack_timer.stop()
		#attack_timer.start()
		#print("Игрок в зоне атаки, начинаем атаковать")
#
## Когда игрок покидает зону атаки
#func _on_attack_area_body_exited(body):
	#if body.is_in_group("Player"):
		#is_player_in_range = false
		#attack_timer.stop()
		#print("Игрок вышел из зоны атаки, атака остановлена")
#
## Таймер срабатывает каждые attack_cooldown секунд
#func _on_attack_timer_timeout():
	#if is_player_in_range and player != null and player.has_method("take_damage"):
		#player.take_damage(damage)
		#print("Враг атакует! Нанесено урона: ", damage)
#
#func take_damage(damage: int):
	#hp -= damage
	#print("Враг получил урон! HP = ", hp)
	#if hp <= 0:
		#die()
#
#func die():
	#print("Враг умер!")
	#died.emit()
	#queue_free()
	
extends CharacterBody2D

@export var hp: int = 3
@export var speed: float = 100.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0
@export var min_distance: float = 30.0   # дистанция, на которой останавливается

signal died(victim: Node)

var can_attack: bool = true
var player: Node2D = null
var is_player_in_range: bool = false
var attack_timer: Timer = null
var is_dead: bool = false

func _ready():
	add_to_group("Enemies")
	print("Курица создана! HP = ", hp, ", позиция: ", global_position)
	find_player()
	
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = false
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)
	
	var attack_area = $AttackArea
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_body_entered)
		attack_area.body_exited.connect(_on_attack_area_body_exited)

func find_player():
	var nodes = get_tree().get_nodes_in_group("Player")
	if nodes.size() > 0:
		player = nodes[0]

func _physics_process(_delta):
	if player == null:
		find_player()
		return
	
	# Движение к игроку с остановкой на min_distance
	var distance = global_position.distance_to(player.global_position)
	if distance > min_distance:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _on_attack_area_body_entered(body):
	if body.is_in_group("Player"):
		is_player_in_range = true
		if attack_timer.is_stopped():
			attack_timer.start()
		print("Игрок в зоне атаки курицы")

func _on_attack_area_body_exited(body):
	if body.is_in_group("Player"):
		is_player_in_range = false
		attack_timer.stop()
		print("Игрок вышел из зоны атаки курицы")

func _on_attack_timer_timeout():
	if is_player_in_range and player != null and player.has_method("take_damage"):
		player.take_damage(damage)
		print("Курица атакует! Урон: ", damage)

func take_damage(amount: int):
	if is_dead:
		return
	hp -= amount
	print("Курица получила урон! HP = ", hp)
	if hp <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	print("Враг умер!")
	died.emit(self)   # передаём себя
	queue_free()
