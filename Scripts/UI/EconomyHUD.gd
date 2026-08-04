extends CanvasLayer


@onready var health_label: Label = %HealthLabel
@onready var gold_label: Label = %GoldLabel
@onready var key_label: Label = %KeyLabel
@onready var health_icon: TextureRect = %HealthIcon
@onready var gold_icon: TextureRect = %GoldIcon
@onready var key_icon: TextureRect = %KeyIcon

const FLYING_ICON_SIZE: float = 32.0

const PICKUP_FLY_FIRST_DURATION: float = 0.16
const PICKUP_FLY_SECOND_DURATION: float = 0.34

const PICKUP_FLY_HEIGHT: float = 45.0


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
		CanvasItem.TEXTURE_FILTER_NEAREST
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

	# Сначала предмет немного поднимается,
	# затем ускоряется к счётчику.
	var middle_position: Vector2 = (
		start_position.lerp(
			target_position,
			0.35
		)
		+ Vector2(
			0.0,
			-PICKUP_FLY_HEIGHT
		)
	)

	var fly_tween: Tween = create_tween()

	fly_tween.tween_property(
		flying_icon,
		"position",
		middle_position,
		PICKUP_FLY_FIRST_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	fly_tween.tween_property(
		flying_icon,
		"position",
		target_position,
		PICKUP_FLY_SECOND_DURATION
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	fly_tween.parallel().tween_property(
		flying_icon,
		"scale",
		final_scale,
		PICKUP_FLY_SECOND_DURATION
	)

	fly_tween.parallel().tween_property(
		flying_icon,
		"modulate:a",
		0.7,
		PICKUP_FLY_SECOND_DURATION
	)

	fly_tween.tween_callback(
		_on_pickup_fly_finished.bind(
			flying_icon,
			target_icon
		)
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
