extends CanvasLayer


const QUICK_SLOT_ACTION_PREFIX: String = "quick_slot_"


@onready var slots_container: HBoxContainer = (%SlotsContainer)
@onready var active_effects_container: HBoxContainer = (%ActiveEffectsContainer)


var slot_buttons: Array[Button] = []
var active_effect_cards: Dictionary = {}

var effect_refresh_accumulator: float = 0.0


const EFFECT_REFRESH_INTERVAL: float = 0.1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_create_slot_buttons()
	_connect_signals()
	_refresh_quick_bar()
	_refresh_active_effects()

	set_process(true)
	set_process_unhandled_input(true)

func _process(
	delta: float
) -> void:
	effect_refresh_accumulator += delta

	if (
		effect_refresh_accumulator
		< EFFECT_REFRESH_INTERVAL
	):
		return

	effect_refresh_accumulator = 0.0

	_refresh_active_effects()
	
# =========================================================
# СОЗДАНИЕ СЛОТОВ
# =========================================================

func _create_slot_buttons() -> void:
	_clear_container(
		slots_container
	)

	slot_buttons.clear()

	var slot_count: int = (
		GameManager.get_quick_slot_count()
	)

	for slot_index in range(slot_count):
		var button := Button.new()

		button.name = (
			"QuickSlot"
			+ str(slot_index + 1)
		)

		button.custom_minimum_size = Vector2(
			80.0,
			72.0
		)
		button.add_theme_constant_override("icon_max_width",32)

		button.expand_icon = false

		button.text = str(
			slot_index + 1
		)

		button.toggle_mode = true

		# Панель пока управляется только клавиатурой.
		button.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		button.focus_mode = (
			Control.FOCUS_NONE
		)

		# Для пиксельных иконок.
		button.texture_filter = (
			CanvasItem.TEXTURE_FILTER_NEAREST
		)

		slots_container.add_child(
			button
		)

		slot_buttons.append(
			button
		)


# =========================================================
# ВВОД
# =========================================================

func _unhandled_input(
	event: InputEvent
) -> void:
	if (
		event is InputEventKey
		and event.echo
	):
		return

	if get_tree().paused:
		return

	if (
		GameManager.state
		!= GameManager.GameState.PLAYING
	):
		return

	for slot_index in range(
		slot_buttons.size()
	):
		var action_name: String = (
			QUICK_SLOT_ACTION_PREFIX
			+ str(slot_index + 1)
		)

		if not event.is_action_pressed(
			action_name
		):
			continue

		get_viewport().set_input_as_handled()

		_activate_quick_slot(
			slot_index
		)

		return


func _activate_quick_slot(
	slot_index: int
) -> void:
	var result: Dictionary = (
		GameManager.use_quick_slot(
			slot_index
		)
	)

	var message: String = str(
		result.get(
			"message",
			"Не удалось использовать слот."
		)
	)

	if bool(
		result.get(
			"success",
			false
		)
	):
		print(message)
	else:
		print(
			"Быстрый слот ",
			slot_index + 1,
			": ",
			message
		)

	_refresh_quick_bar()


# =========================================================
# ОБНОВЛЕНИЕ UI
# =========================================================

func _refresh_quick_bar() -> void:
	var entries: Array[Dictionary] = (
		GameManager.get_quick_slot_entries()
	)

	for slot_index in range(
		slot_buttons.size()
	):
		var button: Button = (
			slot_buttons[slot_index]
		)

		if slot_index >= entries.size():
			_clear_button(
				button,
				slot_index
			)
			continue

		var entry: Dictionary = (
			entries[slot_index]
		)

		var item := entry.get(
			"item"
		) as ItemData

		var amount: int = int(
			entry.get(
				"amount",
				0
			)
		)

		var selected: bool = bool(
			entry.get(
				"selected",
				false
			)
		)

		if item == null or amount <= 0:
			_clear_button(
				button,
				slot_index
			)
			continue

		button.text = (
			str(slot_index + 1)
			+ "\n×"
			+ str(amount)
		)

		button.icon = item.icon

		button.tooltip_text = (
			item.name
			+ " ×"
			+ str(amount)
		)

		button.button_pressed = selected
		button.modulate = Color.WHITE


func _clear_button(
	button: Button,
	slot_index: int
) -> void:
	button.text = (
		str(slot_index + 1)
		+ "\n—"
	)

	button.icon = null

	button.tooltip_text = (
		"Слот "
		+ str(slot_index + 1)
		+ " пуст"
	)

	button.button_pressed = false

	button.modulate = Color(
		1.0,
		1.0,
		1.0,
		0.55
	)

# =========================================================
# АКТИВНЫЕ ВРЕМЕННЫЕ ЭФФЕКТЫ
# =========================================================

