extends CharacterBody2D

@export var base_speed: float = 300.0
@export var egg_scene: PackedScene
@export_group("Damage Feedback")

@export var damage_feedback_scene: PackedScene

@export var damage_tint: Color = Color(
	1.0,
	0.2,
	0.2,
	1.0
)

@export_range(0.0, 32.0, 1.0)
var damage_bounce_height: float = 12.0

@export_group("Completed Floor Boost")

@export_range(1.0, 2.0, 0.05)
var completed_floor_speed_multiplier: float = 3.0
@onready var animated_sprite: AnimatedSprite2D = ($AnimatedSprite2D)
var egg_pool: Array[Node] = []
const INITIAL_POOL_SIZE := 20

var external_force: Vector2 = Vector2.ZERO
@export_group("Knockback")
@export_range(0.1, 20.0, 0.1)
var push_decay_rate: float = 6.3
var current_speed: float = 300.0
var completed_floor_speed_boost_active: bool = false
var time_since_last_shot: float = 0.0
var is_dead: bool = false
var damage_feedback_tween: Tween = null

var visual_base_scale: Vector2 = Vector2.ONE
var visual_base_position: Vector2 = Vector2.ZERO
var visual_base_modulate: Color = Color.WHITE
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
	animated_sprite.play(&"idle")
	visual_base_scale = animated_sprite.scale
	visual_base_position = animated_sprite.position
	visual_base_modulate = animated_sprite.modulate
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
	
func _create_egg_pool() -> void:
	if egg_scene == null:
		push_error(
			"Player: не назначена сцена яйца. "
			+ "Пул снарядов не создан."
		)
		return

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		push_error(
			"Player: не найдена текущая сцена. "
			+ "Пул снарядов не создан."
		)
		return

	for _index in range(
		INITIAL_POOL_SIZE
	):
		var egg: Node = (
			egg_scene.instantiate()
		)

		if egg == null:
			push_error(
				"Player: не удалось создать яйцо "
				+ "для пула."
			)
			continue

		current_scene.add_child(
			egg
		)

		if not egg.has_signal(
			&"returned_to_pool"
		):
			push_error(
				"Сцена яйца не содержит сигнал "
				+ "returned_to_pool."
			)

			egg.queue_free()
			continue

		if not egg.has_method(
			&"deactivate"
		):
			push_error(
				"Сцена яйца не содержит метод "
				+ "deactivate()."
			)

			egg.queue_free()
			continue

		egg.connect(
			&"returned_to_pool",
			_on_egg_returned_to_pool
		)

		egg.call(
			&"deactivate"
		)

		# deactivate() испускает сигнал,
		# поэтому защищаемся от дубля.
		if not egg_pool.has(
			egg
		):
			egg_pool.append(
				egg
			)

func _on_egg_returned_to_pool(egg):
	if not egg_pool.has(egg):
		egg_pool.append(egg)

func _physics_process(delta):
	if is_dead:
		return
	# === Движение ===
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_left"):   direction.x -= 1
	if Input.is_action_pressed("move_right"):  direction.x += 1
	if Input.is_action_pressed("move_up"):     direction.y -= 1
	if Input.is_action_pressed("move_down"):   direction.y += 1
	direction = direction.normalized()
	
	var desired_velocity = direction * current_speed
	velocity = desired_velocity + external_force
	var push_decay_weight: float = (
		1.0
		- exp(
			-push_decay_rate
			* delta
		)
	)

	external_force = external_force.lerp(
		Vector2.ZERO,
		push_decay_weight
	)

	if external_force.length_squared() < 1.0:
		external_force = Vector2.ZERO
	move_and_slide()
	
	_update_movement_animation(
		direction
	)
	if is_dead:
		return
		
	# === Стрельба ===
	time_since_last_shot += delta

	var is_shooting: bool = (
		Input.is_action_pressed(
			&"shoot"
		)
	)

	var fire_rate: float = 0.3

	if GameManager.player_stats != null:
		fire_rate = (
			GameManager.player_stats.fire_rate
		)

	if (
		is_shooting
		and time_since_last_shot >= fire_rate
	):
		shoot()
		time_since_last_shot = 0.0

func _update_movement_animation(
	direction: Vector2
) -> void:
	# Пока проигрывается бросок яйца,
	# ходьба и idle не должны его перебивать.
	if (
		(
			animated_sprite.animation == &"shoot"
			or animated_sprite.animation == &"heal"
		)
		and animated_sprite.is_playing()
	):
		return

	if direction == Vector2.ZERO:
		if animated_sprite.animation != &"idle":
			animated_sprite.play(&"idle")

		return

	if direction.x < 0.0:
		animated_sprite.flip_h = true
	elif direction.x > 0.0:
		animated_sprite.flip_h = false

	if animated_sprite.animation != &"walk":
		animated_sprite.play(&"walk")

