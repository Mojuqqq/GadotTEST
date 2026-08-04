extends "res://Scripts/Interactables/Pickups/PickupBase.gd"


func _apply_pickup() -> void:
	_play_counter_fly(
		&"gold"
	)

	GameManager.add_gold(
		amount
	)
