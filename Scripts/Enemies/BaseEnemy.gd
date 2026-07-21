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

func set_active(active: bool):
	is_active = active
	set_physics_process(active)
	if hp_bar:
		hp_bar.visible = active
		print("HP bar для ", name, " видимость: ", active)
	else:
		print("HP bar для ", name, " отсутствует!")

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
