extends Control
class_name SettingsMenu


signal opened
signal closed


@onready var dim_background: Panel = (
	$DimBackground
)

@onready var close_button: TextureButton = (
	$CloseButton
)


# =========================================================
# ЗВУК
# =========================================================

@onready var master_slider: HSlider = (
	$Content/SettingsVBox/MasterRow/MasterSlider
)

@onready var master_value: Label = (
	$Content/SettingsVBox/MasterRow/MasterValue
)

@onready var music_slider: HSlider = (
	$Content/SettingsVBox/MusicRow/MusicSlider
)

@onready var music_value: Label = (
	$Content/SettingsVBox/MusicRow/MusicValue
)

@onready var effects_slider: HSlider = (
	$Content/SettingsVBox/EffectsRow/EffectsSlider
)

@onready var effects_value: Label = (
	$Content/SettingsVBox/EffectsRow/EffectsValue
)


# =========================================================
# ЭКРАН
# =========================================================

@onready var fullscreen_check: CheckButton = (
	$Content/SettingsVBox/FullscreenRow/FullscreenCheck
)

@onready var resolution_option: OptionButton = (
	$Content/SettingsVBox/ResolutionRow/ResolutionOption
)


# =========================================================
# КНОПКИ
# =========================================================

@onready var reset_button: Button = (
	$Content/SettingsVBox/ButtonsRow/ResetButton
)

@onready var back_button: Button = (
	$Content/SettingsVBox/ButtonsRow/BackButton
)


var is_updating_ui: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_connect_signals()
	_fill_resolution_options()
	_refresh_from_manager()


# =========================================================
# ОТКРЫТИЕ И ЗАКРЫТИЕ
# =========================================================

func open_menu() -> void:
	if visible:
		return

	_refresh_from_manager()

	visible = true

	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE
	)

	back_button.grab_focus()

	opened.emit()


func close_menu() -> void:
	if not visible:
		return

	visible = false
	closed.emit()


func is_menu_open() -> bool:
	return visible


# =========================================================
# ПОДКЛЮЧЕНИЕ СИГНАЛОВ
# =========================================================

func _connect_signals() -> void:
	if not close_button.pressed.is_connected(
		_on_close_button_pressed
	):
		close_button.pressed.connect(
			_on_close_button_pressed
		)

	if not back_button.pressed.is_connected(
		_on_back_button_pressed
	):
		back_button.pressed.connect(
			_on_back_button_pressed
		)

	if not reset_button.pressed.is_connected(
		_on_reset_button_pressed
	):
		reset_button.pressed.connect(
			_on_reset_button_pressed
		)

	if not dim_background.gui_input.is_connected(
		_on_dim_background_gui_input
	):
		dim_background.gui_input.connect(
			_on_dim_background_gui_input
		)

	if not master_slider.value_changed.is_connected(
		_on_master_slider_value_changed
	):
		master_slider.value_changed.connect(
			_on_master_slider_value_changed
		)

	if not music_slider.value_changed.is_connected(
		_on_music_slider_value_changed
	):
		music_slider.value_changed.connect(
			_on_music_slider_value_changed
		)

	if not effects_slider.value_changed.is_connected(
		_on_effects_slider_value_changed
	):
		effects_slider.value_changed.connect(
			_on_effects_slider_value_changed
		)

	if not fullscreen_check.toggled.is_connected(
		_on_fullscreen_check_toggled
	):
		fullscreen_check.toggled.connect(
			_on_fullscreen_check_toggled
		)

	if not resolution_option.item_selected.is_connected(
		_on_resolution_option_item_selected
	):
		resolution_option.item_selected.connect(
			_on_resolution_option_item_selected
		)


# =========================================================
# ЗАПОЛНЕНИЕ ИНТЕРФЕЙСА
# =========================================================

func _fill_resolution_options() -> void:
	resolution_option.clear()

	for index in range(
		SettingsManager.get_resolution_count()
	):
		var resolution_label: String = (
			SettingsManager.get_resolution_label(
				index
			)
		)

		resolution_option.add_item(
			resolution_label,
			index
		)


