extends Node2D
class_name RewardPopup

signal animation_finished

@export var appear_duration: float = 0.25
@export var hold_duration: float = 0.8
@export var fade_duration: float = 0.7

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

func _debug_fade_started() -> void:
	print(
		"[VICTORY_TIMING] fade started: ",
		Time.get_ticks_msec(),
		" ms"
	)


func _debug_fade_finished() -> void:
	print(
		"[VICTORY_TIMING] fade finished: ",
		Time.get_ticks_msec(),
		" ms"
	)

func setup(
	item: ItemData,
	amount: int = 1
) -> void:
	if item == null:
		print(
			"[VICTORY_TIMING] popup setup: ",
			Time.get_ticks_msec(),
			" ms"
		)
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

	tween.tween_callback(
		_debug_fade_started
	)

	# Основная видимая часть исчезновения.
	# К её концу награда уже практически не видна.
	var visible_fade_duration: float = (
		fade_duration * 0.8
	)

	var fade_tail_duration: float = (
		fade_duration - visible_fade_duration
	)

	tween.set_parallel(true)

	tween.tween_property(
		self,
		"modulate:a",
		0.05,
		visible_fade_duration
	)

	tween.tween_property(
		self,
		"position",
		end_position,
		visible_fade_duration
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN
	)

	tween.set_parallel(false)

	# Визуально награда уже исчезла —
	# сразу разрешаем показ ДО победы.
	tween.tween_callback(
		animation_finished.emit
	)

	# Завершаем последние почти невидимые
	# 5% прозрачности уже под окном победы.
	tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_tail_duration
	)

	tween.tween_callback(
		queue_free
	)
