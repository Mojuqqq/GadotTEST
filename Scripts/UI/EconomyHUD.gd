extends CanvasLayer


@onready var health_label: Label = %HealthLabel
@onready var gold_label: Label = %GoldLabel
@onready var key_label: Label = %KeyLabel
@onready var health_icon: TextureRect = %HealthIcon
@onready var gold_icon: TextureRect = %GoldIcon
@onready var key_icon: TextureRect = %KeyIcon

const FLYING_ICON_SIZE: float = 32.0

const PICKUP_FLY_MIN_DURATION: float = 0.55
const PICKUP_FLY_MAX_DURATION: float = 0.85

const PICKUP_FLY_SPEED: float = 900.0
const PICKUP_FLY_ARC_HEIGHT: float = 90.0


var counter_pulse_tweens: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	add_to_group(
		&"EconomyHUD"
	)

	_connect_signals()
	_refresh_values()

	call_deferred(
		&"_prepare_counter_icons"
	)

func _prepare_counter_icons() -> void:
	var counter_icons: Array[TextureRect] = [
		health_icon,
		gold_icon,
		key_icon
	]

	for counter_icon in counter_icons:
		if not is_instance_valid(
			counter_icon
		):
			continue

		counter_icon.pivot_offset = (
			counter_icon.size * 0.5
		)

