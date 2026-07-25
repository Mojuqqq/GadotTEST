extends Node


signal settings_loaded

signal master_volume_changed(
	value: float
)

signal music_volume_changed(
	value: float
)

signal sfx_volume_changed(
	value: float
)

signal fullscreen_changed(
	enabled: bool
)

signal resolution_changed(
	index: int,
	size: Vector2i
)


const SAVE_PATH: String = "user://settings.cfg"

const MASTER_BUS: StringName = &"Master"
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"


const DEFAULT_MASTER_VOLUME: float = 1.0
const DEFAULT_MUSIC_VOLUME: float = 1.0
const DEFAULT_SFX_VOLUME: float = 1.0

const DEFAULT_FULLSCREEN: bool = false
const DEFAULT_RESOLUTION_INDEX: int = 1


const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1024, 768),
	Vector2i(1280, 1024),
	Vector2i(1600, 1200),
	Vector2i(1920, 1080)
]


var master_volume: float = (
	DEFAULT_MASTER_VOLUME
)

var music_volume: float = (
	DEFAULT_MUSIC_VOLUME
)

var sfx_volume: float = (
	DEFAULT_SFX_VOLUME
)

var fullscreen: bool = (
	DEFAULT_FULLSCREEN
)

var resolution_index: int = (
	DEFAULT_RESOLUTION_INDEX
)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ensure_audio_buses()
	load_settings()
	apply_all_settings()

	settings_loaded.emit()


# =========================================================
# ЗАГРУЗКА И СОХРАНЕНИЕ
# =========================================================

func load_settings() -> void:
	var config := ConfigFile.new()

	var error: Error = config.load(
		SAVE_PATH
	)

	if error == ERR_FILE_NOT_FOUND:
		_set_default_values()
		save_settings()
		return

	if error != OK:
		push_warning(
			"Не удалось загрузить настройки. "
			+ "Код ошибки: "
			+ str(error)
		)

		_set_default_values()
		return

	master_volume = clampf(
		float(
			config.get_value(
				"audio",
				"master_volume",
				DEFAULT_MASTER_VOLUME
			)
		),
		0.0,
		1.0
	)

	music_volume = clampf(
		float(
			config.get_value(
				"audio",
				"music_volume",
				DEFAULT_MUSIC_VOLUME
			)
		),
		0.0,
		1.0
	)

	sfx_volume = clampf(
		float(
			config.get_value(
				"audio",
				"sfx_volume",
				DEFAULT_SFX_VOLUME
			)
		),
		0.0,
		1.0
	)

	fullscreen = bool(
		config.get_value(
			"display",
			"fullscreen",
			DEFAULT_FULLSCREEN
		)
	)

	resolution_index = clampi(
		int(
			config.get_value(
				"display",
				"resolution_index",
				DEFAULT_RESOLUTION_INDEX
			)
		),
		0,
		RESOLUTIONS.size() - 1
	)


func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(
		"audio",
		"master_volume",
		master_volume
	)

	config.set_value(
		"audio",
		"music_volume",
		music_volume
	)

	config.set_value(
		"audio",
		"sfx_volume",
		sfx_volume
	)

	config.set_value(
		"display",
		"fullscreen",
		fullscreen
	)

	config.set_value(
		"display",
		"resolution_index",
		resolution_index
	)

	var error: Error = config.save(
		SAVE_PATH
	)

	if error != OK:
		push_warning(
			"Не удалось сохранить настройки. "
			+ "Код ошибки: "
			+ str(error)
		)


func _set_default_values() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	music_volume = DEFAULT_MUSIC_VOLUME
	sfx_volume = DEFAULT_SFX_VOLUME
	fullscreen = DEFAULT_FULLSCREEN
	resolution_index = DEFAULT_RESOLUTION_INDEX


# =========================================================
# ПРИМЕНЕНИЕ ВСЕХ НАСТРОЕК
# =========================================================

func apply_all_settings() -> void:
	_apply_bus_volume(
		MASTER_BUS,
		master_volume
	)

	_apply_bus_volume(
		MUSIC_BUS,
		music_volume
	)

	_apply_bus_volume(
		SFX_BUS,
		sfx_volume
	)

	_apply_display_settings()


func reset_to_defaults() -> void:
	set_master_volume(
		DEFAULT_MASTER_VOLUME,
		false
	)

	set_music_volume(
		DEFAULT_MUSIC_VOLUME,
		false
	)

	set_sfx_volume(
		DEFAULT_SFX_VOLUME,
		false
	)

	set_resolution_index(
		DEFAULT_RESOLUTION_INDEX,
		false
	)

	set_fullscreen(
		DEFAULT_FULLSCREEN,
		false
	)

	save_settings()


# =========================================================
# ГРОМКОСТЬ
# =========================================================

