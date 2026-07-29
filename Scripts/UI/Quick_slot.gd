extends Control
class_name QuickSlot


@onready var locked_background: TextureRect = (
	$LockedBackground
)

@onready var normal_frame: TextureRect = (
	$NormalFrame
)

@onready var active_frame: TextureRect = (
	$ActiveFrame
)

@onready var item_icon: TextureRect = (
	$ItemIcon
)

@onready var slot_number_label: Label = (
	$SlotNumberLabel
)

@onready var amount_label: Label = (
	$AmountLabel
)

@onready var input_button: Button = (
	$InputButton
)


var slot_index: int = -1
var is_locked: bool = false
var has_item_content: bool = false


func setup_slot(
	index: int,
	locked_state: bool
) -> void:
	slot_index = index

	slot_number_label.text = str(
		index + 1
	)

	if locked_state:
		show_locked()
	else:
		show_empty()


func show_empty() -> void:
	is_locked = false
	has_item_content = false

	locked_background.visible = false

	normal_frame.visible = true
	active_frame.visible = false

	item_icon.texture = null
	item_icon.visible = false

	amount_label.text = ""
	amount_label.visible = false

	input_button.disabled = true

	tooltip_text = (
		"Слот "
		+ str(slot_index + 1)
		+ " пуст"
	)


func show_locked() -> void:
	is_locked = true
	has_item_content = false

	# Фон блокировки показывается под обычной рамкой.
	locked_background.visible = true

	normal_frame.visible = true
	active_frame.visible = false

	item_icon.texture = null
	item_icon.visible = false

	amount_label.text = ""
	amount_label.visible = false

	input_button.disabled = true

	tooltip_text = (
		"Слот "
		+ str(slot_index + 1)
		+ " заблокирован"
	)


func show_item(
	item: ItemData,
	amount: int,
	selected: bool
) -> void:
	if is_locked:
		show_locked()
		return

	if item == null or amount <= 0:
		show_empty()
		return

	has_item_content = true

	locked_background.visible = false

	normal_frame.visible = not selected
	active_frame.visible = selected

	item_icon.texture = item.icon
	item_icon.visible = item.icon != null

	amount_label.text = (
		"×"
		+ str(amount)
	)

	amount_label.visible = true

	input_button.disabled = false

	tooltip_text = (
		item.name
		+ " ×"
		+ str(amount)
	)


func set_selected(
	selected: bool
) -> void:
	if is_locked or not has_item_content:
		normal_frame.visible = true
		active_frame.visible = false
		return

	normal_frame.visible = not selected
	active_frame.visible = selected
