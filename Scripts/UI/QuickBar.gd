extends CanvasLayer

const UI_FONT: FontFile = preload(
	"res://Assets/Fonts/Rubik-VariableFont_wght.ttf"
)
const QUICK_SLOT_ACTION_PREFIX: String = "quick_slot_"
const QUICK_SLOT_SCENE: PackedScene = preload("res://Scenes/UI/QuickSlot.tscn")
const DISPLAY_SLOT_COUNT: int = 9
const AVAILABLE_SLOT_COUNT: int = 5

@onready var slots_container: HBoxContainer = (%SlotsContainer)
@onready var active_effects_container: HBoxContainer = (%ActiveEffectsContainer)


var quick_slots: Array[QuickSlot] = []
var active_effect_cards: Dictionary = {}

var item_warning_label: Label = null
var item_warning_tween: Tween = null

var effect_refresh_accumulator: float = 0.0
const EFFECT_REFRESH_INTERVAL: float = 0.1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

	_create_item_warning_label()
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

func _create_item_warning_label() -> void:
	item_warning_label = Label.new()
	item_warning_label.name = "ItemUseWarningLabel"
	item_warning_label.add_theme_font_override(
		&"font",
		UI_FONT
	)

	item_warning_label.add_theme_font_size_override(
		&"font_size",
		18
	)

	item_warning_label.set_anchors_preset(
		Control.PRESET_CENTER_BOTTOM
	)

	item_warning_label.offset_left = -250.0
	item_warning_label.offset_top = -175.0
	item_warning_label.offset_right = 250.0
	item_warning_label.offset_bottom = -135.0

	item_warning_label.grow_horizontal = (
		Control.GROW_DIRECTION_BOTH
	)

	item_warning_label.grow_vertical = (
		Control.GROW_DIRECTION_BEGIN
	)

	item_warning_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	item_warning_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	item_warning_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	item_warning_label.add_theme_color_override(
		"font_color",
		Color(
			1.0,
			0.35,
			0.25,
			1.0
		)
	)

	item_warning_label.add_theme_color_override(
		"font_outline_color",
		Color(
			0.08,
			0.03,
			0.02,
			1.0
		)
	)

	item_warning_label.add_theme_constant_override(
		"outline_size",
		5
	)

	item_warning_label.text = ""
	item_warning_label.modulate.a = 0.0

	add_child(
		item_warning_label
	)

# =========================================================
# СОЗДАНИЕ СЛОТОВ
# =========================================================

func _create_slot_buttons() -> void:
	_clear_container(
		slots_container
	)

	quick_slots.clear()

	for slot_index in range(
		DISPLAY_SLOT_COUNT
	):
		var quick_slot := (
			QUICK_SLOT_SCENE.instantiate()
			as QuickSlot
		)

		if quick_slot == null:
			push_warning(
				"Не удалось создать быстрый слот."
			)
			continue

		slots_container.add_child(
			quick_slot
		)

		var locked_state: bool = (
			slot_index >= AVAILABLE_SLOT_COUNT
		)

		quick_slot.setup_slot(
			slot_index,
			locked_state
		)

		quick_slots.append(
			quick_slot
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

	var input_slot_count: int = mini(
		AVAILABLE_SLOT_COUNT,
		quick_slots.size()
	)

	for slot_index in range(
		input_slot_count
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
	if (
		slot_index < 0
		or slot_index >= quick_slots.size()
	):
		return

	var quick_slot: QuickSlot = (
		quick_slots[slot_index]
	)

	if (
		quick_slot.is_locked
		or not quick_slot.has_item_content
	):
		return
		
	var result: Dictionary = (
		GameManager.use_quick_slot(
			slot_index
		)
	)

	var success: bool = bool(
		result.get(
			"success",
			false
		)
	)

	if not success:
		AudioManager.play_error()
		var message: String = str(
			result.get(
				"message",
				"Сейчас предмет нельзя применить."
			)
		)


		_show_item_use_warning(
			message
		)

	if success:
		AudioManager.play_sfx(
			&"item_use",
			-17.0,
			0.98,
			1.02
		)

	_refresh_quick_bar()

func _show_item_use_warning(
	message: String
) -> void:
	if not is_instance_valid(
		item_warning_label
	):
		return

	var final_message: String = (
		message.strip_edges()
	)

	if final_message.is_empty():
		final_message = (
			"Сейчас предмет нельзя применить."
		)

	if (
		item_warning_tween != null
		and item_warning_tween.is_valid()
	):
		item_warning_tween.kill()

	item_warning_label.text = final_message
	item_warning_label.modulate = Color.WHITE

	item_warning_tween = create_tween()

	item_warning_tween.tween_interval(
		1.6
	)

	item_warning_tween.tween_property(
		item_warning_label,
		"modulate:a",
		0.0,
		0.3
	)

	item_warning_tween.tween_callback(
		_clear_item_use_warning
	)


func _clear_item_use_warning() -> void:
	if not is_instance_valid(
		item_warning_label
	):
		return

	item_warning_label.text = ""
	item_warning_label.modulate.a = 0.0

# =========================================================
# ОБНОВЛЕНИЕ UI
# =========================================================

func _refresh_quick_bar() -> void:
	var entries: Array[Dictionary] = (
		GameManager.get_quick_slot_entries()
	)

	for slot_index in range(
		quick_slots.size()
	):
		var quick_slot: QuickSlot = (
			quick_slots[slot_index]
		)

		# Слоты 6–9 всегда остаются
		# визуально заблокированными.
		if slot_index >= AVAILABLE_SLOT_COUNT:
			quick_slot.show_locked()
			continue

		# Первые пять слотов доступны,
		# даже когда в них нет предмета.
		if slot_index >= entries.size():
			quick_slot.show_empty()
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
			quick_slot.show_empty()
			continue

		quick_slot.show_item(
			item,
			amount,
			selected
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
					item_id,
					effect
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

	active_effects_container.visible = true


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
	slot_index: int
) -> void:
	_refresh_quick_bar()

	if slot_index < 0:
		return

	AudioManager.play_sfx(
		&"quick_slot_select",
		-14.0,
		0.98,
		1.02
	)


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
	item_id: String,
	effect: Dictionary
) -> Dictionary:
	var item: ItemData = (
		_find_database_item(
			item_id
		)
	)

	var display_name: String = str(
		effect.get(
			"display_name",
			""
		)
	)

	var effect_icon := effect.get(
		"icon"
	) as Texture2D

	var icon_path: String = str(
		effect.get(
			"icon_path",
			""
		)
	)

	if (
		effect_icon == null
		and not icon_path.is_empty()
		and ResourceLoader.exists(icon_path)
	):
		effect_icon = (
			load(icon_path) as Texture2D
		)

	if item != null:
		if display_name.is_empty():
			display_name = item.name

		if effect_icon == null:
			effect_icon = item.icon

	if display_name.is_empty():
		display_name = item_id

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

	icon.texture = effect_icon

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
	name_label.add_theme_font_override(
		&"font",
		UI_FONT
	)

	name_label.add_theme_font_size_override(
		&"font_size",
		14
	)
	name_label.text = display_name

	name_label.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)

	information.add_child(
		name_label
	)

	var timer_label := Label.new()

	timer_label.add_theme_font_override(
		&"font",
		UI_FONT
	)

	timer_label.add_theme_font_size_override(
		&"font_size",
		13
	)

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
