extends Node


const MUSIC_BUS: StringName = &"Music"


const FARM_THEME: AudioStream = preload(
	"res://Assets/Audio/Music/farm_theme.wav"
)

const COMBAT_THEME: AudioStream = preload(
	"res://Assets/Audio/Music/combat_theme.ogg"
)

const BOSS_THEME: AudioStream = preload(
	"res://Assets/Audio/Music/boss_theme.ogg"
)

const BOSS_CLIMAX_THEME: AudioStream = preload(
	"res://Assets/Audio/Music/boss_theme_climax.ogg"
)

const SHOP_THEME: AudioStream = preload(
	"res://Assets/Audio/Music/shop_theme.ogg"
)

const VICTORY_THEME: AudioStream = preload(
	"res://Assets/Audio/Music/victory_theme.wav"
)

const GAME_OVER_THEME: AudioStream = preload(
	"res://Assets/Audio/Music/game_over_theme.wav"
)


var player_a: AudioStreamPlayer = null
var player_b: AudioStreamPlayer = null

var active_player: AudioStreamPlayer = null

var fade_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	player_a = _create_music_player(
		"MusicPlayerA"
	)

	player_b = _create_music_player(
		"MusicPlayerB"
	)

	active_player = player_a

	if not GameManager.game_over.is_connected(
		_on_game_over
	):
		GameManager.game_over.connect(
			_on_game_over
		)


func _create_music_player(
	player_name: String
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()

	player.name = player_name
	player.bus = MUSIC_BUS
	player.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(player)

	return player


func play_farm() -> void:
	_play_track(
		FARM_THEME,
		-12.0
	)


func play_combat() -> void:
	_play_track(
		COMBAT_THEME,
		-11.0
	)


func play_boss() -> void:
	_play_track(
		BOSS_THEME,
		-10.0
	)


func play_boss_climax() -> void:
	_play_track(
		BOSS_CLIMAX_THEME,
		-9.0
	)


func play_shop() -> void:
	_play_track(
		SHOP_THEME,
		-13.0
	)


func play_victory() -> void:
	_play_track(
		VICTORY_THEME,
		-9.0,
		0.7
	)


func play_game_over() -> void:
	_play_track(
		GAME_OVER_THEME,
		-10.0,
		0.7
	)


func _play_track(
	stream: AudioStream,
	target_volume_db: float,
	fade_duration: float = 0.5
) -> void:
	if stream == null:
		return

	if (
		active_player != null
		and active_player.playing
		and active_player.stream == stream
	):
		return

	var outgoing: AudioStreamPlayer = (
		active_player
	)

	var incoming: AudioStreamPlayer = (
		player_b
		if active_player == player_a
		else player_a
	)

	if incoming == null:
		return

	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()

	if (
		fade_tween != null
		and fade_tween.is_valid()
	):
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.set_parallel(true)

	if outgoing != null and outgoing.playing:
		fade_tween.tween_property(
			outgoing,
			"volume_db",
			-60.0,
			fade_duration
		)

	fade_tween.tween_property(
		incoming,
		"volume_db",
		target_volume_db,
		fade_duration
	)

	fade_tween.set_parallel(false)

	if outgoing != null:
		fade_tween.tween_callback(
			outgoing.stop
		)

	active_player = incoming


func stop_music(
	fade_duration: float = 0.4
) -> void:
	if active_player == null:
		return

	if not active_player.playing:
		return

	if (
		fade_tween != null
		and fade_tween.is_valid()
	):
		fade_tween.kill()

	var outgoing: AudioStreamPlayer = (
		active_player
	)

	fade_tween = create_tween()

	fade_tween.tween_property(
		outgoing,
		"volume_db",
		-60.0,
		fade_duration
	)

	fade_tween.tween_callback(
		outgoing.stop
	)


func _on_game_over(
	victory: bool
) -> void:
	if victory:
		play_victory()
	else:
		play_game_over()
