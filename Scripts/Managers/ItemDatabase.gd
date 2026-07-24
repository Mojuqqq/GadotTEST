extends Node


var all_items: Array[ItemData] = []


# =========================================================
# СОЗДАНИЕ БАЗЫ ПРЕДМЕТОВ
# =========================================================

func init_items(_game_manager: Node):
	all_items.clear()

	var items_data: Array[Dictionary] = [
		{
			"id": "energy",
			"name": "⚡ Скоростные сапоги",
			"desc": "+15% скорость",
			"icon": "res://Assets/Art/Items/New_boots.png",
			"shop_price": 20,
			"apply": func(stats, gm):
				stats.speed *= 1.15

				if (
					is_instance_valid(gm.player)
					and not gm.player.is_queued_for_deletion()
					and gm.player.has_method("update_speed")
				):
					gm.player.update_speed(
						stats.speed
					)

				gm.notify_stats_changed()
	},

		{
			"id": "eye",
			"name": "👁 Новые очки",
			"desc": "Увеличивает дальность атаки",
			"icon": "res://Assets/Art/Items/New_glasses.png",
			"shop_price": 25,
			"apply": func(stats, gm):
				stats.attack_range_multiplier = 1.5
				gm.notify_stats_changed()
	},

		{
			"id": "golden_egg",
			"name": "🥚 Золотое яйцо",
			"desc": "+50% урон",
			"icon": "res://Assets/Art/Items/Gold_egg.png",
			"shop_price": 35,
			"apply": func(stats, gm):
				stats.damage = ceili(
					stats.damage * 1.5
				)

				stats.has_golden_egg = true

				gm.notify_stats_changed()
	},

		{
			"id": "battle_rooster",
			"name": "🐔 Боевой петух",
			"desc": "Помощник атакует врагов",
			"icon": "res://Assets/Art/Items/Crazy_chicken.png",
			"shop_price": 40,
			"apply": func(stats, gm):
				stats.has_rooster = true
				gm.notify_stats_changed()

				if (
					is_instance_valid(gm.player)
					and not gm.player.is_queued_for_deletion()
					and gm.player.has_method(
						"spawn_companion"
					)
				):
					gm.player.spawn_companion(
						"rooster"
					)
	},

		{
			"id": "omelet",
			"name": "🍳 Омлет",
			"desc": "+2 сердца",
			"icon": "res://Assets/Art/Items/Omlet.png",
			"shop_price": 30,
			"apply": func(_stats, gm):
				gm.increase_max_hp(2)
	},

		{
			"id": "hot_sauce",
			"name": "🌶 Острый соус",
			"desc": "Яйца летят быстрее",
			"icon": "res://Assets/Art/Items/Hot_sauce.png",
			"shop_price": 15,
			"apply": func(stats, gm):
				stats.egg_speed *= 1.2
				gm.notify_stats_changed()
	},

		{
			"id": "rotten_egg",
			"name": "💣 Тухлое яйцо",
			"desc": "Оставляет ядовитую лужу",
			"icon": "res://Assets/Art/Items/Rotten_egg.png",
			"shop_price": 25,
			"apply": func(stats, gm):
				stats.poison_cloud = true
				gm.notify_stats_changed()
	},

		{
			"id": "chick",
			"name": "🐣 Цыплёнок",
			"desc": "Вылупляется, бежит к врагу и взрывается",
			"icon": "res://Assets/Art/Items/Item_chicken.png",
			"shop_price": 35,
			"apply": func(stats, gm):
				stats.has_chick_bomb = true
				gm.notify_stats_changed()

				if (
					is_instance_valid(gm.player)
					and not gm.player.is_queued_for_deletion()
					and gm.player.has_method(
						"spawn_companion"
					)
				):
					gm.player.spawn_companion(
						"chick"
					)
	}
	]

	_create_items(items_data)


# =========================================================
# СОЗДАНИЕ ITEMDATA
# =========================================================

func _create_items(
	items_data: Array[Dictionary]
):
	for data in items_data:
		var item := ItemData.new()

		item.id = str(data.get("id", ""))
		item.name = str(data.get("name", ""))
		item.description = str(data.get("desc", ""))

		item.shop_price = maxi(
			int(data.get("shop_price", 20)),
			1
		)

		item.apply = data.get(
			"apply",
			Callable()
		)

		var icon_path: String = data.get(
			"icon",
			""
		)

		if not icon_path.is_empty():
			if ResourceLoader.exists(icon_path):
				item.icon = load(icon_path)
			else:
				push_warning(
					"Не найдена иконка предмета: "
					+ icon_path
				)

		all_items.append(item)
