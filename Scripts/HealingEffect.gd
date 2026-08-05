extends Node2D


@onready var burst: CPUParticles2D = (
	$Burst
)

@onready var rising: CPUParticles2D = (
	$Rising
)


func _ready() -> void:
	_configure_particles()

	await get_tree().process_frame


	burst.restart()
	rising.restart()

	var effect_duration: float = (
		maxf(
			burst.lifetime,
			rising.lifetime
		)
		+ 0.25
	)

	await get_tree().create_timer(
		effect_duration
	).timeout

	queue_free()

func _configure_particles() -> void:
	# Короткая вспышка во все стороны.
	burst.position = Vector2(
		0.0,
		-10.0
	)

	burst.local_coords = true

	burst.direction = Vector2.UP
	burst.spread = 180.0

	burst.initial_velocity_min = 70.0
	burst.initial_velocity_max = 120.0

	# Обязательно отключаем стандартную
	# гравитацию CPUParticles2D.
	burst.gravity = Vector2.ZERO

	burst.emission_shape = (
		CPUParticles2D.EMISSION_SHAPE_SPHERE
	)

	burst.emission_sphere_radius = 28.0

	burst.scale_amount_min = 0.8
	burst.scale_amount_max = 1.3

	# Лёгкое закручивание частиц.
	burst.tangential_accel_min = 20.0
	burst.tangential_accel_max = 50.0

	# Медленные частицы вокруг тела,
	# поднимающиеся вверх.
	rising.position = Vector2(
		0.0,
		-5.0
	)

	rising.local_coords = true

	rising.direction = Vector2.UP
	rising.spread = 35.0

	rising.initial_velocity_min = 30.0
	rising.initial_velocity_max = 60.0

	# Отрицательный Y в Godot — движение вверх.
	rising.gravity = Vector2(
		0.0,
		-10.0
	)

	rising.emission_shape = (
		CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	)

	rising.emission_rect_extents = Vector2(
		45.0,
		55.0
	)

	rising.scale_amount_min = 0.7
	rising.scale_amount_max = 1.1
