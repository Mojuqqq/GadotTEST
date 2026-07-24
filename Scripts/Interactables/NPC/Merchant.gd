extends Node2D


const SHOP_MENU_SCENE: PackedScene = preload(
	"res://Scenes/UI/ShopMenu.tscn"
)


@export_group("Interaction")

@export var interaction_action: StringName = (
	&"interact"
)


@export_group("Shop")

@export_range(1, 10, 1)
var offer_count: int = 3


@onready var interaction_area: Area2D = (
	$InteractionArea
)

@onready var prompt_label: Label = (
	$PromptLabel
)


var player_near: bool = false
var shop_open: bool = false

var offers: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("Merchants")

	prompt_label.visible = false
	set_process_unhandled_input(false)

	_generate_offers()

	if not interaction_area.body_entered.is_connected(
		_on_interaction_area_body_entered
	):
		interaction_area.body_entered.connect(
			_on_interaction_area_body_entered
		)

	if not interaction_area.body_exited.is_connected(
		_on_interaction_area_body_exited
	):
		interaction_area.body_exited.connect(
			_on_interaction_area_body_exited
		)


func _unhandled_input(event: InputEvent) -> void:
	if shop_open:
		return

	if not player_near:
		return

	if event.is_action_pressed(
		interaction_action
	):
		get_viewport().set_input_as_handled()
		_open_shop()


func _on_interaction_area_body_entered(
	body: Node2D
) -> void:
	if not body.is_in_group("Player"):
		return

	player_near = true

	if not shop_open:
		prompt_label.text = "[E] Торговать"
		prompt_label.visible = true
		set_process_unhandled_input(true)


func _on_interaction_area_body_exited(
	body: Node2D
) -> void:
	if not body.is_in_group("Player"):
		return

	player_near = false
	prompt_label.visible = false

	set_process_unhandled_input(false)


func _generate_offers() -> void:
	offers.clear()

	var available_items: Array = (
		GameManager.all_items.duplicate()
	)

	available_items.shuffle()

	var count: int = mini(
		offer_count,
		available_items.size()
	)

	for index in range(count):
		var item := (
			available_items[index]
			as ItemData
		)

		if item == null:
			push_warning(
				"Торговец пропустил некорректный "
				+ "элемент списка предметов."
			)
			continue

		var price: int = maxi(
			item.shop_price,
			1
		)

		var grant_amount: int = (
			GameManager.roll_item_grant_amount(item)
		)

		offers.append({
			"item": item,
			"price": price,
			"amount": grant_amount,
			"sold": false
		})


func get_offers() -> Array[Dictionary]:
	return offers

func _has_inventory_space(
	item: ItemData,
	amount: int
) -> bool:
	if item == null:
		return false

	if amount <= 0:
		return false

	var current_amount: int = (
		GameManager.get_inventory_item_amount(
			item.id
		)
	)

	var maximum_amount: int = maxi(
		item.max_inventory_stack,
		1
	)

	return (
		current_amount + amount
		<= maximum_amount
	)

func purchase_offer(index: int) -> Dictionary:
	if index < 0 or index >= offers.size():
		return {
			"success": false,
			"message": "Товар не найден."
		}

	var offer: Dictionary = offers[index]

	if bool(offer.get("sold", false)):
		return {
			"success": false,
			"message": "Этот товар уже продан."
		}

	var item := offer.get("item") as ItemData

	var price: int = maxi(
		int(offer.get("price", 0)),
		0
	)

	var amount: int = maxi(
		int(offer.get("amount", 1)),
		1
	)

	if item == null:
		return {
			"success": false,
			"message": "Предмет не назначен."
		}

	if not _has_inventory_space(
		item,
		amount
	):
		return {
			"success": false,
			"message": (
				"Недостаточно места для "
				+ item.name
				+ " ×"
				+ str(amount)
			)
		}

	if GameManager.total_gold < price:
		return {
			"success": false,
			"message": (
				"Недостаточно золота. Нужно: "
				+ str(price)
			)
		}

	# Сначала добавляем товар.
	# Если списание золота неожиданно не сработает,
	# предметы можно безопасно убрать обратно.
	var inventory_result: Dictionary = (
		GameManager.add_item_to_inventory(
			item,
			amount
		)
	)

	if not bool(
		inventory_result.get(
			"success",
			false
		)
	):
		return {
			"success": false,
			"message": str(
				inventory_result.get(
					"message",
					"Не удалось добавить предмет."
				)
			)
		}

	var added_amount: int = int(
		inventory_result.get(
			"added_amount",
			0
		)
	)

	if added_amount != amount:
		if added_amount > 0:
			GameManager.remove_inventory_item(
				item.id,
				added_amount
			)

		return {
			"success": false,
			"message": (
				"Не удалось добавить всю пачку."
			)
		}

	var payment_successful: bool = (
		GameManager.spend_gold(price)
	)

	if not payment_successful:
		GameManager.remove_inventory_item(
			item.id,
			amount
		)

		return {
			"success": false,
			"message": "Не удалось списать золото."
		}

	offer["sold"] = true
	offers[index] = offer

	var item_name: String = _get_item_name(item)

	print(
		"Куплен предмет в инвентарь: ",
		item_name,
		" ×",
		amount,
		", цена: ",
		price
	)

	var purchase_message: String = (
		"Куплено: "
		+ item_name
	)

	if amount > 1:
		purchase_message += (
			" ×"
			+ str(amount)
		)

	return {
		"success": true,
		"message": purchase_message
	}


func _open_shop() -> void:
	if shop_open:
		return

	if SHOP_MENU_SCENE == null:
		push_error(
			"Не удалось загрузить ShopMenu.tscn"
		)
		return

	var current_scene: Node = (
		get_tree().current_scene
	)

	if current_scene == null:
		push_error(
			"Не найдена текущая игровая сцена."
		)
		return

	var menu := SHOP_MENU_SCENE.instantiate()

	if menu == null:
		push_error(
			"Не удалось создать меню магазина."
		)
		return

	shop_open = true
	prompt_label.visible = false
	set_process_unhandled_input(false)

	current_scene.add_child(menu)

	if menu.has_method("setup"):
		menu.call("setup", self)
	else:
		push_error(
			"В ShopMenu отсутствует setup()."
		)

		shop_open = false
		menu.queue_free()


func on_shop_closed() -> void:
	shop_open = false

	if player_near:
		prompt_label.text = "[E] Торговать"
		prompt_label.visible = true

		set_process_unhandled_input(true)


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
