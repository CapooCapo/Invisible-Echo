extends Node

const AMBIENCE_ROOT := "res://assets/audio/ambience/"
const SFX_ROOT := "res://assets/audio/sfx/"
var ambience_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var current_ambience := ""

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	ambience_player = AudioStreamPlayer.new()
	ambience_player.volume_db = -18.0
	add_child(ambience_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -5.0
	add_child(sfx_player)
	set_ambience("school_night")

func _exit_tree() -> void:
	if ambience_player != null:
		ambience_player.stop()
		ambience_player.stream = null
	if sfx_player != null:
		sfx_player.stop()
		sfx_player.stream = null

func set_ambience(track_id: String) -> void:
	if ambience_player == null: return
	if current_ambience == track_id and ambience_player.playing: return
	var stream := load(AMBIENCE_ROOT + track_id + ".wav") as AudioStreamWAV
	if stream == null:
		push_warning("Missing ambience track: " + track_id)
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambience_player.stream = stream
	current_ambience = track_id
	ambience_player.play()

func play_sfx(sound_id: String) -> void:
	if sfx_player == null: return
	var stream := load(SFX_ROOT + sound_id + ".wav") as AudioStreamWAV
	if stream == null:
		push_warning("Missing sound effect: " + sound_id)
		return
	sfx_player.stream = stream
	sfx_player.play()
