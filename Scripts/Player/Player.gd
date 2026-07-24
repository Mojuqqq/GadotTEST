extends CharacterBody2D

@export var base_speed: float = 300.0
@export var egg_scene: PackedScene
var egg_pool: Array[Node] = []
const INITIAL_POOL_SIZE := 20

var external_force: Vector2 = Vector2.ZERO
var current_speed: float = 300.0
var time_since_last_shot: float = 0.0
@export_group("Hot Sauce")
var hot_sauce_effect_total_duration: float = 0.0

@export_range(1.0, 120.0, 1.0)
var hot_sauce_duration: float = 30.0

@export_range(1.0, 3.0, 0.05)
var hot_sauce_egg_speed_multiplier: float = 1.2


var current_egg_speed_multiplier: float = 1.0
var hot_sauce_timer: Timer = null

# Эффект слёз
var is_crying: bool = false
var tear_timer: Timer = null

var rooster_companion: Node2D = null
var chick_bomb: Node2D = null


const ROOSTER_SCENE := preload(
	"res://Scenes/Companions/Rooster_companion.tscn"
)

const CHICK_BOMB_SCENE := preload(
	"res://Scenes/Companions/Chick_bomb_companion.tscn"
)

func _ready():
	add_to_group("Player")
	if GameManager.player_stats:
		current_speed = GameManager.player_stats.speed
	else:
		current_speed = base_speed
	
	tear_timer = Timer.new()
	tear_timer.one_shot = true
	tear_timer.timeout.connect(_on_tear_effect_end)
	add_child(tear_timer)
	
	hot_sauce_timer = Timer.new()
	hot_sauce_timer.name = "HotSauceTimer"
	hot_sauce_timer.one_shot = true

	hot_sauce_timer.timeout.connect(
		_on_hot_sauce_effect_ended
	)

	add_child(hot_sauce_timer)
	
	call_deferred("_create_egg_pool")
	
func _create_egg_pool():
	for i in INITIAL_POOL_SIZE:
		var egg = egg_scene.instantiate()
		get_tree().current_scene.add_child(egg)

		egg.returned_to_pool.connect(_on_egg_returned_to_pool)
		egg.deactivate()

		# deactivate() отправляет сигнал, поэтому убираем возможный дубль
		if not egg_pool.has(egg):
			egg_pool.append(egg)

func _on_egg_returned_to_pool(egg):
	if not egg_pool.has(egg):
		egg_pool.append(egg)

func _physics_process(delta):
	# === Движение ===
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):   direction.x -= 1
	if Input.is_action_pressed("move_right"):  direction.x += 1
	if Input.is_action_pressed("move_up"):     direction.y -= 1
	if Input.is_action_pressed("move_down"):   direction.y += 1
	direction = direction.normalized()
	
	var desired_velocity = direction * current_speed
	velocity = desired_velocity + external_force
	external_force = external_force.lerp(Vector2.ZERO, 0.1)
	move_and_slide()
	
	# === Стрельба ===
	time_since_last_shot += delta   # время тикает всегда
	
	var is_shooting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var fire_rate = GameManager.player_stats.fire_rate if GameManager.player_stats else 0.3
	
	if is_shooting and time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

func update_speed(new_speed: float):
	current_speed = new_speed

func apply_push(force: Vector2):
	external_force += force

func shoot() -> void:
	if egg_scene == null:
		return

	var egg

	if egg_pool.is_empty():
		egg = egg_scene.instantiate()

		get_tree().current_scene.add_child(
			egg
		)

		egg.returned_to_pool.connect(
			_on_egg_returned_to_pool
		)
	else:
		egg = egg_pool.pop_back()

	var dir: Vector2 = (
		get_global_mouse_position()
		- global_position
	).normalized()

	if is_crying:
		dir = -dir

	var use_rotten_egg: bool = (
		_should_use_rotten_egg()
	)

	var use_golden_egg: bool = false

	if GameManager.player_stats:
		egg.damage = (
			GameManager.player_stats.damage
		)

		egg.speed = (
			GameManager.player_stats.egg_speed
			* current_egg_speed_multiplier
		)

		egg.max_range = (
			GameManager.player_stats.attack_range
			* GameManager.player_stats.attack_range_multiplier
		)

		use_golden_egg = (
			GameManager.player_stats.has_golden_egg
		)

	egg.activate(
		global_position,
		dir,
		egg.damage,
		use_rotten_egg,
		use_golden_egg
	)

	# Списываем тухлое яйцо только после
	# успешного создания снаряда.
	if use_rotten_egg:
		var removed: bool = (
			GameManager.remove_inventory_item(
				"rotten_egg",
				1
			)
		)

		if removed:
			print(
				"Использовано тухлое яйцо. Осталось: ",
				GameManager.get_inventory_item_amount(
					"rotten_egg"
				)
			)
		else:
			push_warning(
				"Не удалось списать тухлое яйцо."
			)

