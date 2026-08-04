extends BaseEnemy
class_name BaseBoss


@export_group("Boss Loot")

@export_range(1, 10, 1)
var boss_gold_pickup_count: int = 5

@export_range(1, 20, 1)
var boss_min_gold_per_pickup: int = 2

@export_range(1, 20, 1)
var boss_max_gold_per_pickup: int = 4

@export_range(20.0, 250.0, 5.0)
var boss_loot_scatter_radius: float = 100.0


func _ready() -> void:
	# Боссов будем масштабировать отдельно.
	use_floor_hp_scaling = false
	# Босс не может стать обычным носителем
	# гарантированного ключа этажа.
	can_carry_guaranteed_key = false

	super()

	add_to_group(&"Bosses")
	add_to_group(&"Enemies")


func _drop_loot() -> void:
	if loot_dropped:
		return

	loot_dropped = true

	_drop_guaranteed_boss_key()
	_drop_boss_gold()


func _drop_guaranteed_boss_key() -> void:
	var key_offset := Vector2(
		0.0,
		-boss_loot_scatter_radius
	)

	_spawn_pickup(
		key_pickup_scene,
		1,
		"ключ босса",
		key_offset
	)


func _drop_boss_gold() -> void:
	var minimum_gold: int = mini(
		boss_min_gold_per_pickup,
		boss_max_gold_per_pickup
	)

	var maximum_gold: int = maxi(
		boss_min_gold_per_pickup,
		boss_max_gold_per_pickup
	)

	minimum_gold = maxi(
		minimum_gold,
		1
	)

	maximum_gold = maxi(
		maximum_gold,
		1
	)

	var pickup_count: int = maxi(
		boss_gold_pickup_count,
		1
	)

	for index in range(pickup_count):
		var angle: float = (
			TAU
			* float(index)
			/ float(pickup_count)
		)

		var radial_distance: float = randf_range(
			boss_loot_scatter_radius * 0.55,
			boss_loot_scatter_radius
		)

		var gold_offset: Vector2 = (
			Vector2.RIGHT.rotated(angle)
			* radial_distance
		)

		var gold_amount: int = randi_range(
			minimum_gold,
			maximum_gold
		)

		_spawn_pickup(
			gold_pickup_scene,
			gold_amount,
			"золото босса",
			gold_offset
		)
