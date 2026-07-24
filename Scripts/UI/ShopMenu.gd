extends CanvasLayer


@onready var gold_label: Label = %GoldLabel
@onready var offer_list: VBoxContainer = %OfferList
@onready var status_label: Label = %StatusLabel
@onready var close_button: Button = %CloseButton


var merchant: Node = null
var previous_pause_state: bool = false
var is_closing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not close_button.pressed.is_connected(
		close_menu
	):
		close_button.pressed.connect(
			close_menu
		)


func setup(new_merchant: Node) -> void:
	merchant = new_merchant

	if not is_instance_valid(merchant):
		push_error(
			"ShopMenu не получил торговца."
		)
		close_menu()
		return

	previous_pause_state = get_tree().paused
	get_tree().paused = true

	if not GameManager.total_gold_changed.is_connected(
		_on_total_gold_changed
	):
		GameManager.total_gold_changed.connect(
			_on_total_gold_changed
		)

	status_label.text = ""

	_refresh_shop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()


func _refresh_shop() -> void:
	_clear_offer_list()

	gold_label.text = (
		"Золото: "
		+ str(GameManager.total_gold)
	)

	if not is_instance_valid(merchant):
		return

	if not merchant.has_method("get_offers"):
		_add_information_label(
			"У торговца отсутствует ассортимент."
		)
		return

	var offers: Array = merchant.call(
		"get_offers"
	)

	if offers.is_empty():
		_add_information_label(
			"Товары закончились."
		)
		return

	for index in range(offers.size()):
		var offer: Dictionary = offers[index]

		_create_offer_button(
			offer,
			index
		)


func _create_offer_button(
	offer: Dictionary,
	index: int
) -> void:
	var item = offer.get("item")
	var price: int = int(
		offer.get("price", 0)
	)
	var amount: int = maxi(
	int(
		offer.get(
			"amount",
			1
		)
	),
	1
)
	var sold: bool = bool(
		offer.get("sold", false)
	)

	var item_name: String = (
		_get_item_name(item)
	)
	var offer_name: String = item_name
	if amount > 1:
		offer_name += (
			" ×"
			+ str(amount)
		)
	var button := Button.new()

	button.custom_minimum_size = Vector2(
		0.0,
		54.0
	)

	button.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	if sold:
		button.text = (
			offer_name
			+ " — ПРОДАНО"
		)

		button.disabled = true
	else:
		button.text = (
			offer_name
			+ " — "
			+ str(price)
			+ " золота"
		)

		button.pressed.connect(
			_on_offer_pressed.bind(index)
		)

	offer_list.add_child(button)


func _on_offer_pressed(index: int) -> void:
	if not is_instance_valid(merchant):
		status_label.text = (
			"Торговец больше недоступен."
		)
		return

	if not merchant.has_method("purchase_offer"):
		status_label.text = (
			"Покупка не поддерживается."
		)
		return

	var result: Dictionary = merchant.call(
		"purchase_offer",
		index
	)

	status_label.text = str(
		result.get(
			"message",
			"Неизвестный результат покупки."
		)
	)

	_refresh_shop()


func _on_total_gold_changed(
	_value: int
) -> void:
	if is_instance_valid(self):
		_refresh_shop()


func _clear_offer_list() -> void:
	for child in offer_list.get_children():
		offer_list.remove_child(child)
		child.queue_free()


func _add_information_label(
	text: String
) -> void:
	var label := Label.new()

	label.text = text
	label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	offer_list.add_child(label)


func _get_item_name(item) -> String:
	if item == null:
		return "Неизвестный предмет"

	var item_name: String = str(item.name)

	if not item_name.is_empty():
		return item_name

	if not item.resource_path.is_empty():
		return (
			item.resource_path
			.get_file()
			.get_basename()
		)

	return "Предмет без названия"


func close_menu() -> void:
	if is_closing:
		return

	is_closing = true

	if GameManager.total_gold_changed.is_connected(
		_on_total_gold_changed
	):
		GameManager.total_gold_changed.disconnect(
			_on_total_gold_changed
		)

	get_tree().paused = previous_pause_state

	if (
		is_instance_valid(merchant)
		and merchant.has_method("on_shop_closed")
	):
		merchant.call_deferred(
			"on_shop_closed"
		)

	queue_free()
