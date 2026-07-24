extends Node2D

@export var duration: float = 1.5          # длительность анимации
@export var rise_distance: float = 120.0  # высота подъёма
@export var scale_to: float = 1.8         # максимальный масштаб

@onready var icon = $Icon
@onready var name_label = $NameLabel
@onready var desc_label = $DescLabel

func _ready():
	z_index = 10  

func setup(
	item: ItemData,
	amount: int = 1
) -> void:
	if item == null:
		queue_free()
		return

	var safe_amount: int = maxi(
		amount,
		1
	)

	if item.icon != null:
		icon.texture = item.icon
		icon.visible = true
	else:
		icon.visible = false

	if safe_amount > 1:
		name_label.text = (
			item.name
			+ " ×"
			+ str(safe_amount)
		)
	else:
		name_label.text = item.name

	desc_label.text = item.description

	# Начальное состояние.
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"modulate:a",
		1.0,
		0.3
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE * scale_to,
		0.5
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"position:y",
		position.y - rise_distance,
		duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.3
	).set_delay(
		duration - 0.3
	)

	tween.tween_callback(
		queue_free
	).set_delay(duration)
