extends "res://Scripts/Interactables/Pickups/PickupBase.gd"


func _apply_pickup() -> void:
	_play_counter_fly(
		&"keys"
	)

	GameManager.add_keys(
		amount
	)
