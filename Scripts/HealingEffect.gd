extends Node2D


@onready var ground_ring: Sprite2D = (
	$GroundRing
)

@onready var burst = $Burst
@onready var rising = $Rising


func _ready() -> void:
	await get_tree().process_frame

	_play_ground_ring_pulse()

	if burst != null:
		burst.restart()

	if rising != null:
		rising.restart()

	var effect_duration: float = 1.1

	if burst != null:
		effect_duration = maxf(
			effect_duration,
			burst.lifetime
		)

	if rising != null:
		effect_duration = maxf(
			effect_duration,
			rising.lifetime
		)

	effect_duration += 0.25

	await get_tree().create_timer(
		effect_duration
	).timeout

	queue_free()


func _play_ground_ring_pulse() -> void:
	if ground_ring == null:
		return

	ground_ring.modulate.a = 0.0
	ground_ring.scale = Vector2(
		0.85,
		0.85
	)

	var tween: Tween = create_tween()

	# Первый мягкий вход
	tween.tween_property(
		ground_ring,
		"modulate:a",
		0.75,
		0.12
	)

	tween.parallel().tween_property(
		ground_ring,
		"scale",
		Vector2(1.0, 1.0),
		0.12
	)

	# Небольшая пульсация
	tween.tween_property(
		ground_ring,
		"modulate:a",
		0.55,
		0.16
	)

	tween.parallel().tween_property(
		ground_ring,
		"scale",
		Vector2(1.08, 1.08),
		0.16
	)

	tween.tween_property(
		ground_ring,
		"modulate:a",
		0.75,
		0.16
	)

	tween.parallel().tween_property(
		ground_ring,
		"scale",
		Vector2(0.96, 0.96),
		0.16
	)

	tween.tween_property(
		ground_ring,
		"modulate:a",
		0.45,
		0.18
	)

	tween.parallel().tween_property(
		ground_ring,
		"scale",
		Vector2(1.1, 1.1),
		0.18
	)

	# Затухание
	tween.tween_property(
		ground_ring,
		"modulate:a",
		0.0,
		0.22
	)

	tween.parallel().tween_property(
		ground_ring,
		"scale",
		Vector2(1.18, 1.18),
		0.22
	)