func update_speed(
	new_speed: float
) -> void:
	var final_speed: float = maxf(
		new_speed,
		0.0
	)

	if completed_floor_speed_boost_active:
		final_speed *= maxf(
			completed_floor_speed_multiplier,
			1.0
		)

	current_speed = final_speed
	
	GameManager.notify_player_speed_changed(
		current_speed
	)

func _play_heal_animation() -> void:
	if animated_sprite == null:
		return

	animated_sprite.stop()
	animated_sprite.play(&"heal")

func receive_healing(
	amount: int
) -> int:
	if amount <= 0:
		return 0

	if is_dead:
		return 0

	var hp_before: int = (
		GameManager.player_hp
	)

	if hp_before >= GameManager.player_max_hp:
		return 0

	GameManager.heal(
		amount
	)

	var healed_amount: int = maxi(
		GameManager.player_hp - hp_before,
		0
	)

	if healed_amount <= 0:
		return 0

	var telemetry: Node = (
		get_tree().get_first_node_in_group(
			&"BalanceTelemetry"
		)
	)

	if (
		telemetry != null
		and telemetry.has_method(
			&"record_healing"
		)
	):
		telemetry.call(
			&"record_healing",
			healed_amount
		)

	_play_heal_animation()

	_spawn_health_feedback(
		healed_amount,
		true
	)

	return healed_amount

func get_current_speed() -> float:
	return current_speed

