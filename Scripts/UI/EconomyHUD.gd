extends CanvasLayer


@onready var gold_label: Label = %GoldLabel
@onready var key_label: Label = %KeyLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_connect_economy_signals()
	_refresh_values()


func _connect_economy_signals() -> void:
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
	_set_gold(GameManager.total_gold)
	_set_keys(GameManager.keys)


func _on_total_gold_changed(value: int) -> void:
	_set_gold(value)


func _on_keys_changed(value: int) -> void:
	_set_keys(value)


func _set_gold(value: int) -> void:
	gold_label.text = str(maxi(value, 0))


func _set_keys(value: int) -> void:
	key_label.text = str(maxi(value, 0))