func _should_use_rotten_egg() -> bool:
	var selected_slot: int = (
		GameManager.get_selected_quick_slot()
	)

	if selected_slot < 0:
		return false

	var selected_item: ItemData = (
		GameManager.get_quick_slot_item(
			selected_slot
		)
	)

	if selected_item == null:
		return false

	if (
		selected_item.use_mode
		!= ItemData.UseMode.AMMO
	):
		return false

	if selected_item.id != "rotten_egg":
		return false

	return GameManager.has_inventory_item(
		"rotten_egg",
		1
	)

# =========================================================
# ИСПОЛЬЗОВАНИЕ ПРЕДМЕТОВ
# =========================================================

func use_inventory_item(
	item_id: String
) -> Dictionary:
	match item_id:
		"hot_sauce":
			return _use_hot_sauce()

		"battle_rooster":
			return _use_battle_rooster()

		"chick":
			return _use_chick_bomb()

		"omelet":
			return _use_omelet()

		_:
			return {
				"success": false,
				"message": (
					"Использование предмета "
					+ item_id
					+ " пока не реализовано."
				)
			}

func _use_omelet() -> Dictionary:
	if GameManager.player_stats == null:
		return {
			"success": false,
			"message": (
				"Характеристики игрока не найдены."
			)
		}

	GameManager.increase_max_hp(2)

	return {
		"success": true,
		"message": (
			"Максимальное здоровье увеличено "
			+ "на 2 сердца."
		)
	}

func _use_hot_sauce() -> Dictionary:
	if hot_sauce_timer == null:
		return {
			"success": false,
			"message": (
				"Не найден таймер острого соуса."
			)
		}

	current_egg_speed_multiplier = (
		hot_sauce_egg_speed_multiplier
	)

	var remaining_time: float = 0.0

	if not hot_sauce_timer.is_stopped():
		remaining_time = (
			hot_sauce_timer.time_left
		)

	var new_duration: float = (
		remaining_time
		+ hot_sauce_duration
	)

	hot_sauce_effect_total_duration = (
		new_duration
	)

	hot_sauce_timer.start(
		new_duration
	)

	print(
		"Острый соус активирован. ",
		"Множитель скорости яиц: ",
		current_egg_speed_multiplier,
		". Осталось секунд: ",
		new_duration
	)

	return {
		"success": true,
		"message": (
			"Острый соус: скорость яиц +"
			+ str(
				roundi(
					(
						hot_sauce_egg_speed_multiplier
						- 1.0
					)
					* 100.0
				)
			)
			+ "% на "
			+ str(
				roundi(new_duration)
			)
			+ " сек."
		)
	}


func _on_hot_sauce_effect_ended() -> void:
	current_egg_speed_multiplier = 1.0
	hot_sauce_effect_total_duration = 0.0

	print(
		"Действие острого соуса закончилось."
	)

func apply_tear_effect(duration: float):
	is_crying = true
	modulate = Color(0.5, 0.5, 1.0, 1.0)
	tear_timer.stop()
	tear_timer.wait_time = duration
	tear_timer.start()

func _on_tear_effect_end():
	is_crying = false
	modulate = Color.WHITE

func take_damage(damage: int):
	GameManager.take_damage(damage)

func die():
	print("Игрок умер!")

	remove_companions()

	call_deferred("queue_free")
	
func spawn_companion(
	companion_type: String
) -> void:
	match companion_type:
		"rooster":
			_spawn_rooster()

		"chick":
			_spawn_chick_bomb()

		_:
			push_warning(
				"Неизвестный тип компаньона: "
				+ companion_type
			)

func _use_battle_rooster() -> Dictionary:
	if _has_active_rooster():
		return {
			"success": false,
			"message": (
				"Боевой петух уже находится рядом."
			)
		}

	var instance: Node2D = _spawn_rooster()

	if instance == null:
		return {
			"success": false,
			"message": (
				"Не удалось призвать боевого петуха."
			)
		}

	return {
		"success": true,
		"message": "Боевой петух призван.",
		"rollback_on_consume_failure": true
	}