func activate_completed_floor_speed_boost() -> void:
	if completed_floor_speed_boost_active:
		return

	completed_floor_speed_boost_active = true

	var base_current_speed: float = base_speed

	if GameManager.player_stats != null:
		base_current_speed = (
			GameManager.player_stats.speed
		)

	update_speed(
		base_current_speed
	)


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

	_play_shoot_animation(
		dir
	)

	var use_rotten_egg: bool = (
		_should_use_rotten_egg()
	)

	var use_golden_egg: bool = false
	var base_egg_speed: float = 700.0

	if GameManager.player_stats != null:
		egg.damage = (
			GameManager.player_stats.damage
		)

		base_egg_speed = (
			GameManager.player_stats.egg_speed
		)

		egg.max_range = (
			GameManager.player_stats.attack_range
			* GameManager.player_stats.attack_range_multiplier
		)

		use_golden_egg = (
			GameManager.player_stats.has_golden_egg
		)

	# Множитель соуса применяем независимо
	# от наличия PlayerStats.
	egg.speed = (
		base_egg_speed
		* current_egg_speed_multiplier
	)
	
	egg.activate(
		global_position,
		dir,
		egg.damage,
		use_rotten_egg,
		use_golden_egg
	)

	var telemetry: Node = (
		get_tree().get_first_node_in_group(
			&"BalanceTelemetry"
		)
	)

	if (
		telemetry != null
		and telemetry.has_method(
			&"record_shot"
		)
	):
		telemetry.call(
			&"record_shot"
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

		if not removed:
			push_warning(
				"Не удалось списать тухлое яйцо."
			)


func _play_shoot_animation(
	shoot_direction: Vector2
) -> void:
	# Поворачиваем персонажа в сторону броска.
	if shoot_direction.x < -0.01:
		animated_sprite.flip_h = true
	elif shoot_direction.x > 0.01:
		animated_sprite.flip_h = false

	# stop() сбрасывает текущую анимацию
	# на первый кадр. Это позволяет корректно
	# перезапускать бросок при каждом выстреле.
	animated_sprite.stop()
	animated_sprite.play(&"shoot")

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

	var hp_before: int = (
		GameManager.player_hp
	)

	GameManager.increase_max_hp(
		2
	)

	var added_hp: int = maxi(
		GameManager.player_hp - hp_before,
		0
	)

	if added_hp > 0:
		_play_heal_animation()

		_spawn_health_feedback(
			added_hp,
			true
		)

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

func apply_tear_effect(duration: float):
	is_crying = true
	modulate = Color(0.5, 0.5, 1.0, 1.0)
	tear_timer.stop()
	tear_timer.wait_time = duration
	tear_timer.start()

func _on_tear_effect_end():
	is_crying = false
	modulate = Color.WHITE

func take_damage(
	damage: int
) -> void:
	if damage <= 0:
		return

	if is_dead:
		return

	var current_hp: int = maxi(
		GameManager.player_hp,
		0
	)

	var actual_damage: int = mini(
		damage,
		current_hp
	)
	
	if actual_damage <= 0:
		return

	var telemetry: Node = (
		get_tree().get_first_node_in_group(
			&"BalanceTelemetry"
		)
	)

	if (
		telemetry != null
		and telemetry.has_method(
			&"record_damage_taken"
		)
	):
		telemetry.call(
			&"record_damage_taken",
			actual_damage
		)

	_spawn_health_feedback(
		actual_damage,
		false
	)

	_play_damage_visual_response()

	GameManager.take_damage(
		actual_damage
	)

func _spawn_health_feedback(
	amount: int,
	is_heal: bool
) -> void:
	if amount <= 0:
		return

	if damage_feedback_scene == null:
		push_warning(
			"Player: не назначена сцена "
			+ "DamageFeedback."
		)
		return

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		return

	var feedback: Node2D = (
		damage_feedback_scene.instantiate()
		as Node2D
	)

	if feedback == null:
		push_warning(
			"Корень DamageFeedback "
			+ "должен быть Node2D."
		)
		return

	current_scene.add_child(
		feedback
	)

	feedback.global_position = (
		global_position
		+ Vector2(
			0.0,
			-75.0
		)
	)

	var display_method: StringName = (
		&"show_heal"
		if is_heal
		else &"show_damage"
	)

	if feedback.has_method(
		display_method
	):
		feedback.call(
			display_method,
			amount
		)
	else:
		push_warning(
			"В DamageFeedback отсутствует метод "
			+ str(display_method)
			+ "()."
		)

		feedback.queue_free()

func _play_damage_visual_response() -> void:
	if (
		damage_feedback_tween != null
		and damage_feedback_tween.is_valid()
	):
		damage_feedback_tween.kill()

	animated_sprite.scale = visual_base_scale
	animated_sprite.position = visual_base_position
	animated_sprite.modulate = damage_tint

	var squash_scale: Vector2 = (
		visual_base_scale
		* Vector2(
			1.2,
			0.78
		)
	)

	var stretch_scale: Vector2 = (
		visual_base_scale
		* Vector2(
			0.88,
			1.18
		)
	)

	var impact_position: Vector2 = (
		visual_base_position
		+ Vector2(
			0.0,
			4.0
		)
	)

	var bounce_position: Vector2 = (
		visual_base_position
		+ Vector2(
			0.0,
			-damage_bounce_height
		)
	)

	damage_feedback_tween = create_tween()

	# Короткое сжатие от удара.
	damage_feedback_tween.tween_property(
		animated_sprite,
		"scale",
		squash_scale,
		0.06
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	damage_feedback_tween.parallel().tween_property(
		animated_sprite,
		"position",
		impact_position,
		0.06
	)

	# Подпрыгивание и растяжение.
	damage_feedback_tween.tween_property(
		animated_sprite,
		"scale",
		stretch_scale,
		0.10
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	damage_feedback_tween.parallel().tween_property(
		animated_sprite,
		"position",
		bounce_position,
		0.10
	)

	# Красный оттенок постепенно исчезает.
	damage_feedback_tween.parallel().tween_property(
		animated_sprite,
		"modulate",
		visual_base_modulate,
		0.18
	)

	# Возвращение к обычному состоянию.
	damage_feedback_tween.tween_property(
		animated_sprite,
		"scale",
		visual_base_scale,
		0.12
	).set_trans(
		Tween.TRANS_BOUNCE
	).set_ease(
		Tween.EASE_OUT
	)

	damage_feedback_tween.parallel().tween_property(
		animated_sprite,
		"position",
		visual_base_position,
		0.12
	)

func die() -> void:
	if is_dead:
		return

	is_dead = true


	velocity = Vector2.ZERO
	external_force = Vector2.ZERO

	set_physics_process(false)

	collision_layer = 0
	collision_mask = 0

	remove_companions()

	animated_sprite.play(&"die")

	await animated_sprite.animation_finished

	queue_free()
	
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

	if (
		tear_timer != null
		and is_crying
		and not tear_timer.is_stopped()
	):
		effects.append({
			"item_id": "onion_tears",
			"display_name": "🧅 Слёзы лука",
			"icon_path": (
				"res://Assets/Art/Characters/"
				+ "Enemies/Enemy_onion.png"
			),
			"time_left": tear_timer.time_left,
			"duration": maxf(
				tear_timer.wait_time,
				0.01
			)
		})

	return effects
