extends SceneTree

## Reproduces the WC Nam interaction prompt visibility failure in the configured
## production scene. This test teleports only to isolate the prompt/UI behavior;
## it does not exercise or claim route navigation.
## Run: godot --headless --path . --script res://tests/test_production_wc_prompt_visibility_regression.gd
const MAIN := "res://scenes/01_hanh_lang.tscn"
const WC_APPROACH := Vector3(12.30543, 6.520944, 1.016525)
const EXPECTED_PROMPT := "E  ·  Mở cửa"
const BEAT_CLASSROOM := 2 # Beat.CLASSROOM in scripts/game.gd
const BEAT_NIGHT_SCHOOL := 8 # Beat.NIGHT_SCHOOL in scripts/game.gd

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.save_writes_suppressed = true
	state.scene_id = "scene_03"
	state.checkpoint_id = "night_school_yard"
	var game: Node = load(MAIN).instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await physics_frame

	var night: Node = game.get("night_school_visual")
	var actor := night.get("actor") as CharacterBody3D if night != null else null
	var prompt := game.get("prompt") as Label
	var panel := game.get("panel") as PanelContainer
	var prompt_hud := game.get("prompt_hud") as PanelContainer
	var dialogue_prompt_column := game.get("dialogue_prompt_column") as VBoxContainer
	var opening_card := game.get("opening_card") as PanelContainer
	if night == null or actor == null or prompt == null or panel == null or prompt_hud == null \
		or dialogue_prompt_column == null or opening_card == null:
		_fail("production scene missing night school, actor, prompt Label, dialogue panel/column, opening overlay, or GameplayPromptHUD")
		_finish()
		return

	# Teleport is intentional here: this checks a measured interaction state, not
	# pathfinding or route navigation.
	actor.call("teleport_to", WC_APPROACH)
	night.set("story_zone", "upper_hall")
	game.set("night_phase", "upper_hall")
	game.call("_process_night_school", 0.0)
	await process_frame

	var near_door := bool(night.call("near_restroom_door"))
	print("PRODUCTION_WC_PROMPT_TRACE actor=%s phase=%s story_zone=%s near_restroom_door=%s prompt_text=%s prompt_visible=%s prompt_visible_in_tree=%s panel_visible=%s" % [
		actor.global_position,
		game.get("night_phase"),
		night.get("story_zone"),
		near_door,
		prompt.text,
		prompt.visible,
		prompt.is_visible_in_tree(),
		panel.visible,
	])
	_check(actor.global_position.distance_to(WC_APPROACH) < 0.001, "actor is at the measured WC Nam prompt location")
	_check(str(game.get("night_phase")) == "upper_hall" and str(night.get("story_zone")) == "upper_hall",
		"production story phase and zone are both upper_hall")
	_check(near_door, "measured location is within WC Nam interaction range")
	_check(prompt.text == EXPECTED_PROMPT, "actual interaction prompt Label has the expected WC Nam text")
	_check(prompt.is_visible_in_tree(), "actual WC Nam interaction prompt is visible in-tree")

	# A night dialogue overlay suppresses the gameplay HUD even though the main
	# dialogue PanelContainer remains hidden during NIGHT_SCHOOL.
	game.call("_show_night_line", "An", "Bọn chúng tới rồi.", "E  ·  Tiếp tục")
	await process_frame
	print("PRODUCTION_WC_PROMPT_OVERLAY opening_card_visible=%s panel_visible=%s hud_visible=%s hud_visible_in_tree=%s prompt_text=%s" % [
		opening_card.visible,
		panel.visible,
		prompt_hud.visible,
		prompt_hud.is_visible_in_tree(),
		prompt.text,
	])
	_check(opening_card.visible and not panel.visible and not prompt_hud.visible
		and not prompt_hud.is_visible_in_tree(),
		"visible opening/night dialogue overlay hides GameplayPromptHUD while panel is hidden")

	game.call("_dismiss_night_line")
	await process_frame
	print("PRODUCTION_WC_PROMPT_HUD_DISMISSED phase=%s story_zone=%s prompt_text=%s hud_visible=%s hud_visible_in_tree=%s" % [
		game.get("night_phase"),
		night.get("story_zone"),
		prompt.text,
		prompt_hud.visible,
		prompt_hud.is_visible_in_tree(),
	])
	_check(str(game.get("night_phase")) == "upper_hall" and not prompt.text.is_empty()
		and prompt_hud.visible and prompt_hud.is_visible_in_tree(),
		"dismissing dialogue restores GameplayPromptHUD for a nonempty NIGHT_SCHOOL prompt")

	# _show_beat opens the standard dialogue panel; the same Label must be moved
	# back into its dialogue column so it is visible above that panel.
	game.set("beat", BEAT_CLASSROOM)
	game.set("classroom_read", false)
	game.set("classroom_intro_dismissed", false)
	game.call("_show_beat")
	var prompt_parent := prompt.get_parent()
	print("PRODUCTION_WC_PROMPT_DIALOGUE panel_visible=%s prompt_parent=%s dialogue_column=%s prompt_visible_in_tree=%s hud_visible=%s" % [
		panel.visible,
		prompt_parent.get_path() if prompt_parent != null else NodePath("<null>"),
		dialogue_prompt_column.get_path(),
		prompt.is_visible_in_tree(),
		prompt_hud.visible,
	])
	_check(panel.visible and prompt_parent == dialogue_prompt_column and prompt.is_visible_in_tree(),
		"_show_beat places the prompt back in the visible dialogue column")

	# Return to the measured gameplay interaction state for the real key event.
	game.set("beat", BEAT_NIGHT_SCHOOL)
	game.set("night_phase", "upper_hall")
	night.set("story_zone", "upper_hall")
	game.call("_show_beat")
	game.call("_process_night_school", 0.0)
	await process_frame
	_check(prompt.text == EXPECTED_PROMPT and prompt_hud.visible and prompt.is_visible_in_tree(),
		"restored WC Nam interaction prompt is visible before real KEY_E")

	# Send a real key event through the viewport's input path instead of calling
	# the interaction helper directly.
	var key_e := InputEventKey.new()
	key_e.keycode = KEY_E
	key_e.pressed = true
	Input.parse_input_event(key_e)
	await process_frame
	print("PRODUCTION_WC_PROMPT_KEY_E phase=%s restroom_entry_open=%s" % [
		game.get("night_phase"), night.get("restroom_entry_open")
	])
	_check(str(game.get("night_phase")) == "entering_restroom" and bool(night.get("restroom_entry_open")),
		"real KEY_E event opens the production WC Nam entrance")
	_finish()

func _check(ok: bool, description: String) -> void:
	if not ok:
		_fail(description)

func _fail(description: String) -> void:
	failures += 1
	push_error("PRODUCTION_WC_PROMPT_FAIL " + description)

func _finish() -> void:
	if failures == 0:
		print("PRODUCTION_WC_PROMPT_PASS")
	quit(1 if failures else 0)
