extends Node2D
class_name RewardPopup

signal animation_finished

@export var appear_duration: float = 0.25
@export var hold_duration: float = 1.8
@export var fade_duration: float = 1.0

@export var appear_rise_distance: float = 16.0
@export var fade_rise_distance: float = 24.0

@export var start_scale: float = 0.75
@export var scale_to: float = 1.25


@onready var icon: Sprite2D = $Icon
@onready var name_label: Label = $NameLabel
@onready var desc_label: Label = $DescLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		icon.texture = null
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
	desc_label.visible = (
		not item.description.is_empty()
	)

	var start_position: Vector2 = position

	var visible_position: Vector2 = (
		start_position
		+ Vector2(
			0.0,
			-appear_rise_distance
		)
	)

	var end_position: Vector2 = (
		visible_position
		+ Vector2(
			0.0,
			-fade_rise_distance
		)
	)

	scale = Vector2.ONE * start_scale
	modulate.a = 0.0

	var tween := create_tween()

	# Плавное появление.
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"modulate:a",
		1.0,
		appear_duration
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE * scale_to,
		appear_duration
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"position",
		visible_position,
		appear_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	# Останавливаем уведомление,
	# чтобы игрок успел прочитать текст.
	tween.set_parallel(false)
	tween.tween_interval(
		hold_duration
	)

	# Плавное исчезновение.
	tween.set_parallel(true)

	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	)

	tween.tween_property(
		self,
		"position",
		end_position,
		fade_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	tween.set_parallel(false)

	# Сначала сообщаем, что вся анимация,
	# включая плавное исчезновение, завершена.
	tween.tween_callback(
		animation_finished.emit
	)

	# Затем удаляем уведомление.
	tween.tween_callback(
		queue_free
	)
