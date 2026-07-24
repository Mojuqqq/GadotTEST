extends "res://Scripts/Interactables/Pickups/PickupBase.gd"


func _apply_pickup() -> void:
	GameManager.add_gold(amount)

	print(
		"Подобрано золото: ",
		amount,
		". Золото текущего забега: ",
		GameManager.run_gold
	)
