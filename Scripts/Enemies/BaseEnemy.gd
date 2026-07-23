extends CharacterBody2D
class_name BaseEnemy

# === Сигналы ===
signal died(victim: Node)

# === Параметры здоровья ===
@export var hp: int = 3
@export var max_hp: int = 3

# === Состояние ===
var is_dead: bool = false
var room_limits: Rect2
var hp_bar: ProgressBar = null
var is_active: bool = false

func _ready():
	# Создаём HP bar
	hp_bar = ProgressBar.new()
	hp_bar.min_value = 0
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_bar.size = Vector2(60, 10)
	hp_bar.position = Vector2(-30, -50)  # над врагом
	hp_bar.show_percentage = false
	# Стиль (можно настроить)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	hp_bar.add_theme_stylebox_override("background", style)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.0, 0.8, 0.0)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	add_child(hp_bar)
	hp_bar.visible = false  # скрыт, пока комната не активируется

func set_room_limits(limits: Rect2):
	room_limits = limits

func set_active(active: bool) -> void:
	is_active = active

	if active:
		# Сначала возвращаем обработку узла и его детей.
		process_mode = Node.PROCESS_MODE_INHERIT

		set_process(true)
		set_physics_process(true)

		_set_detection_areas_enabled(true)

	else:
		velocity = Vector2.ZERO

		# Отключаем Area2D, чтобы враг не замечал игрока
		# через стену или из соседней комнаты.
		_set_detection_areas_enabled(false)

		set_process(false)
		set_physics_process(false)

		# Останавливает обработку дочерних Timer,
		# Area2D и других узлов врага.
		process_mode = Node.PROCESS_MODE_DISABLED

	if hp_bar != null:
		hp_bar.visible = active

func take_damage(amount: int):
	if is_dead:
		return
	hp -= amount
	if hp < 0:
		hp = 0
	if hp_bar:
		hp_bar.value = hp
		# Меняем цвет в зависимости от здоровья
		var fill_style = StyleBoxFlat.new()
		if hp <= max_hp * 0.25:
			fill_style.bg_color = Color.RED
		elif hp <= max_hp * 0.5:
			fill_style.bg_color = Color.YELLOW
		else:
			fill_style.bg_color = Color.GREEN
		hp_bar.add_theme_stylebox_override("fill", fill_style)
	if hp <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	if hp_bar:
		hp_bar.queue_free()
		hp_bar = null
	died.emit(self)
	queue_free()
	
func _set_detection_areas_enabled(
	enabled: bool
) -> void:
	var area_nodes := find_children(
		"*",
		"Area2D",
		true,
		false
	)

	for node in area_nodes:
		var area := node as Area2D

		if area == null:
			continue

		area.set_deferred(
			"monitoring",
			enabled
		)
