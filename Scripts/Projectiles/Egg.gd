extends Area2D


# =========================================================
# ПАРАМЕТРЫ
# =========================================================

@export var speed: float = 700.0
@export var max_range: float = 300.0

@export_group("Projectile textures")

@export var golden_texture: Texture2D = preload(
	"res://Assets/Art/Projectiles/Golden_Egg.png"
)

@export var rotten_texture: Texture2D = preload(
	"res://Assets/Art/Projectiles/Rotten_Egg.png"
)


var direction: Vector2 = Vector2.ZERO
var damage: int = 1

var total_distance_traveled: float = 0.0
var hit: bool = false
var deactivation_requested: bool = false

# Относится только к конкретному выстрелу.
var creates_poison_cloud: bool = false


signal returned_to_pool(egg)


@onready var sprite: Sprite2D = $Sprite2D


const POISON_CLOUD_SCENE: PackedScene = preload(
	"res://Scenes/Effects/PoisonCloud.tscn"
)


var normal_texture: Texture2D = null
var normal_sprite_scale: Vector2 = Vector2.ONE


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	normal_texture = sprite.texture
	normal_sprite_scale = sprite.scale

	rotation = direction.angle()

	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)


# =========================================================
# ДВИЖЕНИЕ
# =========================================================

func _physics_process(delta: float) -> void:
	var step: float = speed * delta

	if step <= 0.0:
		return

	global_position += direction * step
	total_distance_traveled += step

	if direction != Vector2.ZERO:
		rotation = direction.angle()

	if total_distance_traveled >= max_range:
		deactivate()


# =========================================================
# СТОЛКНОВЕНИЯ
# =========================================================

func _on_body_entered(body: Node) -> void:
	if hit:
		return

	if body.is_in_group("Player"):
		return

	hit = true

	set_deferred(
		"monitoring",
		false
	)

	# Попадание во врага.
	if body.has_method("take_damage"):
		body.take_damage(damage)

		if creates_poison_cloud:
			call_deferred(
				"create_poison_cloud",
				global_position,
				damage
			)

		deactivate()
		return

	# Попадание в стену.
	if (
		body is StaticBody2D
		or body is TileMapLayer
		or body is TileMap
		or body.is_in_group("Walls")
	):
		deactivate()
		return

	# Любой другой объект.
	deactivate()


# =========================================================
# ЯДОВИТОЕ ОБЛАКО
# =========================================================

func create_poison_cloud(
	pos: Vector2,
	damage_amount: int
) -> void:
	var cloud: Node2D = (
		POISON_CLOUD_SCENE.instantiate()
		as Node2D
	)

	if cloud == null:
		push_error(
			"Не удалось создать PoisonCloud."
		)
		return

	get_tree().current_scene.add_child(
		cloud
	)

	cloud.global_position = pos

	if cloud.has_method("setup"):
		cloud.setup(
			damage_amount
		)

	print(
		"Создана ядовитая лужа."
	)


# =========================================================
# АКТИВАЦИЯ СНАРЯДА
# =========================================================

func activate(
	pos: Vector2,
	dir: Vector2,
	damage_amount: int,
	rotten_enabled: bool = false,
	golden_enabled: bool = false
) -> void:
	global_position = pos
	direction = dir.normalized()
	damage = damage_amount

	creates_poison_cloud = rotten_enabled

	hit = false
	deactivation_requested = false
	total_distance_traveled = 0.0

	_apply_projectile_visual(
		rotten_enabled,
		golden_enabled
	)

	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

	set_deferred(
		"monitoring",
		true
	)


# =========================================================
# ВИЗУАЛ СНАРЯДА
# =========================================================

func _apply_projectile_visual(
	rotten_enabled: bool,
	golden_enabled: bool
) -> void:
	# Тухлое яйцо имеет визуальный приоритет.
	# При этом бонус урона золотого яйца сохраняется
	# через характеристики игрока.
	if rotten_enabled:
		_set_projectile_texture(
			rotten_texture
		)
		return

	if golden_enabled:
		_set_projectile_texture(
			golden_texture
		)
		return

	_set_projectile_texture(
		normal_texture
	)


func _set_projectile_texture(
	texture: Texture2D
) -> void:
	if sprite == null:
		return

	sprite.modulate = Color.WHITE
	sprite.scale = normal_sprite_scale

	if texture == null:
		sprite.texture = normal_texture
		return

	sprite.texture = texture

	# Подгоняем большую иконку предмета
	# под размер обычного снаряда.
	if normal_texture == null:
		return

	var normal_size: Vector2 = (
		normal_texture.get_size()
	)

	var new_size: Vector2 = (
		texture.get_size()
	)

	if (
		normal_size.x <= 0.0
		or normal_size.y <= 0.0
		or new_size.x <= 0.0
		or new_size.y <= 0.0
	):
		return

	var fit_multiplier: float = minf(
		normal_size.x / new_size.x,
		normal_size.y / new_size.y
	)

	sprite.scale = (
		normal_sprite_scale
		* fit_multiplier
	)


# Оставляем для совместимости со старым кодом.
func set_golden() -> void:
	_apply_projectile_visual(
		false,
		true
	)


# =========================================================
# ВОЗВРАЩЕНИЕ В ПУЛ
# =========================================================

func deactivate() -> void:
	if deactivation_requested:
		return

	deactivation_requested = true

	call_deferred(
		"_deactivate_now"
	)


func _deactivate_now() -> void:
	visible = false
	monitoring = false
	process_mode = Node.PROCESS_MODE_DISABLED

	creates_poison_cloud = false

	returned_to_pool.emit(self)


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	pass