func _refresh_active_effects() -> void:
	var effects: Array[Dictionary] = (
		GameManager.get_active_timed_effects()
	)

	var current_effect_ids: Dictionary = {}

	for effect in effects:
		var item_id: String = str(
			effect.get(
				"item_id",
				""
			)
		)

		if item_id.is_empty():
			continue

		var time_left: float = maxf(
			float(
				effect.get(
					"time_left",
					0.0
				)
			),
			0.0
		)

		if time_left <= 0.0:
			continue

		current_effect_ids[item_id] = true

		if not active_effect_cards.has(
			item_id
		):
			active_effect_cards[item_id] = (
				_create_effect_card(
					item_id
				)
			)

		var card: Dictionary = (
			active_effect_cards[item_id]
		)

		_update_effect_card(
			card,
			effect
		)

	for stored_item_id in (
		active_effect_cards.keys()
	):
		var item_id: String = str(
			stored_item_id
		)

		if current_effect_ids.has(item_id):
			continue

		var card: Dictionary = (
			active_effect_cards[item_id]
		)

		var root := card.get(
			"root"
		) as Control

		if is_instance_valid(root):
			root.queue_free()

		active_effect_cards.erase(
			item_id
		)

	active_effects_container.visible = (
		not active_effect_cards.is_empty()
	)


# =========================================================
# СИГНАЛЫ
# =========================================================

func _connect_signals() -> void:
	if not GameManager.quick_slots_changed.is_connected(
		_on_quick_slots_changed
	):
		GameManager.quick_slots_changed.connect(
			_on_quick_slots_changed
		)

	if not GameManager.selected_quick_slot_changed.is_connected(
		_on_selected_quick_slot_changed
	):
		GameManager.selected_quick_slot_changed.connect(
			_on_selected_quick_slot_changed
		)

	if not GameManager.inventory_item_amount_changed.is_connected(
		_on_inventory_item_amount_changed
	):
		GameManager.inventory_item_amount_changed.connect(
			_on_inventory_item_amount_changed
		)

	if not GameManager.inventory_changed.is_connected(
		_on_inventory_changed
	):
		GameManager.inventory_changed.connect(
			_on_inventory_changed
		)


func _on_quick_slots_changed(
	_slots: Array
) -> void:
	_refresh_quick_bar()


func _on_selected_quick_slot_changed(
	_slot_index: int
) -> void:
	_refresh_quick_bar()


func _on_inventory_item_amount_changed(
	_item_id: String,
	_amount: int
) -> void:
	_refresh_quick_bar()


func _on_inventory_changed(
	_entries: Array
) -> void:
	_refresh_quick_bar()

func _create_effect_card(
	item_id: String
) -> Dictionary:
	var item: ItemData = (
		_find_database_item(
			item_id
		)
	)

	var panel := PanelContainer.new()

	panel.custom_minimum_size = Vector2(
		150.0,
		56.0
	)

	panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		8
	)

	margin.add_theme_constant_override(
		"margin_top",
		5
	)

	margin.add_theme_constant_override(
		"margin_right",
		8
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		5
	)

	panel.add_child(
		margin
	)

	var content := HBoxContainer.new()

	content.add_theme_constant_override(
		"separation",
		7
	)

	margin.add_child(
		content
	)

	var icon := TextureRect.new()

	icon.custom_minimum_size = Vector2(
		36.0,
		36.0
	)

	icon.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)

	icon.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)

	icon.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	if item != null:
		icon.texture = item.icon

	content.add_child(
		icon
	)

	var information := VBoxContainer.new()

	information.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	information.add_theme_constant_override(
		"separation",
		1
	)

	content.add_child(
		information
	)

	var name_label := Label.new()

	if item != null:
		name_label.text = item.name
	else:
		name_label.text = item_id

	name_label.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)

	information.add_child(
		name_label
	)

	var timer_label := Label.new()

	timer_label.text = "0 с"

	information.add_child(
		timer_label
	)

	var progress_bar := ProgressBar.new()

	progress_bar.custom_minimum_size = Vector2(
		90.0,
		6.0
	)

	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 1.0
	progress_bar.show_percentage = false

	progress_bar.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	information.add_child(
		progress_bar
	)

	active_effects_container.add_child(
		panel
	)

	return {
		"root": panel,
		"timer_label": timer_label,
		"progress_bar": progress_bar
	}

func _update_effect_card(
	card: Dictionary,
	effect: Dictionary
) -> void:
	var timer_label := card.get(
		"timer_label"
	) as Label

	var progress_bar := card.get(
		"progress_bar"
	) as ProgressBar

	var time_left: float = maxf(
		float(
			effect.get(
				"time_left",
				0.0
			)
		),
		0.0
	)

	var duration: float = maxf(
		float(
			effect.get(
				"duration",
				1.0
			)
		),
		0.01
	)

	if timer_label != null:
		timer_label.text = (
			_format_effect_time(
				time_left
			)
		)

	if progress_bar != null:
		progress_bar.max_value = duration
		progress_bar.value = time_left


func _format_effect_time(
	time_left: float
) -> String:
	if time_left < 5.0:
		return (
			"%.1f с"
			% time_left
		)

	return (
		str(
			int(
				ceil(time_left)
			)
		)
		+ " с"
	)
	
func _find_database_item(
	item_id: String
) -> ItemData:
	for entry in GameManager.all_items:
		var item := entry as ItemData

		if item == null:
			continue

		if item.id == item_id:
			return item

	return null
	
# =========================================================
# ВСПОМОГАТЕЛЬНОЕ
# =========================================================

func _clear_container(
	container: Node
) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
