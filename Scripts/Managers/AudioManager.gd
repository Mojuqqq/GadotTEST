extends Node


const SFX_BUS: StringName = &"SFX"


# =========================================================
# UI
# =========================================================

const UI_CLICK: AudioStream = preload(
	"res://Assets/Audio/UI/button_click.wav"
)

const UI_HOVER: AudioStream = preload(
	"res://Assets/Audio/UI/button_hover.wav"
)

const UI_CANCEL: AudioStream = preload(
	"res://Assets/Audio/UI/button_cancel.wav"
)


# =========================================================
# ПАУЗА
# =========================================================

const PAUSE_SOUND: AudioStream = preload(
	"res://Assets/Audio/System/pause.wav"
)

const RESUME_SOUND: AudioStream = preload(
	"res://Assets/Audio/System/resume.wav"
)



# =========================================================
# ИГРОВЫЕ ЗВУКИ
# =========================================================

const PLAYER_ATTACK: AudioStream = preload(
	"res://Assets/Audio/Player/egg_throw.wav"
)

const CHEST_OPEN: AudioStream = preload(
	"res://Assets/Audio/World/chest_open.wav"
)

const BONUS: AudioStream = preload(
	"res://Assets/Audio/System/reward.wav"
)

const ERROR_SOUND: AudioStream = preload(
	"res://Assets/Audio/UI/error.wav"
)

const DOOR_OPEN: AudioStream = preload(
	"res://Assets/Audio/World/door_open.wav"
)

# =========================================================
# ДОПОЛНИТЕЛЬНЫЕ ИГРОВЫЕ ЗВУКИ
# =========================================================

