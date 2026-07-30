extends "res://Scripts/Interactables/Pickups/PickupBase.gd"


func _apply_pickup() -> void:
	GameManager.add_keys(amount)