func rollback_inventory_item_use(
	item_id: String
) -> void:
	match item_id:
		"battle_rooster":
			if _has_active_rooster():
				rooster_companion.queue_free()

		"chick":
			if _has_active_chick_bomb():
				chick_bomb.queue_free()

		_:
			pass

func _has_active_rooster() -> bool:
	return (
		is_instance_valid(rooster_companion)
		and not rooster_companion.is_queued_for_deletion()
	)

func _spawn_rooster() -> Node2D:
	if _has_active_rooster():
		print(
			"Боевой петух уже существует."
		)
		return null

	if ROOSTER_SCENE == null:
		push_error(
			"Не назначена сцена боевого петуха."
		)
		return null

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		push_error(
			"Не найдена текущая игровая сцена."
		)
		return null

	var instance := (
		ROOSTER_SCENE.instantiate()
		as Node2D
	)

	if instance == null:
		push_error(
			"Не удалось создать боевого петуха."
		)
		return null

	current_scene.add_child(instance)

	instance.global_position = (
		global_position
		+ Vector2(55.0, 0.0)
	)

	if instance.has_method("set_player"):
		instance.set_player(self)

	rooster_companion = instance

	instance.tree_exited.connect(
		_on_rooster_removed.bind(instance),
		CONNECT_ONE_SHOT
	)

	print(
		"Создан боевой петух."
	)

	return instance

func _use_chick_bomb() -> Dictionary:
	if _has_active_chick_bomb():
		return {
			"success": false,
			"message": (
				"Цыплёнок уже находится рядом."
			)
		}

	var instance: Node2D = (
		_spawn_chick_bomb()
	)

	if instance == null:
		return {
			"success": false,
			"message": (
				"Не удалось создать цыплёнка."
			)
		}

	return {
		"success": true,
		"message": "Цыплёнок призван.",
		"rollback_on_consume_failure": true
	}


func _has_active_chick_bomb() -> bool:
	return (
		is_instance_valid(chick_bomb)
		and not chick_bomb.is_queued_for_deletion()
	)

func _spawn_chick_bomb() -> Node2D:
	if _has_active_chick_bomb():
		print(
			"Цыплёнок уже существует."
		)
		return null

	if CHICK_BOMB_SCENE == null:
		push_error(
			"Не назначена сцена цыплёнка."
		)
		return null

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		push_error(
			"Не найдена текущая игровая сцена."
		)
		return null

	var instance := (
		CHICK_BOMB_SCENE.instantiate()
		as Node2D
	)

	if instance == null:
		push_error(
			"Не удалось создать цыплёнка."
		)
		return null

	current_scene.add_child(instance)

	instance.global_position = (
		global_position
		+ Vector2(-45.0, 0.0)
	)

	if instance.has_method("set_player"):
		instance.set_player(self)

	chick_bomb = instance

	instance.tree_exited.connect(
		_on_chick_bomb_removed.bind(instance),
		CONNECT_ONE_SHOT
	)

	print(
		"Создан цыплёнок."
	)

	return instance


func _on_rooster_removed(
	instance: Node
) -> void:
	if rooster_companion == instance:
		rooster_companion = null


func _on_chick_bomb_removed(
	instance: Node
) -> void:
	if chick_bomb == instance:
		chick_bomb = null

func remove_companions() -> void:
	if is_instance_valid(rooster_companion):
		rooster_companion.queue_free()

	if is_instance_valid(chick_bomb):
		chick_bomb.queue_free()

	rooster_companion = null
	chick_bomb = null

func teleport_companions_to_player() -> void:
	if (
		is_instance_valid(rooster_companion)
		and not rooster_companion.is_queued_for_deletion()
	):
		if rooster_companion.has_method(
			"teleport_to_player"
		):
			rooster_companion.teleport_to_player(
				Vector2(55, 0)
			)

	if (
		is_instance_valid(chick_bomb)
		and not chick_bomb.is_queued_for_deletion()
	):
		if chick_bomb.has_method(
			"teleport_to_player"
		):
			chick_bomb.teleport_to_player(
				Vector2(-55, 0)
			)

func get_active_timed_effects() -> Array[Dictionary]:
	var effects: Array[Dictionary] = []

	if (
		hot_sauce_timer != null
		and not hot_sauce_timer.is_stopped()
	):
		effects.append({
			"item_id": "hot_sauce",
			"time_left": hot_sauce_timer.time_left,
			"duration": maxf(
				hot_sauce_effect_total_duration,
				hot_sauce_duration
			)
		})

	return effects
