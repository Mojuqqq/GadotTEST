extends "res://Scripts/Interactables/Pickups/PickupBase.gd"


func _apply_pickup() -> void:
	_play_counter_fly(
		&"gold"
	)

	GameManager.add_gold(
		amount
	)
	
	AudioManager.play_world_sfx(
		&"coin_pickup",
		global_position,
		-10.0,
		0.98,
		1.08
	)
