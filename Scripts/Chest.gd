extends Area2D

@export var item: ItemData
var is_opened: bool = false
var player_near: bool = false

@onready var interaction_label = $InteractionLabel   # дочерний Label

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interaction_label.visible = false
	interaction_label.text = "[E] Открыть"

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_near = true
		interaction_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_near = false
		interaction_label.visible = false

func _process(_delta):
	if player_near and not is_opened and Input.is_action_just_pressed("interact"):
		open()

func open():
	if is_opened:
		return
	is_opened = true
	interaction_label.visible = false   # скрываем подсказку
	if item:
		item.apply.call(GameManager.player_stats, GameManager)
		print("Получен предмет: ", item.name)
		GameManager.emit_signal("stats_changed", GameManager.player_stats)
	# Удаляем сундук или делаем неактивным
	queue_free()
