extends Node2D


signal finished(instance: Node)


# =========================================================
# СОСТОЯНИЯ
# =========================================================

enum State {
	WARNING,
	FALLING,
	IMPACT
}


# =========================================================
# ПАРАМЕТРЫ ПАДЕНИЯ
# =========================================================

@export_group("Fall")

# Сколько времени игрок видит маркер до начала падения.
@export_range(0.05, 5.0, 0.05)
var warning_duration: float = 0.5

# Время самого падения.
@export_range(0.05, 3.0, 0.05)
var fall_duration: float = 0.45

# Высота, с которой появляется мини-омлет.
@export_range(50.0, 1500.0, 10.0)
var fall_height: float = 600.0

# Сколько времени мини-омлет остаётся после удара.
@export_range(0.05, 3.0, 0.05)
var impact_lifetime: float = 0.3


# =========================================================
# УРОН
# =========================================================

@export_group("Impact")

@export_range(1, 20, 1)
var landing_damage: int = 1

@export_range(10.0, 300.0, 5.0)
var landing_radius: float = 55.0


# =========================================================
# СОСТОЯНИЕ
# =========================================================

var current_state: int = State.WARNING
var state_elapsed: float = 0.0

var damage_dealt: bool = false
var is_finished: bool = false

var base_visual_position: Vector2 = Vector2.ZERO
var base_visual_scale: Vector2 = Vector2.ONE

var base_marker_scale: Vector2 = Vector2.ONE


# =========================================================
# УЗЛЫ
# =========================================================

@onready var visual: Node2D = (
	get_node_or_null("Sprite2D") as Node2D
)

@onready var body_collision: CollisionShape2D = (
	get_node_or_null("CollisionShape2D")
	as CollisionShape2D
)

@onready var landing_marker: Node2D = (
	get_node_or_null("LandingMarker") as Node2D
)


# =========================================================
# ИНИЦИАЛИЗАЦИЯ
# =========================================================

func _ready() -> void:
	# Мини-омлет является атакой, а не обычным врагом.
	remove_from_group("Enemies")

	if visual != null:
		base_visual_position = visual.position
		base_visual_scale = visual.scale

		visual.visible = false

	if landing_marker != null:
		base_marker_scale = landing_marker.scale
		landing_marker.visible = true

	_set_collision_enabled(false)

	current_state = State.WARNING
	state_elapsed = 0.0


# =========================================================
# ОСНОВНОЙ ЦИКЛ
# =========================================================

func _process(
	delta: float
) -> void:
	if is_finished:
		return

	match current_state:
		State.WARNING:
			_process_warning(delta)

		State.FALLING:
			_process_falling(delta)

		State.IMPACT:
			_process_impact(delta)


# =========================================================
# ПРЕДУПРЕЖДЕНИЕ
# =========================================================

func _process_warning(
	delta: float
) -> void:
	state_elapsed += delta

	_update_marker_pulse(
		2.5,
		0.08
	)

	if state_elapsed >= warning_duration:
		_begin_falling()


# =========================================================
# ПАДЕНИЕ
# =========================================================

func _begin_falling() -> void:
	current_state = State.FALLING
	state_elapsed = 0.0

	if visual != null:
		visual.visible = true
		visual.scale = base_visual_scale

		visual.position = (
			base_visual_position
			+ Vector2(
				0.0,
				-fall_height
			)
		)


func _process_falling(
	delta: float
) -> void:
	state_elapsed += delta

	var progress: float = clampf(
		state_elapsed / maxf(fall_duration, 0.01),
		0.0,
		1.0
	)

	# Чем ближе к земле, тем быстрее падение.
	var eased_progress: float = progress * progress

	if visual != null:
		visual.position = (
			base_visual_position
			+ Vector2(
				0.0,
				-fall_height
				* (1.0 - eased_progress)
			)
		)

	_update_marker_pulse(
		5.0,
		0.12
	)

	if progress >= 1.0:
		_impact()


# =========================================================
# УДАР
# =========================================================

func _impact() -> void:
	current_state = State.IMPACT
	state_elapsed = 0.0

	if landing_marker != null:
		landing_marker.visible = false
		landing_marker.scale = base_marker_scale

	if visual != null:
		visual.position = base_visual_position

		visual.scale = Vector2(
			base_visual_scale.x * 1.3,
			base_visual_scale.y * 0.7
		)

	if not damage_dealt:
		damage_dealt = true
		_deal_landing_damage()


func _process_impact(
	delta: float
) -> void:
	state_elapsed += delta

	var progress: float = clampf(
		state_elapsed / maxf(impact_lifetime, 0.01),
		0.0,
		1.0
	)

	if visual != null:
		visual.scale = Vector2(
			base_visual_scale.x * lerpf(
				1.3,
				1.0,
				progress
			),
			base_visual_scale.y * lerpf(
				0.7,
				1.0,
				progress
			)
		)

	if progress >= 1.0:
		_finish()


# =========================================================
# НАНЕСЕНИЕ УРОНА
# =========================================================

func _deal_landing_damage() -> void:
	var target_groups: Array[StringName] = [
		&"Player",
		&"Companions"
	]

	var damaged_targets: Array[Node] = []

	for group_name in target_groups:
		for candidate in get_tree().get_nodes_in_group(
			group_name
		):
			if not is_instance_valid(candidate):
				continue

			if candidate.is_queued_for_deletion():
				continue

			if not candidate.has_method("take_damage"):
				continue

			var target := candidate as Node2D

			if target == null:
				continue

			if damaged_targets.has(target):
				continue

			var distance: float = (
				global_position.distance_to(
					target.global_position
				)
			)

			if distance > landing_radius:
				continue

			damaged_targets.append(target)

			target.take_damage(
				landing_damage
			)


# =========================================================
# МАРКЕР
# =========================================================

func _update_marker_pulse(
	speed: float,
	strength: float
) -> void:
	if landing_marker == null:
		return

	var pulse: float = (
		1.0
		+ sin(
			state_elapsed * TAU * speed
		) * strength
	)

	landing_marker.scale = (
		base_marker_scale * pulse
	)


# =========================================================
# КОЛЛИЗИЯ
# =========================================================

func _set_collision_enabled(
	enabled: bool
) -> void:
	if body_collision == null:
		return

	body_collision.set_deferred(
		"disabled",
		not enabled
	)


# =========================================================
# ЗАВЕРШЕНИЕ
# =========================================================

func _finish() -> void:
	if is_finished:
		return

	is_finished = true

	finished.emit(self)

	queue_free()
