extends Area2D


@export var item: ItemData
@export var textures: Array[Texture2D]


@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_label: Label = $InteractionLabel


var is_opened: bool = false
var player_near: bool = false


func _ready() -> void:
	# Выбираем случайную текстуру сундука.
	if textures.size() > 0:
		var random_texture: Texture2D = textures[
			randi_range(0, textures.size() - 1)
		]

		sprite.texture = random_texture

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if not GameManager.keys_changed.is_connected(
		_on_keys_changed
	):
		GameManager.keys_changed.connect(
			_on_keys_changed
		)

	interaction_label.visible = false
	interaction_label.text = "Нужен ключ"


func _process(_delta: float) -> void:
	if is_opened:
		return

	if not player_near:
		return

	if Input.is_action_just_pressed("interact"):
		_try_open_chest()


func _on_body_entered(body: Node2D) -> void:
	if is_opened:
		return

	if not body.is_in_group("Player"):
		return

	player_near = true
	_update_interaction_label()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return

	player_near = false
	interaction_label.visible = false


func _on_keys_changed(_key_count: int) -> void:
	if player_near and not is_opened:
		_update_interaction_label()


func _update_interaction_label() -> void:
	if is_opened:
		interaction_label.visible = false
		return

	if item == null:
		interaction_label.text = "Сундук пуст"
	elif not _has_inventory_space_for_item():
		interaction_label.text = "Стак заполнен"
	elif GameManager.has_key():
		interaction_label.text = "[E] Открыть"
	else:
		interaction_label.text = "Нужен ключ"

	interaction_label.visible = true

func _has_inventory_space_for_item() -> bool:
	if item == null:
		return false

	var current_amount: int = (
		GameManager.get_inventory_item_amount(
			item.id
		)
	)

	var max_amount: int = maxi(
		item.max_inventory_stack,
		1
	)

	return current_amount < max_amount

func _try_open_chest() -> void:
	if is_opened:
		return

	if not GameManager.has_key():
		_show_no_key_feedback()
		return

	if item == null:
		_show_feedback(
			"В сундуке отсутствует предмет."
		)
		return

	if not _has_inventory_space_for_item():
		_show_feedback(
			"Нельзя открыть: стак предмета заполнен."
		)
		return

	# Сначала добавляем предмет. Если операция
	# не удалась, ключ не расходуется.
	var result: Dictionary = (
		GameManager.add_item_to_inventory(item)
	)

	var success: bool = bool(
		result.get("success", false)
	)

	if not success:
		_show_feedback(
			str(
				result.get(
					"message",
					"Не удалось добавить предмет."
				)
			)
		)
		return

	var added_amount: int = int(
		result.get("added_amount", 0)
	)

	if added_amount <= 0:
		_show_feedback(
			"Предмет не был добавлен."
		)
		return

	var key_was_used: bool = (
		GameManager.use_key()
	)

	if not key_was_used:
		GameManager.remove_inventory_item(
			item.id,
			added_amount
		)

		_show_no_key_feedback()
		return

	open(added_amount)


func open(added_amount: int) -> void:
	if is_opened:
		return

	is_opened = true
	player_near = false
	interaction_label.visible = false

	print(
		"Получен предмет в инвентарь: ",
		item.name,
		" ×",
		added_amount
	)

	show_reward(added_amount)

	queue_free()


func show_reward(
	added_amount: int
) -> void:
	var popup_scene: PackedScene = preload(
		"res://Scenes/UI/Reward_popup.tscn"
	)

	var popup: Node = (
		popup_scene.instantiate()
	)

	if popup == null:
		push_warning(
			"Не удалось создать RewardPopup."
		)
		return

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		popup.queue_free()
		return

	current_scene.add_child(popup)

	if popup is Node2D:
		popup.global_position = (
			global_position
			+ Vector2(0, -40)
		)

	if popup.has_method("setup"):
		popup.call(
			"setup",
			item,
			added_amount
		)
	else:
		push_warning(
			"У RewardPopup отсутствует setup()."
		)

func _show_feedback(
	message: String
) -> void:
	interaction_label.text = message
	interaction_label.visible = true

	print(message)

func _show_no_key_feedback() -> void:
	interaction_label.text = "Нужен ключ!"
	interaction_label.visible = true

	print(
		"Для открытия сундука нужен ключ"
	)
