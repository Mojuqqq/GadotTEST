extends Area2D

@export var item: ItemData
var is_opened: bool = false
var player_near: bool = false
@export var textures: Array[Texture2D]

@onready var sprite = $Sprite2D   
@onready var interaction_label = $InteractionLabel 

func _ready():
# Выбираем случайную текстуру
	if textures.size() > 0:
		var random_texture = textures[randi_range(0, textures.size() - 1)]
		sprite.texture = random_texture
	
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
	interaction_label.visible = false
	if item:
		item.apply.call(GameManager.player_stats, GameManager)
		print("Получен предмет: ", item.name)
		GameManager.emit_signal("stats_changed", GameManager.player_stats)
		
		# Показываем награду
		show_reward()
	queue_free()

func show_reward():
	var popup_scene = preload("res://Scenes/UI/Reward_popup.tscn")
	var popup = popup_scene.instantiate()
	# Добавляем в корень сцены (можно в UI, но лучше в Main, чтобы не перекрывать UI)
	get_tree().current_scene.add_child(popup)
	# Позиционируем над сундуком
	popup.global_position = global_position + Vector2(0, -40)
	popup.setup(item)
