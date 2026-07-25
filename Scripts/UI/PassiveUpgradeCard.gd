extends PanelContainer
class_name PassiveUpgradeCard


@onready var item_icon: TextureRect = %ItemIcon

@onready var item_name_label: Label = (
	%ItemNameLabel
)

@onready var item_description_label: Label = (
	%ItemDescriptionLabel
)

@onready var stack_label: Label = %StackLabel


func setup(
	item: ItemData,
	stack_count: int
) -> void:
	if item == null:
		visible = false
		return

	item_name_label.text = item.name

	item_description_label.text = (
		item.description
	)

	stack_label.text = (
		"×"
		+ str(maxi(stack_count, 1))
	)

	if item.icon != null:
		item_icon.texture = item.icon
		item_icon.visible = true
	else:
		item_icon.texture = null
		item_icon.visible = false

	item_description_label.visible = (
		not item.description.is_empty()
	)

	tooltip_text = item.description
