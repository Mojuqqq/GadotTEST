extends CanvasLayer


@onready var health_label: Label = %HealthLabel
@onready var gold_label: Label = %GoldLabel
@onready var key_label: Label = %KeyLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_connect_signals()
	_refresh_values()


func _connect_signals() -> void:
	if not GameManager.player_hp_changed.is_connected(
		_on_player_hp_changed
	):
		GameManager.player_hp_changed.connect(
			_on_player_hp_changed
		)

	if not GameManager.total_gold_changed.is_connected(
		_on_total_gold_changed
	):
		GameManager.total_gold_changed.connect(
			_on_total_gold_changed
		)

	if not GameManager.keys_changed.is_connected(
		_on_keys_changed
	):
		GameManager.keys_changed.connect(
			_on_keys_changed
		)


func _refresh_values() -> void:
	_set_health(
		GameManager.player_hp,
		GameManager.player_max_hp
	)

	_set_gold(
		GameManager.total_gold
	)

	_set_keys(
		GameManager.keys
	)


func _on_player_hp_changed(
	hp: int,
	max_hp: int
) -> void:
	_set_health(
		hp,
		max_hp
	)


func _on_total_gold_changed(
	value: int
) -> void:
	_set_gold(
		value
	)


func _on_keys_changed(
	value: int
) -> void:
	_set_keys(
		value
	)


func _set_health(
	hp: int,
	max_hp: int
) -> void:
	var safe_max_hp: int = maxi(
		max_hp,
		1
	)

	var safe_hp: int = clampi(
		hp,
		0,
		safe_max_hp
	)

	health_label.text = (
		str(safe_hp)
		+ "/"
		+ str(safe_max_hp)
	)


func _set_gold(
	value: int
) -> void:
	gold_label.text = str(
		maxi(value, 0)
	)


func _set_keys(
	value: int
) -> void:
	key_label.text = str(
		maxi(value, 0)
	)