func play_pickup_fly(
	texture: Texture2D,
	world_position: Vector2,
	counter_target: StringName
) -> void:
	if texture == null:
		return

	var target_icon: TextureRect = (
		_get_counter_target_icon(
			counter_target
		)
	)

	if not is_instance_valid(
		target_icon
	):
		return

	var viewport: Viewport = get_viewport()

	if viewport == null:
		return

	# Переводим позицию предмета из игрового мира
	# в экранные координаты интерфейса.
	var start_position: Vector2 = (
		viewport.get_canvas_transform()
		* world_position
	)

	var target_position: Vector2 = (
		target_icon.get_global_rect().get_center()
	)

	var flying_icon := Sprite2D.new()

	flying_icon.name = "FlyingPickupIcon"
	flying_icon.texture = texture

	flying_icon.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR
	)

	flying_icon.position = start_position
	flying_icon.z_index = 100

	var texture_size: Vector2 = (
		texture.get_size()
	)

	if (
		texture_size.x > 0.0
		and texture_size.y > 0.0
	):
		var scale_factor: float = minf(
			FLYING_ICON_SIZE / texture_size.x,
			FLYING_ICON_SIZE / texture_size.y
		)

		flying_icon.scale = (
			Vector2.ONE * scale_factor
		)

	add_child(
		flying_icon
	)

	var start_scale: Vector2 = (
		flying_icon.scale
	)

	var final_scale: Vector2 = (
		start_scale * 0.6
	)

	var distance_to_target: float = (
		start_position.distance_to(
			target_position
		)
	)

	var flight_duration: float = clampf(
		distance_to_target / PICKUP_FLY_SPEED,
		PICKUP_FLY_MIN_DURATION,
		PICKUP_FLY_MAX_DURATION
	)

	var arc_height: float = minf(
		PICKUP_FLY_ARC_HEIGHT,
		distance_to_target * 0.3
	)

	# Контрольная точка формирует единую плавную дугу.
	var control_position: Vector2 = (
		start_position.lerp(
			target_position,
			0.45
		)
		+ Vector2(
			0.0,
			-arc_height
		)
	)

	var fly_tween: Tween = create_tween()

	fly_tween.set_process_mode(
		Tween.TWEEN_PROCESS_IDLE
	)

	fly_tween.tween_method(
		_update_flying_pickup.bind(
			flying_icon,
			start_position,
			control_position,
			target_position,
			start_scale,
			final_scale
		),
		0.0,
		1.0,
		flight_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	fly_tween.tween_callback(
		_on_pickup_fly_finished.bind(
			flying_icon,
			target_icon
		)
	)

	fly_tween.tween_callback(
		_on_pickup_fly_finished.bind(
			flying_icon,
			target_icon
		)
	)

func _update_flying_pickup(
	progress: float,
	flying_icon: Sprite2D,
	start_position: Vector2,
	control_position: Vector2,
	target_position: Vector2,
	start_scale: Vector2,
	final_scale: Vector2
) -> void:
	if not is_instance_valid(
		flying_icon
	):
		return

	var safe_progress: float = clampf(
		progress,
		0.0,
		1.0
	)

	# Квадратичная кривая Безье:
	# start → control → target.
	var first_segment: Vector2 = (
		start_position.lerp(
			control_position,
			safe_progress
		)
	)

	var second_segment: Vector2 = (
		control_position.lerp(
			target_position,
			safe_progress
		)
	)

	flying_icon.position = (
		first_segment.lerp(
			second_segment,
			safe_progress
		)
	)

	flying_icon.scale = (
		start_scale.lerp(
			final_scale,
			safe_progress
		)
	)

	# Прозрачность уменьшается только ближе
	# к окончанию полёта.
	var fade_progress: float = clampf(
		(
			safe_progress
			- 0.72
		) / 0.28,
		0.0,
		1.0
	)

	flying_icon.modulate.a = lerpf(
		1.0,
		0.65,
		fade_progress
	)

func _get_counter_target_icon(
	counter_target: StringName
) -> TextureRect:
	match counter_target:
		&"health":
			return health_icon

		&"gold":
			return gold_icon

		&"keys":
			return key_icon

		_:
			push_warning(
				"Неизвестная цель анимации подбора: "
				+ String(counter_target)
			)

			return null

func _on_pickup_fly_finished(
	flying_icon: Sprite2D,
	target_icon: TextureRect
) -> void:
	if is_instance_valid(
		flying_icon
	):
		flying_icon.queue_free()

	_pulse_counter_icon(
		target_icon
	)

func _pulse_counter_icon(
	target_icon: TextureRect
) -> void:
	if not is_instance_valid(
		target_icon
	):
		return

	if counter_pulse_tweens.has(
		target_icon
	):
		var previous_tween: Tween = (
			counter_pulse_tweens[target_icon]
		)

		if (
			previous_tween != null
			and previous_tween.is_valid()
		):
			previous_tween.kill()

	target_icon.scale = Vector2.ONE

	var pulse_tween: Tween = create_tween()

	counter_pulse_tweens[target_icon] = (
		pulse_tween
	)

	pulse_tween.tween_property(
		target_icon,
		"scale",
		Vector2(
			1.25,
			1.25
		),
		0.1
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	pulse_tween.tween_property(
		target_icon,
		"scale",
		Vector2.ONE,
		0.14
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	pulse_tween.tween_callback(
		_on_counter_pulse_finished.bind(
			target_icon
		)
	)


func _on_counter_pulse_finished(
	target_icon: TextureRect
) -> void:
	counter_pulse_tweens.erase(
		target_icon
	)

func _connect_signals() -> void:
	if not GameManager.player_hp_changed.is_connected(
		_on_player_hp_changed
	):
		GameManager.player_hp_changed.connect(
			_on_player_hp_changed
		)

	if not GameManager.total_gold_changed.is_connected(
		_on_total_gold_changed
	):
		GameManager.total_gold_changed.connect(
			_on_total_gold_changed
		)

	if not GameManager.keys_changed.is_connected(
		_on_keys_changed
	):
		GameManager.keys_changed.connect(
			_on_keys_changed
		)


func _refresh_values() -> void:
	_set_health(
		GameManager.player_hp,
		GameManager.player_max_hp
	)

	_set_gold(
		GameManager.total_gold
	)

	_set_keys(
		GameManager.keys
	)


func _on_player_hp_changed(
	hp: int,
	max_hp: int
) -> void:
	_set_health(
		hp,
		max_hp
	)


func _on_total_gold_changed(
	value: int
) -> void:
	_set_gold(
		value
	)


func _on_keys_changed(
	value: int
) -> void:
	_set_keys(
		value
	)


func _set_health(
	hp: int,
	max_hp: int
) -> void:
	var safe_max_hp: int = maxi(
		max_hp,
		1
	)

	var safe_hp: int = clampi(
		hp,
		0,
		safe_max_hp
	)

	health_label.text = (
		str(safe_hp)
		+ "/"
		+ str(safe_max_hp)
	)


func _set_gold(
	value: int
) -> void:
	gold_label.text = str(
		maxi(value, 0)
	)


func _set_keys(
	value: int
) -> void:
	key_label.text = str(
		maxi(value, 0)
	)
