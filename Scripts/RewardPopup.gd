extends Node2D

@export var duration: float = 1.5          # длительность анимации
@export var rise_distance: float = 120.0  # высота подъёма
@export var scale_to: float = 1.8         # максимальный масштаб

@onready var icon = $Icon
@onready var name_label = $NameLabel
@onready var desc_label = $DescLabel

func setup(item: ItemData):
	# Устанавливаем данные
	if item.icon:
		icon.texture = item.icon
	else:
		icon.visible = false   # если нет иконки
	name_label.text = item.name
	desc_label.text = item.description
	
	# Начальное состояние (маленький и прозрачный)
	scale = Vector2(0.2, 0.2)
	modulate.a = 0.0
	
	# Запускаем анимацию
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Появление и увеличение
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE * scale_to, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Подъём вверх
	tween.tween_property(self, "position:y", position.y - rise_distance, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Затухание и удаление
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_delay(duration - 0.3)
	tween.tween_callback(queue_free).set_delay(duration)
