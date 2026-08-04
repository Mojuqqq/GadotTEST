extends "res://Scripts/Interactables/Pickups/PickupBase.gd"


func _on_body_entered(
	body: Node2D
) -> void:
	if is_collected:
		return

	if not body.is_in_group(
		&"Player"
	):
		return

	if not body.has_method(
		&"receive_healing"
	):
		return

	var healed_amount: int = int(
		body.call(
			&"receive_healing",
			amount
		)
	)

	# При полном здоровье сердечко остаётся лежать.
	if healed_amount <= 0:
		return

	is_collected = true

	_play_counter_fly(
		&"health"
	)

	set_deferred(
		&"monitoring",
		false
	)

	if collision_shape != null:
		collision_shape.set_deferred(
			&"disabled",
			true
		)

	_play_collect_animation()
