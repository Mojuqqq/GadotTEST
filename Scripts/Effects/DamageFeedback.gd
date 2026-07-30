extends Node2D
class_name DamageFeedback


@onready var damage_label: Label = %DamageLabel


@export_group("Animation")

@export_range(0.1, 2.0, 0.05)
var duration: float = 0.75

@export_range(10.0, 200.0, 5.0)
var rise_distance: float = 80.0

@export_range(0.0, 100.0, 2.0)
var horizontal_scatter: float = 24.0

@export_range(0.1, 2.0, 0.05)
var start_scale: float = 0.65

@export_range(0.1, 2.0, 0.05)
var peak_scale: float = 1.15


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_damage(
	amount: int
) -> void:
	_show_feedback(
		amount,
		false
	)


func show_heal(
	amount: int
) -> void:
	_show_feedback(
		amount,
		true
	)


func _show_feedback(
	amount: int,
	is_heal: bool
) -> void:
	if amount <= 0:
		queue_free()
		return

	damage_label.text = (
		("+" if is_heal else "-")
		+ str(amount)
	)

	var feedback_color: Color = (
		Color(
			0.45,
			1.0,
			0.45,
			1.0
		)
		if is_heal
		else Color(
			1.0,
			0.5766771,
			0.53013307,
			1.0
		)
	)

	damage_label.add_theme_color_override(
		&"font_color",
		feedback_color
	)

	var start_position: Vector2 = (
		position
		+ Vector2(
			randf_range(
				-horizontal_scatter,
				horizontal_scatter
			),
			0.0
		)
	)

	var end_position: Vector2 = (
		start_position
		+ Vector2(
			0.0,
			-rise_distance
		)
	)

	position = start_position
	scale = Vector2.ONE * start_scale
	modulate.a = 0.0

	var fade_duration: float = minf(
		0.22,
		duration
	)

	var fade_delay: float = maxf(
		duration - fade_duration,
		0.0
	)

	var tween: Tween = create_tween()

	tween.set_parallel(
		true
	)

	tween.tween_property(
		self,
		"position",
		end_position,
		duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"modulate:a",
		1.0,
		0.08
	)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	).set_delay(
		fade_delay
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE * peak_scale,
		0.1
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.16
	).set_delay(
		0.1
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.set_parallel(
		false
	)

	tween.tween_callback(
		queue_free
	)