func set_master_volume(
	value: float,
	should_save: bool = true
) -> void:
	master_volume = clampf(
		value,
		0.0,
		1.0
	)

	_apply_bus_volume(
		MASTER_BUS,
		master_volume
	)

	master_volume_changed.emit(
		master_volume
	)

	if should_save:
		save_settings()


func set_music_volume(
	value: float,
	should_save: bool = true
) -> void:
	music_volume = clampf(
		value,
		0.0,
		1.0
	)

	_apply_bus_volume(
		MUSIC_BUS,
		music_volume
	)

	music_volume_changed.emit(
		music_volume
	)

	if should_save:
		save_settings()


func set_sfx_volume(
	value: float,
	should_save: bool = true
) -> void:
	sfx_volume = clampf(
		value,
		0.0,
		1.0
	)

	_apply_bus_volume(
		SFX_BUS,
		sfx_volume
	)

	sfx_volume_changed.emit(
		sfx_volume
	)

	if should_save:
		save_settings()


func _apply_bus_volume(
	bus_name: StringName,
	linear_value: float
) -> void:
	var bus_index: int = (
		AudioServer.get_bus_index(
			bus_name
		)
	)

	if bus_index == -1:
		push_warning(
			"Аудиошина не найдена: "
			+ String(bus_name)
		)
		return

	var safe_value: float = maxf(
		linear_value,
		0.0001
	)

	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(safe_value)
	)

	AudioServer.set_bus_mute(
		bus_index,
		linear_value <= 0.0
	)


# =========================================================
# АУДИОШИНЫ
# =========================================================

func _ensure_audio_buses() -> void:
	_ensure_audio_bus(
		MUSIC_BUS
	)

	_ensure_audio_bus(
		SFX_BUS
	)


func _ensure_audio_bus(
	bus_name: StringName
) -> void:
	if (
		AudioServer.get_bus_index(
			bus_name
		)
		!= -1
	):
		return

	AudioServer.add_bus()

	var new_bus_index: int = (
		AudioServer.get_bus_count() - 1
	)

	AudioServer.set_bus_name(
		new_bus_index,
		bus_name
	)

	AudioServer.set_bus_send(
		new_bus_index,
		MASTER_BUS
	)


# =========================================================
# ПОЛНОЭКРАННЫЙ РЕЖИМ
# =========================================================

func set_fullscreen(
	enabled: bool,
	should_save: bool = true
) -> void:
	fullscreen = enabled

	_apply_display_settings()

	fullscreen_changed.emit(
		fullscreen
	)

	if should_save:
		save_settings()


func _apply_display_settings() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
		)
		return

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED
	)

	call_deferred(
		"_apply_windowed_resolution"
	)


# =========================================================
# РАЗРЕШЕНИЕ
# =========================================================

func set_resolution_index(
	index: int,
	should_save: bool = true
) -> void:
	if (
		index < 0
		or index >= RESOLUTIONS.size()
	):
		push_warning(
			"Некорректный индекс разрешения: "
			+ str(index)
		)
		return

	resolution_index = index

	if not fullscreen:
		call_deferred(
			"_apply_windowed_resolution"
		)

	resolution_changed.emit(
		resolution_index,
		get_current_resolution()
	)

	if should_save:
		save_settings()


func _apply_windowed_resolution() -> void:
	if fullscreen:
		return

	var resolution: Vector2i = (
		get_current_resolution()
	)

	DisplayServer.window_set_size(
		resolution
	)

	_center_window_on_screen(
		resolution
	)


func _center_window_on_screen(
	window_size: Vector2i
) -> void:
	var screen_index: int = (
		DisplayServer.window_get_current_screen()
	)

	var usable_rect: Rect2i = (
		DisplayServer.screen_get_usable_rect(
			screen_index
		)
	)

	var horizontal_offset: int = maxi(
		int(
			(
				float(usable_rect.size.x)
				- float(window_size.x)
			)
			/ 2.0
		),
		0
	)

	var vertical_offset: int = maxi(
		int(
			(
				float(usable_rect.size.y)
				- float(window_size.y)
			)
			/ 2.0
		),
		0
	)

	var window_position := Vector2i(
		usable_rect.position.x
		+ horizontal_offset,
		usable_rect.position.y
		+ vertical_offset
	)

	DisplayServer.window_set_position(
		window_position
	)


func get_current_resolution() -> Vector2i:
	return RESOLUTIONS[
		resolution_index
	]


func get_resolution_count() -> int:
	return RESOLUTIONS.size()


func get_resolution(
	index: int
) -> Vector2i:
	if (
		index < 0
		or index >= RESOLUTIONS.size()
	):
		return get_current_resolution()

	return RESOLUTIONS[index]


func get_resolution_label(
	index: int
) -> String:
	var resolution: Vector2i = (
		get_resolution(index)
	)

	return (
		str(resolution.x)
		+ " × "
		+ str(resolution.y)
	)
