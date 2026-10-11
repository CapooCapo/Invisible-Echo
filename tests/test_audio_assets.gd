extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for track in ["school_night", "computer_room"]:
		var stream := load("res://assets/audio/ambience/%s.wav" % track) as AudioStreamWAV
		_check(stream != null and stream.get_length() >= 8.0, "%s ambience resource loads" % track)
	for sound in ["letter", "mirror_sting", "puzzle_solved", "chase_heartbeat", "death_hit", "keepsake"]:
		var stream := load("res://assets/audio/sfx/%s.wav" % sound) as AudioStreamWAV
		_check(stream != null and stream.get_length() > 0.1, "%s sound resource loads" % sound)
	if failures == 0:
		print("AUDIO_PASS checks=%d" % checks)
		quit()
	else:
		push_error("AUDIO_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("CHECK FAILED: " + description)
