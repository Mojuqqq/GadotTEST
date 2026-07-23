extends Area2D


var linked_door: Area2D = null
var target_room_node: Node2D = null

var is_open: bool = false


var blocker_body: StaticBody2D = null
var blocker_shape: CollisionShape2D = null


func _ready() -> void:
	input_pickable = false

	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)

	_create_physical_blocker()

	# При запуске дверь закрыта,
	# поэтому физический блокиратор включён.
	set_open(is_open)


# =========================================================
# ФИЗИЧЕСКИЙ БЛОКИРАТОР
# =========================================================

func _create_physical_blocker() -> void:
	var trigger_shape: CollisionShape2D = (
		get_node_or_null("CollisionShape2D")
		as CollisionShape2D
	)

	if trigger_shape == null:
		push_error(
			"У двери "
			+ name
			+ " отсутствует CollisionShape2D"
		)
		return

	if trigger_shape.shape == null:
		push_error(
			"У CollisionShape2D двери "
			+ name
			+ " не назначена Shape"
		)
		return

	blocker_body = StaticBody2D.new()
	blocker_body.name = "DoorBlocker"

	# Первый физический слой проекта — World.
	blocker_body.collision_layer = 1 << 0
	blocker_body.collision_mask = 0

	add_child(blocker_body)

	blocker_shape = CollisionShape2D.new()
	blocker_shape.name = "CollisionShape2D"

	# Используем ту же форму и положение,
	# что и у зоны перехода двери.
	blocker_shape.shape = trigger_shape.shape
	blocker_shape.transform = trigger_shape.transform

	blocker_body.add_child(blocker_shape)


# =========================================================
# ПЕРЕХОД
# =========================================================

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	if not is_open:
		print("Дверь закрыта")
		return

	if target_room_node == null:
		push_warning(
			"У двери "
			+ name
			+ " не назначена целевая комната"
		)
		return

	print(
		"Дверь открыта, переходим в ",
		target_room_node.name
	)

	var main := get_tree().current_scene

	if (
		main != null
		and main.has_method("move_player_to_room")
	):
		main.move_player_to_room(
			target_room_node,
			global_position
		)
	else:
		push_error(
			"Текущая сцена не имеет метода "
			+ "move_player_to_room()"
		)


# =========================================================
# ОТКРЫТИЕ И ЗАКРЫТИЕ
# =========================================================

func set_open(open: bool) -> void:
	is_open = open

	# Открытая дверь:
	# блокиратор отключён.
	#
	# Закрытая дверь:
	# блокиратор включён.
	if is_instance_valid(blocker_shape):
		blocker_shape.set_deferred(
			"disabled",
			is_open
		)

	modulate = (
		Color.GREEN
		if is_open
		else Color.RED
	)

	print(
		"Дверь ",
		name,
		" установлена в состояние: ",
		"открыта" if is_open else "закрыта"
	)
