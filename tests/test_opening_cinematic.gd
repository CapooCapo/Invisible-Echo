extends SceneTree

## Regression coverage for the approved Scene 01/02 opening flow.
## Run with: godot --headless --path . --script tests/test_opening_cinematic.gd
const MAIN_SCENE := "res://scenes/01_hanh_lang.tscn"

var checks := 0
var failures := 0
var game: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.persistence_enabled = false
	state.inventory.clear()
	state.flags.clear()
	state.evidence.clear()
	state.scene_id = "scene_01"
	state.checkpoint_id = "scene_01_start"
	game = load(MAIN_SCENE).instantiate()
	_check(game != null, "main game scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	current_scene = game
	await process_frame
	await physics_frame

	var hall: Node = game.get("hallway_visual")
	var actor := hall.get("actor") as CharacterBody3D
	_check(actor != null, "Scene 01 creates a physical player")
	if actor == null:
		_finish()
		return
	_check(_count_red_reveal_labels(hall) == 0, "hallway starts without red rescue lettering")

	var expected_monologue := [
		"Chúng ta sống trong một thế giới nơi cá lớn nuốt cá bé.",
		"Nơi con người giẫm lên nhau chỉ để được sống.",
		"Tôi từng nghĩ... chỉ cần không liên quan đến mình là đủ.",
	]
	_check(str(game.get("opening_phase")) == "scene01_monologue", "opening starts on the black-screen monologue")
	var fade := game.get("cinematic_black") as ColorRect
	var card := game.get("opening_card") as Control
	_check(card != null and card.visible and fade != null and fade.visible,
		"opening monologue subtitle card and black-screen layer are both active")
	_check(card != null and fade != null and card.z_index > fade.z_index,
		"monologue subtitles render above the black screen overlay")
	for i in expected_monologue.size():
		_check(str(game.get("opening_subtitle").text) == expected_monologue[i],
			"monologue line %d is exact and in order" % (i + 1))
		game.call("_advance_opening_sequence")
	_check(str(game.get("opening_phase")) == "scene01_pre_dialogue", "monologue ends before hallway dialogue")
	_check(hall.get("cinematic_camera").current == true and actor.camera.current == false,
		"external establishing camera takes over after the black-screen monologue")
	for expected in [["Bảo", "Ê, về thôi!"], ["Hoàng", "Đợi chút. Cái gì kia?"]]:
		_check(str(game.get("opening_speaker").text) == expected[0]
			and str(game.get("opening_subtitle").text) == expected[1],
			"Scene 01 pre-pickup dialogue is exact and ordered: %s" % expected[0])
		game.call("_advance_opening_sequence")
	_check(str(game.get("opening_phase")) == "scene01_find_letter", "player control hands off for manual letter pickup")
	_check(actor.get("controls_enabled") == true, "player controls are enabled for the approach")
	_check(_is_first_person(actor), "gameplay camera is first-person when movement controls return")

	var letter := hall.get("letter") as Node3D
	_check(letter != null, "hallway contains a physical envelope")
	if letter == null:
		_finish()
		return
	actor.call("teleport_to", letter.position + Vector3(0, 0, .7))
	await physics_frame
	_check(hall.call("near_letter") == true, "player must physically approach the letter")
	game.call("_interact")
	_check(game.get("letter_found") == true, "E interaction collects the envelope")
	_check(state.inventory.has("mysterious_letter"), "collected envelope is stored in inventory")
	_check(str(state.evidence.get("mysterious_letter", "")) == "front_read",
		"only the front-message reveal is recorded for the letter")
	var letter_card := game.get("opening_letter_card") as Control
	var letter_contents := game.get("opening_letter_contents") as Label
	_check(letter_card != null and letter_card.visible, "letter fragment reveal is visibly gated after pickup")
	_check(letter_contents != null and letter_contents.text == "CỨU TÔI", "Scene 01 reveals only the short SOS message")
	_check(letter_contents != null and not letter_contents.text.contains("Nhà vệ sinh tầng 3")
		and not letter_contents.text.contains("11 giờ tối nay"),
		"Scene 01 does not reveal the destination or meeting time")
	await create_timer(.6).timeout
	_check(_count_red_reveal_labels(hall) == 0, "pickup does not activate the red reveal")
	_check(_count_red_reveal_labels(hall) == 0, "pickup creates no red rescue lettering in the hallway")
	var close_letter := InputEventKey.new()
	close_letter.keycode = KEY_ESCAPE
	close_letter.pressed = true
	game.call("_unhandled_input", close_letter)
	_check(letter_card != null and not letter_card.visible, "Esc closes the held-letter text view")
	_check(game.get("opening_card").visible == true, "closing the letter returns to the dialogue subtitle")
	_check(str(game.get("opening_speaker").text) == "Hoàng"
		and str(game.get("opening_subtitle").text) == "Lần sau viết SOS nhé.",
		"Hoang's SOS remark follows closing the letter")
	game.call("_advance_opening_sequence")

	var pickup_dialogue := [
		["Bảo", "Thư tình à?"],
		["Hoàng", "Không ghi tên."],
		["Huân", "Không liên quan thì bỏ đi."],
		["Lân", "Về thôi, trễ rồi."],
	]
	for expected in pickup_dialogue:
		_check(str(game.get("opening_speaker").text) == expected[0]
			and str(game.get("opening_subtitle").text) == expected[1],
			"post-pickup dialogue is exact and ordered: %s" % expected[0])
		game.call("_advance_opening_sequence")
	_check(str(game.get("opening_phase")) == "scene01_pocket_wait",
		"pocket animation starts only after the post-pickup conversation")
	_check(state.flags.get("letter_kept", false) == true,
		"letter-kept story flag is saved when pocketing begins")
	_check(_count_red_reveal_labels(hall) == 0, "pocketing still does not turn the world red")
	game.call("_on_scene01_pocket_finished")

	# Step the cinematic controller through knock, reaction, and the empty-stair beat.
	game.call("_process_opening_sequence", .13)
	_check(str(game.get("opening_phase")) == "scene01_knock_reaction", "upstairs knock triggers a reaction beat")
	var knock_player := hall.get("upstairs_knock_player") as AudioStreamPlayer3D
	_check(knock_player != null and knock_player.stream != null, "an upstairs knock sound source exists")
	game.call("_process_opening_sequence", .5)
	_check(str(game.get("opening_phase")) == "scene01_empty_hall", "camera holds on the empty upstairs area")
	_check(hall.find_child("An", true, false) == null, "no apparition is introduced at the stairwell")
	_check(_count_red_reveal_labels(hall) == 0, "stairwell beat remains free of the red transition")
	game.call("_process_opening_sequence", .3)
	await create_timer(.6).timeout
	_check(str(game.get("opening_phase")) == "classroom_establish", "Scene 01 fades into Scene 02")
	_check(state.flags.get("scene_01_completed", false) == true, "Scene 01 completion is recorded")

	var classroom: Node = game.get("classroom_visual")
	_check(classroom != null and classroom.visible, "Scene 02 classroom scene is active")
	if classroom == null:
		_finish()
		return
	var classroom_actor := classroom.get("actor") as CharacterBody3D
	_check(classroom_actor != null and classroom_actor.get("controls_enabled") == false,
		"Scene 02 keeps player movement disabled throughout its opening cinematic")
	classroom.call("set_opening_state", "message")
	_check(str(classroom.get("desk_message").text) == "CỨU TÔI"
		and classroom.get("desk_message").visible == true, "classroom desk message is readable and exact")
	var envelopes: Array = classroom.get("envelopes")
	_check(envelopes.size() == 4, "classroom contains exactly four matching envelope props")
	_check(_visible_envelope_count(envelopes) == 1, "only Hoang's envelope is visible before friends reveal theirs")

	await create_timer(1.7).timeout
	_check(not letter.visible, "pocket animation removes the envelope before the classroom dialogue")
	_check(str(game.get("opening_phase")) == "classroom_dialogue",
		"the classroom dialogue starts after the 3D establishing shot")
	var classroom_dialogue := [
		["Bảo", "Nghe nói tháng trước có một học sinh chết ở trường này."],
		["Hoàng", "Thật à?"],
		["Huân", "Tin đồn thôi."],
	]
	for expected in classroom_dialogue:
		_check(str(game.get("opening_speaker").text) == expected[0]
			and str(game.get("opening_subtitle").text) == expected[1],
			"Scene 02 dialogue is exact and ordered: %s" % expected[0])
		game.call("_advance_opening_sequence")
	game.call("_process_opening_sequence", 1.0)
	_check(_visible_envelope_count(envelopes) == 2, "first friend reveals an envelope after the rumor dialogue")
	game.call("_process_opening_sequence", 1.0)
	_check(_visible_envelope_count(envelopes) == 3, "second friend reveals an envelope in sequence")
	game.call("_process_opening_sequence", 1.0)
	_check(_visible_envelope_count(envelopes) == 4, "third friend reveal completes exactly four envelopes")
	game.call("_process_opening_sequence", 3.0)
	_check(str(game.get("opening_phase")) == "classroom_letter_contents", "Hoang opens the letter after silent realization")
	var full_letter := "LÀM ƠN CỨU TÔI.\n\nNhà vệ sinh tầng 3.\n11 giờ tối nay.\nXin đừng bỏ mặc tôi."
	_check(str(game.get("opening_subtitle").text) == full_letter, "full letter contents and Vietnamese text are exact")
	_check(classroom.get_node_or_null("ClassroomViewport/ClassroomWorld/ReadableLetterContents") != null
		or classroom.find_child("ReadableLetterContents", true, false) != null,
		"the opened letter has a readable in-world text prop")
	game.call("_advance_opening_sequence")
	_check(str(game.get("opening_speaker").text) == "Lân"
		and str(game.get("opening_subtitle").text) == "Tối nay... thật sao?", "Lân reacts after the letter is read")
	game.call("_advance_opening_sequence")
	_check(str(game.get("opening_speaker").text) == "Hoàng"
		and str(game.get("opening_subtitle").text) == "Tao muốn biết ai gửi thư.", "Hoang's decision follows Lan's reaction")
	game.call("_advance_opening_sequence")
	var monologue_timer := game.get("monologue_completion_timer") as Timer
	await create_timer(monologue_timer.wait_time + .15).timeout
	await process_frame
	_check(str(game.get("opening_phase")) == "" and game.beat == game.Beat.HALLWAY
		and game.active_room == "hallway", "completed black monologue hands off to the afternoon exit")
	_check(str(state.scene_id) == "scene_02" and str(state.checkpoint_id) == "afternoon_exit",
		"classroom completion checkpoints the afternoon exit, not the restroom")
	_check(str(state.evidence.get("invitation_location", "")) == "restroom_floor_3"
		and str(state.evidence.get("invitation_time", "")) == "23_00",
		"invitation still records the third-floor restroom meeting at 23:00")
	_check(bool(game.get("afternoon_exit_available")) and game.hallway_visual.get("actor").controls_enabled,
		"the player can now approach and open the after-school exit")

	var hallway_actor := game.hallway_visual.get("actor") as CharacterBody3D
	hallway_actor.teleport_to(Vector3(0, 0, -12.45))
	_check(bool(game.hallway_visual.call("near_restroom_door")), "the after-school exit can be reached")
	game.call("_interact")
	_check(bool(game.hallway_visual.get("restroom_door_open"))
		and bool(game.get("exit_transition_pending")), "E opens the after-school exit")
	hallway_actor.teleport_to(Vector3(0, 0, -13.8))
	game.call("_process", .01)
	await create_timer(.9).timeout
	var night_school: Node = game.get("night_school_visual")
	var night_actor := night_school.get("actor") as CharacterBody3D
	_check(game.beat == game.Beat.NIGHT_SCHOOL and str(game.get("night_phase")) == "yard",
		"crossing the exit enters the night-school yard")
	_check(str(state.checkpoint_id) == "night_school_yard"
		and str(state.story_time) == "22:55", "yard arrival records the night checkpoint and time")

	night_actor.teleport_to(Vector3(0, 0, -7.4))
	game.call("_interact")
	_check(str(game.get("night_phase")) == "ground_hall"
		and str(night_school.get("story_zone")) == "ground_hall", "E enters the school from the yard")
	night_actor.teleport_to(Vector3(-7, 0, -11.5))
	game.call("_interact")
	_check(str(game.get("night_phase")) == "stairs"
		and str(night_school.get("story_zone")) == "stairs", "E enters the stairwell")
	night_actor.teleport_to(Vector3(-7, 4.6, -24.3))
	game.call("_process_night_school", .01)
	night_school.call("_process", .01)
	_check(str(game.get("night_phase")) == "upper_hall", "reaching the third-floor landing unlocks the upper hall")
	night_actor.teleport_to(Vector3(5, 4.8, -26))
	_check(bool(night_school.call("near_restroom_door")), "the restroom door is reachable at the end of the upper hall")
	game.call("_interact")
	_check(str(game.get("night_phase")) == "entering_restroom"
		and bool(night_school.get("restroom_entry_open")), "E opens the third-floor restroom door")
	night_actor.teleport_to(Vector3(5, 4.8, -28.3))
	game.call("_process_night_school", .01)
	_check(str(night_school.get("story_zone")) == "restroom"
		and str(game.get("night_phase")) == "friend_bao_line",
		"crossing the restroom threshold enters the restroom sequence")
	_check(str(state.checkpoint_id) == "restroom_approach" and str(state.story_time) == "23:00",
		"restroom entry records the 23:00 third-floor checkpoint")

	_finish()


func _is_first_person(actor: CharacterBody3D) -> bool:
	var model := actor.get("model") as Node3D
	var arm := actor.get("spring_arm") as SpringArm3D
	var camera := actor.get("camera") as Camera3D
	return (
		model != null
		and not model.visible
		and arm != null
		and is_zero_approx(arm.spring_length)
		and camera != null
		and camera.current
		and camera.fov >= 60.0
	)


func _count_red_reveal_labels(hall: Node) -> int:
	var count := 0
	var world := hall.get("world") as Node3D
	if world == null:
		return count
	for child in world.get_children():
		if child is Label3D and (child as Label3D).text.strip_edges().to_upper() == "CỨU TÔI":
			count += 1
	return count


func _visible_envelope_count(items: Array) -> int:
	var count := 0
	for item in items:
		if item is Node3D and (item as Node3D).visible:
			count += 1
	return count


func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("OPENING_CINEMATIC_FAIL " + description)


func _finish() -> void:
	print("OPENING_CINEMATIC %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures else 0)