func _refresh_from_manager() -> void:
	is_updating_ui = true

	var master_percent: float = (
		SettingsManager.master_volume
		* 100.0
	)

	var music_percent: float = (
		SettingsManager.music_volume
		* 100.0
	)

	var effects_percent: float = (
		SettingsManager.sfx_volume
		* 100.0
	)

	master_slider.value = master_percent
	music_slider.value = music_percent
	effects_slider.value = effects_percent

	_update_percent_label(
		master_value,
		master_percent
	)

	_update_percent_label(
		music_value,
		music_percent
	)

	_update_percent_label(
		effects_value,
		effects_percent
	)

	fullscreen_check.button_pressed = (
		SettingsManager.fullscreen
	)

	_update_fullscreen_control(
		SettingsManager.fullscreen
	)

	var resolution_index: int = clampi(
		SettingsManager.resolution_index,
		0,
		resolution_option.item_count - 1
	)

	if resolution_option.item_count > 0:
		resolution_option.select(
			resolution_index
		)

	is_updating_ui = false


func _update_percent_label(
	label: Label,
	value: float
) -> void:
	label.text = (
		str(
			int(
				round(value)
			)
		)
		+ "%"
	)


func _update_fullscreen_control(
	enabled: bool
) -> void:
	fullscreen_check.text = (
		"Включено"
		if enabled
		else "Выключено"
	)

	# Разрешение окна нельзя изменить,
	# пока включён полноэкранный режим.
	resolution_option.disabled = enabled

	if enabled:
		resolution_option.tooltip_text = (
			"Разрешение применяется "
			+ "только в оконном режиме"
		)
	else:
		resolution_option.tooltip_text = (
			"Выберите разрешение окна"
		)


# =========================================================
# ГРОМКОСТЬ
# =========================================================

func _on_master_slider_value_changed(
	value: float
) -> void:
	_update_percent_label(
		master_value,
		value
	)

	if is_updating_ui:
		return

	SettingsManager.set_master_volume(
		_percent_to_linear(value)
	)


func _on_music_slider_value_changed(
	value: float
) -> void:
	_update_percent_label(
		music_value,
		value
	)

	if is_updating_ui:
		return

	SettingsManager.set_music_volume(
		_percent_to_linear(value)
	)


func _on_effects_slider_value_changed(
	value: float
) -> void:
	_update_percent_label(
		effects_value,
		value
	)

	if is_updating_ui:
		return

	SettingsManager.set_sfx_volume(
		_percent_to_linear(value)
	)


func _percent_to_linear(
	value: float
) -> float:
	return clampf(
		value / 100.0,
		0.0,
		1.0
	)


# =========================================================
# ЭКРАН
# =========================================================

func _on_fullscreen_check_toggled(
	enabled: bool
) -> void:
	_update_fullscreen_control(
		enabled
	)

	if is_updating_ui:
		return

	SettingsManager.set_fullscreen(
		enabled
	)


func _on_resolution_option_item_selected(
	index: int
) -> void:
	if is_updating_ui:
		return

	SettingsManager.set_resolution_index(
		index
	)


# =========================================================
# КНОПКИ
# =========================================================

func _on_close_button_pressed() -> void:
	close_menu()


func _on_back_button_pressed() -> void:
	close_menu()


func _on_reset_button_pressed() -> void:
	SettingsManager.reset_to_defaults()
	_refresh_from_manager()


# =========================================================
# НАЖАТИЕ ВНЕ ОКНА
# =========================================================

func _on_dim_background_gui_input(
	event: InputEvent
) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = (
			event as InputEventMouseButton
		)

		if (
			mouse_event.button_index
			== MOUSE_BUTTON_LEFT
			and mouse_event.pressed
		):
			dim_background.accept_event()
			close_menu()

		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = (
			event as InputEventScreenTouch
		)

		if touch_event.pressed:
			dim_background.accept_event()
			close_menu()
