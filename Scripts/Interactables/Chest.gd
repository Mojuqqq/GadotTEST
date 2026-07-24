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

	if GameManager.has_key():
		interaction_label.text = "[E] Открыть"
	else:
		interaction_label.text = "Нужен ключ"

	interaction_label.visible = true


func _try_open_chest() -> void:
	if is_opened:
		return

	if not GameManager.has_key():
		_show_no_key_feedback()
		return

	var key_was_used: bool = GameManager.use_key()

	if not key_was_used:
		_show_no_key_feedback()
		return

	open()


func open() -> void:
	if is_opened:
		return

	is_opened = true
	player_near = false
	interaction_label.visible = false

	if item != null:
		item.apply.call(
			GameManager.player_stats,
			GameManager
		)

		print(
			"Получен предмет: ",
			item.name
		)

		GameManager.emit_signal(
			"stats_changed",
			GameManager.player_stats
		)

		show_reward()

	queue_free()


func show_reward() -> void:
	var popup_scene: PackedScene = preload(
		"res://Scenes/UI/Reward_popup.tscn"
	)

	var popup: Node = popup_scene.instantiate()

	get_tree().current_scene.add_child(popup)

	popup.global_position = (
		global_position
		+ Vector2(0, -40)
	)

	popup.setup(item)


func _show_no_key_feedback() -> void:
	interaction_label.text = "Нужен ключ!"
	interaction_label.visible = true

	print(
		"Для открытия сундука нужен ключ"
	)
