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
var is_locked: bool = true


func setup_slot(index: int) -> void:
	slot_index = index

	slot_number_label.text = str(
		index + 1
	)

	show_locked()


func show_locked() -> void:
	is_locked = true

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
		+ " пуст"
	)


func show_item(
	item: ItemData,
	amount: int,
	selected: bool
) -> void:
	if item == null or amount <= 0:
		show_locked()
		return

	is_locked = false

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


func set_selected(selected: bool) -> void:
	if is_locked:
		normal_frame.visible = true
		active_frame.visible = false
		return

	normal_frame.visible = not selected
	active_frame.visible = selected
