extends Node


const SFX_BUS: StringName = &"SFX"


# =========================================================
# UI
# =========================================================

const UI_CLICK: AudioStream = preload(
	"res://Assets/Audio/Клик/506054__mellau__button-click-1.wav"
)

const UI_HOVER: AudioStream = preload(
	"res://Assets/Audio/Клик/navedenie--derevyannyiy-tap.wav"
)

const UI_CANCEL: AudioStream = preload(
	"res://Assets/Audio/Клик/788602__el_boss__cancel-or-no-button-sound.wav"
)


# =========================================================
# ПАУЗА
# =========================================================

const PAUSE_SOUND: AudioStream = preload(
	"res://Assets/Audio/пауза/836021__matustrm__pause.wav"
)

const RESUME_SOUND: AudioStream = preload(
	"res://Assets/Audio/анпауза/836022__matustrm__resume.wav"
)


# =========================================================
# ИГРОВЫЕ ЗВУКИ
# =========================================================

const PLAYER_ATTACK: AudioStream = preload(
	"res://Assets/Audio/атак плеер/168984__lavik89__digital-hit.wav"
)

const CHEST_OPEN: AudioStream = preload(
	"res://Assets/Audio/бонус/sunduk-otkryivaetsya--nagrada.wav"
)

const BONUS: AudioStream = preload(
	"res://Assets/Audio/бонус/otkryitie--dostijenie.wav"
)

const ERROR_SOUND: AudioStream = preload(
	"res://Assets/Audio/ерор/327738__distillerystudio__error_01.wav"
)

const DOOR_OPEN: AudioStream = preload(
	"res://Assets/Audio/опен дор/35109__digifishmusic__electromechanical-thunk.wav"
)


func _ready() -> void:
	# Звуки меню должны работать даже тогда,
	# когда SceneTree находится на паузе.
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not get_tree().node_added.is_connected(
		_on_node_added
	):
		get_tree().node_added.connect(
			_on_node_added
		)

	# Подключаем кнопки, которые уже существуют
	# к моменту запуска AudioManager.
	call_deferred(
		&"_connect_existing_buttons"
	)


# =========================================================
# АВТОМАТИЧЕСКОЕ ПОДКЛЮЧЕНИЕ UI
# =========================================================

func _connect_existing_buttons() -> void:
	_scan_node_for_buttons(
		get_tree().root
	)


func _scan_node_for_buttons(
	node: Node
) -> void:
	_try_connect_button(
		node
	)

	for child in node.get_children():
		_scan_node_for_buttons(
			child
		)


func _on_node_added(
	node: Node
) -> void:
	# Это подключает кнопки динамически создаваемых
	# окон: инвентаря, магазина, наград и так далее.
	call_deferred(
		&"_try_connect_button",
		node
	)


func _try_connect_button(
	node: Node
) -> void:
	if not is_instance_valid(node):
		return

	if not node is BaseButton:
		return

	var button := node as BaseButton

	# Через metadata можно полностью отключить
	# автоматический звук для конкретной кнопки.
	if bool(
		button.get_meta(
			&"audio_silent",
			false
		)
	):
		return

	if bool(
		button.get_meta(
			&"_audio_connected",
			false
		)
	):
		return

	button.set_meta(
		&"_audio_connected",
		true
	)

	button.pressed.connect(
		_on_ui_button_pressed.bind(button)
	)

	button.mouse_entered.connect(
		_on_ui_button_hovered.bind(button)
	)


func _on_ui_button_pressed(
	button: BaseButton
) -> void:
	if not is_instance_valid(button):
		return

	var sound_type: String = str(
		button.get_meta(
			&"audio_click",
			"default"
		)
	)

	match sound_type:
		"cancel":
			play_ui_cancel()

		"none":
			return

		_:
			play_ui_click()


func _on_ui_button_hovered(
	button: BaseButton
) -> void:
	if not is_instance_valid(button):
		return

	if button.disabled:
		return

	play_ui_hover()


# =========================================================
# ПУБЛИЧНЫЕ МЕТОДЫ
# =========================================================

func play_ui_click() -> void:
	_play_one_shot(
		UI_CLICK,
		-8.0,
		0.98,
		1.02
	)


func play_ui_hover() -> void:
	_play_one_shot(
		UI_HOVER,
		-16.0,
		0.98,
		1.02
	)


func play_ui_cancel() -> void:
	_play_one_shot(
		UI_CANCEL,
		-8.0
	)


func play_pause() -> void:
	_play_one_shot(
		PAUSE_SOUND,
		-5.0
	)


func play_resume() -> void:
	_play_one_shot(
		RESUME_SOUND,
		-5.0
	)


func play_error() -> void:
	_play_one_shot(
		ERROR_SOUND,
		-8.0
	)


func play_bonus() -> void:
	_play_one_shot(
		BONUS,
		-5.0
	)


func play_player_attack(
	world_position: Vector2
) -> void:
	_play_world_sound(
		PLAYER_ATTACK,
		world_position,
		-14.0,
		0.96,
		1.04
	)


func play_chest_open(
	world_position: Vector2
) -> void:
	_play_world_sound(
		CHEST_OPEN,
		world_position,
		-5.0
	)


func play_door_open(
	world_position: Vector2
) -> void:
	_play_world_sound(
		DOOR_OPEN,
		world_position,
		-7.0,
		0.98,
		1.02
	)


# =========================================================
# ВНУТРЕННЕЕ ВОСПРОИЗВЕДЕНИЕ
# =========================================================

func _play_one_shot(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_min: float = 1.0,
	pitch_max: float = 1.0
) -> void:
	if stream == null:
		return

	var player := AudioStreamPlayer.new()

	player.name = "OneShotSFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = SFX_BUS
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(
		pitch_min,
		pitch_max
	)

	add_child(player)

	player.finished.connect(
		player.queue_free
	)

	player.play()


func _play_world_sound(
	stream: AudioStream,
	world_position: Vector2,
	volume_db: float = 0.0,
	pitch_min: float = 1.0,
	pitch_max: float = 1.0
) -> void:
	if stream == null:
		return

	var player := AudioStreamPlayer2D.new()

	player.name = "WorldOneShotSFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = SFX_BUS
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(
		pitch_min,
		pitch_max
	)

	player.max_distance = 900.0
	player.attenuation = 1.0

	add_child(player)

	player.global_position = world_position

	player.finished.connect(
		player.queue_free
	)

	player.play()
