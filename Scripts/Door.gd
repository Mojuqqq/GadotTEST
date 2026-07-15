extends Area2D

var linked_door: Area2D = null
var target_room_node: Node2D = null

# Флаг, открыта ли дверь (по умолчанию закрыта)
var is_open: bool = false

func _ready():
	input_pickable = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Player") and is_open:
		var main = get_tree().current_scene
		if main and main.has_method("move_player_to_room"):
			main.move_player_to_room(target_room_node, global_position)

# Метод для открытия/закрытия двери
func set_open(open: bool):
	is_open = open
	# Можно также визуально менять цвет или спрайт
	modulate = Color.GREEN if open else Color.RED  # для наглядности