const SFX: Dictionary = {
	# Яйца
	&"egg_hit_enemy": preload(
		"res://Assets/Audio/Eggs/egg_hit_enemy.wav"
	),
	&"egg_hit_wall": preload(
		"res://Assets/Audio/Eggs/egg_hit_wall.wav"
	),
	&"egg_break": preload(
		"res://Assets/Audio/Eggs/egg_break.wav"
	),
	&"egg_splat": preload(
		"res://Assets/Audio/Eggs/egg_splat.wav"
	),
	&"golden_hit": preload(
		"res://Assets/Audio/Eggs/golden_hit.wav"
	),
	&"rotten_egg_squish": preload(
		"res://Assets/Audio/Eggs/rotten_egg_squish.wav"
	),
	&"poison_spawn": preload(
		"res://Assets/Audio/Eggs/poison_spawn.wav"
	),
	&"poison_tick": preload(
		"res://Assets/Audio/Eggs/poison_tick.wav"
	),

	# Игрок
	&"player_hurt_01": preload(
		"res://Assets/Audio/Player/player_hurt_01.wav"
	),
	&"player_hurt_02": preload(
		"res://Assets/Audio/Player/player_hurt_02.wav"
	),
	&"player_hurt_03": preload(
		"res://Assets/Audio/Player/player_hurt_03.wav"
	),
	&"player_death": preload(
		"res://Assets/Audio/Player/player_death.wav"
	),
	&"player_heal": preload(
		"res://Assets/Audio/Player/player_heal.wav"
	),
	&"speed_boost": preload(
		"res://Assets/Audio/Player/speed_boost.wav"
	),
	&"player_stunned": preload(
		"res://Assets/Audio/Player/player_stunned.wav"
	),
	&"stun_end": preload(
		"res://Assets/Audio/Player/stun_end.ogg"
	),
	&"player_knockback": preload(
		"res://Assets/Audio/Player/player_knockback.wav"
	),
	&"low_hp_warning": preload(
		"res://Assets/Audio/Player/low_hp_warning.wav"
	),

	# Предметы
	&"item_use": preload(
		"res://Assets/Audio/Items/item_use.wav"
	),
	&"item_pickup": preload(
		"res://Assets/Audio/Items/item_pickup.wav"
	),
	&"effect_end": preload(
		"res://Assets/Audio/Items/effect_end.wav"
	),
	&"omelet_bite": preload(
		"res://Assets/Audio/Items/omelet_bite.wav"
	),
	&"hot_sauce_use": preload(
		"res://Assets/Audio/Items/hot_sauce_use.wav"
	),

	# Универсальные удары
	&"impact_small": preload(
		"res://Assets/Audio/Universal/impact_small.ogg"
	),
	&"impact_medium": preload(
		"res://Assets/Audio/Universal/impact_medium.ogg"
	),
	&"impact_heavy": preload(
		"res://Assets/Audio/Universal/impact_heavy.ogg"
	),
	&"impact_soft": preload(
		"res://Assets/Audio/Universal/impact_soft.ogg"
	),
	&"impact_wood": preload(
		"res://Assets/Audio/Universal/impact_wood.ogg"
	),
	&"impact_metal": preload(
		"res://Assets/Audio/Universal/impact_metal.ogg"
	),

	# Универсальные эффекты
	&"explosion_small": preload(
		"res://Assets/Audio/Universal/explosion_small.wav"
	),
	&"whoosh_transition": preload(
		"res://Assets/Audio/Universal/whoosh_transition.wav"
	),
	&"whoosh_small": preload(
		"res://Assets/Audio/Universal/whoosh_small.wav"
	),
	&"whoosh_heavy": preload(
		"res://Assets/Audio/Universal/whoosh_heavy.wav"
	),
	&"body_fall_heavy": preload(
		"res://Assets/Audio/Universal/body_fall_heavy.wav"
	),
	&"shockwave": preload(
		"res://Assets/Audio/Universal/shockwave.wav"
	),
	&"water_splash": preload(
		"res://Assets/Audio/Universal/water_splash.wav"
	),

	# UI
	&"quick_slot_select": preload(
		"res://Assets/Audio/UI/quick_slot_select.ogg"
	),
	&"popup_open": preload(
		"res://Assets/Audio/UI/popup_open.ogg"
	),
	&"popup_close": preload(
		"res://Assets/Audio/UI/popup_close.ogg"
	),
	&"confirm": preload(
		"res://Assets/Audio/UI/confirm.ogg"
	),
	&"toggle_on": preload(
		"res://Assets/Audio/UI/toggle_on.ogg"
	),
	&"toggle_off": preload(
		"res://Assets/Audio/UI/toggle_off.ogg"
	),
	&"slider_tick": preload(
		"res://Assets/Audio/UI/slider_tick.ogg"
	),
	&"warning_popup": preload(
		"res://Assets/Audio/UI/warning_popup.ogg"
	),

	# Экономика / мир
	&"coin_pickup": preload(
		"res://Assets/Audio/World/coin_pickup.wav"
	),
	&"gold_spend": preload(
		"res://Assets/Audio/World/gold_spend.ogg"
	),
	&"key_pickup": preload(
		"res://Assets/Audio/World/key_pickup.wav"
	),
	&"key_turn": preload(
		"res://Assets/Audio/World/key_turn.wav"
	),
	&"door_lock": preload(
		"res://Assets/Audio/World/door_lock.wav"
	),
	&"shop_bell": preload(
		"res://Assets/Audio/World/shop_bell.wav"
	),

	# Компаньоны / курицы
	&"rooster_spawn": preload(
		"res://Assets/Audio/Companions/rooster_spawn.wav"
	),
	&"bird_flap": preload(
		"res://Assets/Audio/Companions/bird_flap.wav"
	),
	&"rooster_peck": preload(
		"res://Assets/Audio/Companions/rooster_peck.wav"
	),
	&"companion_spawn": preload(
		"res://Assets/Audio/Companions/companion_spawn.wav"
	),
	&"chick_peep": preload(
		"res://Assets/Audio/Companions/chick_peep.wav"
	),
	&"companion_poof": preload(
		"res://Assets/Audio/Companions/companion_poof.wav"
	),

	# Враги
	&"chicken_alarm": preload(
		"res://Assets/Audio/Enemies/chicken_alarm.wav"
	),
	&"chicken_death": preload(
		"res://Assets/Audio/Enemies/chicken_death.wav"
	),
	&"chicken_cluck_01": preload(
		"res://Assets/Audio/Enemies/chicken_cluck_01.wav"
	),
	&"chicken_cluck_02": preload(
		"res://Assets/Audio/Enemies/chicken_cluck_02.wav"
	),
	&"chicken_cluck_03": preload(
		"res://Assets/Audio/Enemies/chicken_cluck_03.wav"
	),
	&"onion_cry_01": preload(
		"res://Assets/Audio/Enemies/onion_cry_01.wav"
	),
	&"onion_cry_02": preload(
		"res://Assets/Audio/Enemies/onion_cry_02.wav"
	),
	&"onion_cry_03": preload(
		"res://Assets/Audio/Enemies/onion_cry_03.wav"
	),
	&"cow_moo": preload(
		"res://Assets/Audio/Enemies/cow_moo.wav"
	),
	&"bull_snort_01": preload(
		"res://Assets/Audio/Enemies/bull_snort_01.wav"
	),
	&"bull_snort_02": preload(
		"res://Assets/Audio/Enemies/bull_snort_02.wav"
	),
	&"bull_breath": preload(
		"res://Assets/Audio/Enemies/bull_breath.wav"
	),
	&"bull_bellow": preload(
		"res://Assets/Audio/Enemies/bull_bellow.wav"
	),

	# Боссы
	&"bull_ring_jingle": preload(
		"res://Assets/Audio/Bosses/bull_ring_jingle.wav"
	),
	&"bull_stomp": preload(
		"res://Assets/Audio/Bosses/bull_stomp.wav"
	),
	&"bull_enraged_roar": preload(
		"res://Assets/Audio/Bosses/bull_enraged_roar.wav"
	),
	&"boss_telegraph": preload(
		"res://Assets/Audio/Bosses/boss_telegraph.wav"
	),
	&"boss_intro_sting": preload(
		"res://Assets/Audio/Bosses/boss_intro_sting.wav"
	),
	&"boss_victory": preload(
		"res://Assets/Audio/System/boss_victory.wav"
	),
	&"scene_transition": preload(
		"res://Assets/Audio/System/scene_transition.mp3"
	)
}

