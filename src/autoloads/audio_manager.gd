## AudioManager — Autoload singleton
## ADR-008: Audio Architecture
## GDD Req: TR-audio-001
##
## Non-positional audio only. All SFX referenced by StringName constant.
## Volley volume scales linearly with archer count: -6dB at 2 archers, 0dB at 8.
## AudioStreamPlayer nodes are children of this node (added in _ready).
extends Node

const SFX_VOLLEY := &"volley"
const SFX_COIN_COLLECT := &"coin_collect"
const SFX_RECRUIT := &"recruit"
const SFX_CASTLE_HIT := &"castle_hit"
const SFX_GAME_OVER := &"game_over"
const SFX_DWELL_COMPLETE := &"dwell_complete"

## All registered AudioStreamPlayer nodes, keyed by StringName.
var _players: Dictionary = {}

func _ready() -> void:
	_register_player(SFX_VOLLEY)
	_register_player(SFX_COIN_COLLECT)
	_register_player(SFX_RECRUIT)
	_register_player(SFX_CASTLE_HIT)
	_register_player(SFX_GAME_OVER)
	_register_player(SFX_DWELL_COMPLETE)

	# Assign procedurally-generated audio streams — no external .ogg files required.
	# All use AudioStreamWAV (8-bit unsigned PCM, mono, 11025 Hz) for minimal memory footprint.
	_players[SFX_VOLLEY].stream       = _make_sfx_volley()
	_players[SFX_COIN_COLLECT].stream = _make_sfx_coin()
	_players[SFX_RECRUIT].stream      = _make_sfx_recruit()
	_players[SFX_CASTLE_HIT].stream   = _make_sfx_castle_hit()
	_players[SFX_GAME_OVER].stream    = _make_sfx_game_over()
	_players[SFX_DWELL_COMPLETE].stream = _make_sfx_dwell_complete()

	# Connect to session_reset — stop all sound on session restart
	GameStateMachine.session_reset.connect(_on_session_reset)

## Play a named SFX. Safe to call even if the stream has no audio asset loaded.
func play(sfx_name: StringName) -> void:
	if sfx_name in _players:
		_players[sfx_name].play()

## Play the volley SFX with volume scaled to archer count.
## Formula: volume_db = lerp(-6.0, 0.0, (n - 2.0) / 6.0)
## n=2 → -6dB, n=8 → 0dB
func play_volley(archer_count: int) -> void:
	var n := clampf(float(archer_count), 2.0, 8.0)
	var volume_db := lerpf(-6.0, 0.0, (n - 2.0) / 6.0)
	if SFX_VOLLEY in _players:
		_players[SFX_VOLLEY].volume_db = volume_db
		_players[SFX_VOLLEY].play()

## Stop all audio on session reset.
func _on_session_reset() -> void:
	for player: AudioStreamPlayer in _players.values():
		player.stop()

## Internal: create and register an AudioStreamPlayer child for the given SFX name.
func _register_player(sfx_name: StringName) -> void:
	var player := AudioStreamPlayer.new()
	player.name = str(sfx_name)
	add_child(player)
	_players[sfx_name] = player

# ---------------------------------------------------------------------------
# Procedural SFX generators — AudioStreamWAV, 8-bit unsigned PCM, mono 11025 Hz
# 8-bit unsigned: 0=silence(min), 128=center, 255=max. Range is 0..255.
# ---------------------------------------------------------------------------

## Build a WAV from a PackedByteArray of 8-bit unsigned samples at 11025 Hz.
func _build_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.stereo = false
	stream.mix_rate = 11025
	stream.data = data
	return stream

## Short percussive "thwip" — white noise burst with fast exponential decay (~0.09s).
func _make_sfx_volley() -> AudioStreamWAV:
	const HZ := 11025; const DUR := 0.09
	var n := int(DUR * HZ)
	var data := PackedByteArray(); data.resize(n)
	for i in range(n):
		var env: float = pow(1.0 - float(i) / float(n), 2.0)
		var noise: float = randf_range(-1.0, 1.0)
		data[i] = int(clamp(128.0 + noise * env * 90.0, 0.0, 255.0))
	return _build_wav(data)

## Rising sine "ding" — 880 Hz → 1320 Hz over 0.14s.
func _make_sfx_coin() -> AudioStreamWAV:
	const HZ := 11025; const DUR := 0.14
	var n := int(DUR * HZ)
	var data := PackedByteArray(); data.resize(n)
	for i in range(n):
		var t: float = float(i) / float(HZ)
		var freq: float = lerpf(880.0, 1320.0, float(i) / float(n))
		var env: float = 1.0 - float(i) / float(n)
		var v: float = sin(TAU * freq * t) * env
		data[i] = int(clamp(128.0 + v * 100.0, 0.0, 255.0))
	return _build_wav(data)

## Warm chord "confirm" — 440 Hz sine + 550 Hz overtone, 0.22s with decay.
func _make_sfx_recruit() -> AudioStreamWAV:
	const HZ := 11025; const DUR := 0.22
	var n := int(DUR * HZ)
	var data := PackedByteArray(); data.resize(n)
	for i in range(n):
		var t: float = float(i) / float(HZ)
		var env: float = pow(1.0 - float(i) / float(n), 0.7)
		var v: float = (sin(TAU * 440.0 * t) * 0.6 + sin(TAU * 550.0 * t) * 0.4) * env
		data[i] = int(clamp(128.0 + v * 100.0, 0.0, 255.0))
	return _build_wav(data)

## Low thud "impact" — 120 Hz square with noise layer, 0.28s fast decay.
func _make_sfx_castle_hit() -> AudioStreamWAV:
	const HZ := 11025; const DUR := 0.28
	var n := int(DUR * HZ)
	var data := PackedByteArray(); data.resize(n)
	for i in range(n):
		var t: float = float(i) / float(HZ)
		var env: float = pow(1.0 - float(i) / float(n), 1.5)
		var sq: float = 1.0 if fmod(t * 120.0, 1.0) < 0.5 else -1.0
		var noise: float = randf_range(-1.0, 1.0)
		var v: float = (sq * 0.7 + noise * 0.3) * env
		data[i] = int(clamp(128.0 + v * 110.0, 0.0, 255.0))
	return _build_wav(data)

## Descending tone "fail" — 440→220→110 Hz sine over 0.75s.
func _make_sfx_game_over() -> AudioStreamWAV:
	const HZ := 11025; const DUR := 0.75
	var n := int(DUR * HZ)
	var data := PackedByteArray(); data.resize(n)
	for i in range(n):
		var t: float = float(i) / float(HZ)
		var ratio: float = float(i) / float(n)
		var freq: float = lerpf(440.0, 110.0, ratio)
		var env: float = 1.0 - ratio * 0.8
		var v: float = sin(TAU * freq * t) * env
		data[i] = int(clamp(128.0 + v * 105.0, 0.0, 255.0))
	return _build_wav(data)

## Rising chirp "done" — 550→880 Hz over 0.16s.
func _make_sfx_dwell_complete() -> AudioStreamWAV:
	const HZ := 11025; const DUR := 0.16
	var n := int(DUR * HZ)
	var data := PackedByteArray(); data.resize(n)
	for i in range(n):
		var t: float = float(i) / float(HZ)
		var freq: float = lerpf(550.0, 880.0, float(i) / float(n))
		var env: float = 1.0 - float(i) / float(n) * 0.5
		var v: float = sin(TAU * freq * t) * env
		data[i] = int(clamp(128.0 + v * 95.0, 0.0, 255.0))
	return _build_wav(data)
