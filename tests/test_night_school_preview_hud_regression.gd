extends SceneTree

## A night-school editor preview must keep its current phase-specific HUD when
## the scene refreshes the beat after the player reaches the third-floor WC.
## Run with: godot --headless --path . --script
## tests/test_night_school_preview_hud_regression.gd -- --night-school-preview
const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"
const SAVE_PATH := "user://an_tieng_gay_trong_dem_save.json"

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.save_writes_suppressed = true
	state.scene_id = "scene_03"
	state.checkpoint_id = "night_school_yard"
	var game: Node = load(MAIN_SCENE).instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in 4:
		await process_frame

	_check(OS.get_cmdline_user_args().has("--night-school-preview"),
		"test launches through the night-school preview route")
	_check(bool(game.get("night_school_preview_launch"))
		and game.beat == game.Beat.NIGHT_SCHOOL,
		"night-school preview is active without changing the main story entrypoint")

	var night: Node = game.get("night_school_visual")
	var actor := night.get("actor") as CharacterBody3D if night != null else null
	var objective := game.get("objective") as Label
	var prompt := game.get("prompt") as Label
	if night != null and actor != null:
		actor.teleport_to(Vector3(14.0, 6.4, 1.0))
		await physics_frame
		game.call("_sync_night_school_upper_hall_from_position")
		game.call("_process_night_school", 0.01)
		_check(str(game.get("night_phase")) == "upper_hall"
			and str(night.get("story_zone")) == "upper_hall",
			"player position advances the preview into the upper hall")
		_check(objective != null and objective.text == "Cửa nhà vệ sinh tầng 3"
			and prompt != null and prompt.text == "E  ·  Mở cửa",
			"upper-hall proximity shows the WC door objective and E interaction")
		print("NIGHT_SCHOOL_HUD before_show_beat phase=%s objective=%s prompt=%s" % [
			game.get("night_phase"), objective.text if objective != null else "<missing>",
			prompt.text if prompt != null else "<missing>",
		])
		game.call("_show_beat")
		print("NIGHT_SCHOOL_HUD after_show_beat phase=%s objective=%s prompt=%s" % [
			game.get("night_phase"), objective.text if objective != null else "<missing>",
			prompt.text if prompt != null else "<missing>",
		])
		_check(str(game.get("night_phase")) == "upper_hall"
			and str(night.get("story_zone")) == "upper_hall",
			"HUD refresh keeps the runtime phase at the upper hall")
		_check(objective != null and objective.text == "Cửa nhà vệ sinh tầng 3"
			and prompt != null and prompt.text == "E  ·  Mở cửa",
			"HUD refresh preserves the WC door objective and E prompt in preview")
	else:
		_check(false, "night-school preview exposes its player")

	_check(not bool(state.persistence_enabled) and bool(state.save_writes_suppressed)
		and not FileAccess.file_exists(SAVE_PATH),
		"preview regression leaves persistent saves disabled and untouched")
	if game != null:
		game.queue_free()
	await process_frame
	if failures == 0:
		print("NIGHT_SCHOOL_PREVIEW_HUD_PASS checks=%d" % checks)
		quit()
	else:
		push_error("NIGHT_SCHOOL_PREVIEW_HUD_FAIL checks=%d failures=%d" % [checks, failures])
		quit(1)


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + description)