const PLAYER_HURT_SOUNDS: Array[StringName] = [
	&"player_hurt_01",
	&"player_hurt_02",
	&"player_hurt_03"
]

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

	# Эти кнопки при закрытии паузы отдельно
	# проигрывают звук resume, поэтому обычный
	# звук нажатия им не нужен.
	if (
		button.name == &"ContinueButton"
		or button.name == &"CloseButton"
	):
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

func play_player_hurt(
	critical: bool = false
) -> void:
	var sound_name: StringName = (
		PLAYER_HURT_SOUNDS.pick_random()
	)

	if critical:
		play_sfx(
			sound_name,
			-7.0,
			0.90,
			0.97
		)

		play_sfx(
			&"impact_heavy",
			-10.0,
			0.95,
			1.02
		)

		return

	play_sfx(
		sound_name,
		-10.0,
		0.97,
		1.04
	)

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
		-18.0,
		0.98,
		1.02
	)


func play_ui_cancel() -> void:
	_play_one_shot(
		UI_CANCEL,
		-10.0
	)


func play_pause() -> void:
	_play_one_shot(
		PAUSE_SOUND,
		-10.0
	)


func play_resume() -> void:
	_play_one_shot(
		RESUME_SOUND,
		-10.0
	)


func play_error() -> void:
	_play_one_shot(
		ERROR_SOUND,
		-10.0
	)


func play_bonus() -> void:
	_play_one_shot(
		BONUS,
		-7.0
	)


func play_player_attack(
	_world_position: Vector2
) -> void:
	_play_one_shot(
		PLAYER_ATTACK,
		-8.0,
		0.96,
		1.04
	)


func play_chest_open(
	world_position: Vector2
) -> void:
	_play_world_sound(
		CHEST_OPEN,
		world_position,
		-9.0
	)


func play_door_open(
	world_position: Vector2
) -> void:
	_play_world_sound(
		DOOR_OPEN,
		world_position,
		-12.0,
		0.98,
		1.02
	)

func play_sfx(
	sound_name: StringName,
	volume_db: float = 0.0,
	pitch_min: float = 1.0,
	pitch_max: float = 1.0
) -> void:
	var stream := (
		SFX.get(sound_name) as AudioStream
	)

	if stream == null:
		push_warning(
			"AudioManager: не найден звук "
			+ str(sound_name)
		)
		return

	_play_one_shot(
		stream,
		volume_db,
		pitch_min,
		pitch_max
	)


func play_world_sfx(
	sound_name: StringName,
	world_position: Vector2,
	volume_db: float = 0.0,
	pitch_min: float = 1.0,
	pitch_max: float = 1.0
) -> void:
	var stream := (
		SFX.get(sound_name) as AudioStream
	)

	if stream == null:
		push_warning(
			"AudioManager: не найден звук "
			+ str(sound_name)
		)
		return

	_play_world_sound(
		stream,
		world_position,
		volume_db,
		pitch_min,
		pitch_max
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
