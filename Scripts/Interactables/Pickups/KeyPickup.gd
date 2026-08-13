extends "res://Scripts/Interactables/Pickups/PickupBase.gd"


func _apply_pickup() -> void:
	_play_counter_fly(
		&"keys"
	)

	GameManager.add_keys(
		amount
	)
	
	AudioManager.play_world_sfx(
		&"key_pickup",
		global_position,
		-10.0,
		0.98,
		1.04
	)
