extends Area2D


@export var amount: int = 1

@export var bob_height: float = 4.0
@export var bob_duration: float = 0.7


@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)

@onready var pickup_sprite: Sprite2D = (
	$Sprite2D
)


var is_collected: bool = false
var idle_tween: Tween = null


func _ready() -> void:
	add_to_group("Pickups")

	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)

	_start_idle_animation()


func setup(new_amount: int) -> void:
	amount = maxi(new_amount, 1)


func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return

	if not body.is_in_group("Player"):
		return

	_collect()


func _collect() -> void:
	if is_collected:
		return

	is_collected = true

	set_deferred(
		"monitoring",
		false
	)

	if collision_shape != null:
		collision_shape.set_deferred(
			"disabled",
			true
		)

	_apply_pickup()
	_play_collect_animation()


func _apply_pickup() -> void:
	push_error(
		"Для предмета "
		+ name
		+ " не реализован метод _apply_pickup()"
	)


func _start_idle_animation() -> void:
	if pickup_sprite == null:
		return

	var start_y: float = pickup_sprite.position.y

	idle_tween = create_tween()
	idle_tween.set_loops()

	idle_tween.tween_property(
		pickup_sprite,
		"position:y",
		start_y - bob_height,
		bob_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)

	idle_tween.tween_property(
		pickup_sprite,
		"position:y",
		start_y,
		bob_duration
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_IN_OUT
	)


func _play_collect_animation() -> void:
	if idle_tween != null:
		idle_tween.kill()
		idle_tween = null

	if pickup_sprite == null:
		queue_free()
		return

	var collect_tween := create_tween()

	collect_tween.tween_property(
		pickup_sprite,
		"scale",
		Vector2.ZERO,
		0.16
	)

	collect_tween.parallel().tween_property(
		pickup_sprite,
		"modulate:a",
		0.0,
		0.16
	)

	collect_tween.tween_callback(
		queue_free
	)
