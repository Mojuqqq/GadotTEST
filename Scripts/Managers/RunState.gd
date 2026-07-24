extends Node


signal player_hp_changed(hp: int, max_hp: int)
signal stats_changed(stats)


const DEFAULT_MAX_HP := 5


var player: Node2D = null
var player_stats = null

var player_hp: int = DEFAULT_MAX_HP
var player_max_hp: int = DEFAULT_MAX_HP


# =========================================================
# РЕГИСТРАЦИЯ ИГРОКА
# =========================================================

func set_player(player_node: Node2D) -> void:
	player = player_node

	if player_stats != null:
		player_max_hp = player_stats.max_hp
	else:
		player_max_hp = DEFAULT_MAX_HP
		player_hp = player_max_hp

	player_hp_changed.emit(
		player_hp,
		player_max_hp
	)

	_apply_speed_to_player()


func unregister_player(player_node: Node) -> void:
	if player == player_node:
		player = null


# =========================================================
# ХАРАКТЕРИСТИКИ ИГРОКА
# =========================================================

func set_player_stats(stats) -> void:
	player_stats = stats

	player_max_hp = stats.max_hp
	player_hp = stats.max_hp

	player_hp_changed.emit(
		player_hp,
		player_max_hp
	)

	stats_changed.emit(player_stats)

	_apply_speed_to_player()


func upgrade_stat(
	stat_name: String,
	amount: float
) -> void:
	if player_stats == null:
		return

	match stat_name:
		"max_hp":
			player_stats.max_hp += int(amount)

			player_max_hp = player_stats.max_hp
			player_hp = mini(
				player_hp + int(amount),
				player_max_hp
			)

			player_hp_changed.emit(
				player_hp,
				player_max_hp
			)

		"damage":
			player_stats.damage += int(amount)

		"speed":
			player_stats.speed += amount
			_apply_speed_to_player()

		"fire_rate":
			player_stats.fire_rate = maxf(
				0.05,
				player_stats.fire_rate - amount
			)

		"egg_speed":
			player_stats.egg_speed += amount

		_:
			push_warning(
				"Неизвестная характеристика: "
				+ stat_name
			)
			return

	stats_changed.emit(player_stats)


# =========================================================
# ЗДОРОВЬЕ
# =========================================================

func take_damage(amount: int) -> bool:
	if amount <= 0:
		return false

	player_hp = maxi(
		player_hp - amount,
		0
	)

	player_hp_changed.emit(
		player_hp,
		player_max_hp
	)

	# Возвращаем true, если игрок умер.
	# GameManager сам запустит Game Over.
	return player_hp <= 0


func heal(amount: int) -> void:
	if amount <= 0:
		return

	player_hp = mini(
		player_hp + amount,
		player_max_hp
	)

	player_hp_changed.emit(
		player_hp,
		player_max_hp
	)


func increase_max_hp(amount: int) -> void:
	if amount <= 0:
		return

	if player_stats == null:
		return

	player_stats.max_hp += amount

	player_max_hp = player_stats.max_hp
	player_hp = mini(
		player_hp + amount,
		player_max_hp
	)

	player_hp_changed.emit(
		player_hp,
		player_max_hp
	)

	stats_changed.emit(player_stats)


# =========================================================
# СБРОС СОСТОЯНИЯ
# =========================================================

func reset() -> void:
	player = null
	player_stats = null

	player_hp = DEFAULT_MAX_HP
	player_max_hp = DEFAULT_MAX_HP


# =========================================================
# ВНУТРЕННИЕ МЕТОДЫ
# =========================================================

func _apply_speed_to_player() -> void:
	if player_stats == null:
		return

	if not is_instance_valid(player):
		return

	if player.is_queued_for_deletion():
		return

	if player.has_method("update_speed"):
		player.update_speed(
			player_stats.speed
		)
