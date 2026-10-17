extends SubViewportContainer

## Lightweight third-person classroom set for the four-letter story beat.
const CONTROLLER: Script = preload("res://scripts/visual/hoang_controller_3d.gd")
const PLAYER_START := Vector3(0.5, 0.0, 0.1)

var viewport: SubViewport
var world: Node3D
var actor: HoangController3D
var cinematic_camera: Camera3D
var duty_desk: StaticBody3D
var desk_light: OmniLight3D
var time := 0.0

var wall_mat: StandardMaterial3D
var floor_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var paper_mat: StandardMaterial3D
var chalk_mat: StandardMaterial3D
var desk_message: Label3D
var envelopes: Array[Node3D] = []
var classmates: Array[Node3D] = []
var classmate_animations: Array[AnimationPlayer] = []
var fan_rotor: Node3D


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "ClassroomViewport"
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	world = Node3D.new()
	world.name = "MorningClassroom"
	viewport.add_child(world)
	_make_materials()
	_make_environment()
	_make_room()
	_make_windows_and_board()
	_make_duty_desk()
	_make_letters()
	_make_classmates()
	actor = CONTROLLER.new() as HoangController3D
	world.add_child(actor)
	# Place the player facing the duty desk, within interaction range, so the
	# letters are immediately in view after the opening text is dismissed.
	actor.teleport_to(PLAYER_START)
	actor.model.visible = true
	actor.camera.current = false
	actor.set_idle_pose("Sit")
	actor.set_controls_enabled(false)
	cinematic_camera = Camera3D.new()
	cinematic_camera.name = "ClassroomCinematicCamera"
	cinematic_camera.fov = 58.0
	cinematic_camera.near = 0.08
	cinematic_camera.far = 60.0
	cinematic_camera.position = Vector3(0.5, 3.0, 5.6)
	cinematic_camera.current = true
	world.add_child(cinematic_camera)
	cinematic_camera.look_at(Vector3(0.0, 1.0, -1.4))


func _process(delta: float) -> void:
	time += delta
	if desk_light != null:
		var near := near_desk()
		desk_light.light_energy = (0.16 if near else 0.045) + 0.025 * (0.5 + 0.5 * sin(time * 2.1))
	if fan_rotor != null:
		fan_rotor.rotation.y = time * 2.1


func _material(name: String, color: Color, roughness := 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name
	material.albedo_color = color
	material.roughness = roughness
	return material


func _make_materials() -> void:
	floor_mat = _material("Classroom worn terrazzo", Color("#554339"), 0.82)
	floor_mat.albedo_texture = load("res://assets/materials/school/floor_ceramic.png") as Texture2D
	wall_mat = _material("Classroom stained ivory plaster", Color("#aaa695"), 0.94)
	wall_mat.albedo_texture = load("res://assets/materials/school/old_plaster.png") as Texture2D
	wall_mat.uv1_scale = Vector3(3, 2, 1)
	wood_mat = _material("Duty desk worn wood", Color("#443126"), 0.88)
	wood_mat.albedo_texture = load("res://assets/materials/school/worn_wood.png") as Texture2D
	wood_mat.uv1_scale = Vector3(2, 2, 1)
	paper_mat = _material("Old letter paper", Color("#d5cdb8"), 0.96)
	chalk_mat = _material("Chalkboard", Color("#20372e"), 0.96)


func _make_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#101923")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8190a1")
	environment.ambient_light_energy = 0.38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#18232c")
	environment.fog_density = 0.012
	var camera_env := WorldEnvironment.new()
	var resource := Environment.new()
	resource.background_mode = Environment.BG_COLOR
	resource.background_color = environment.background_color
	resource.ambient_light_source = environment.ambient_light_source
	resource.ambient_light_color = environment.ambient_light_color
	resource.ambient_light_energy = environment.ambient_light_energy
	resource.tonemap_mode = environment.tonemap_mode
	resource.fog_enabled = environment.fog_enabled
	resource.fog_light_color = environment.fog_light_color
	resource.fog_density = environment.fog_density
	camera_env.environment = resource
	world.add_child(camera_env)
	for x in [-2.7, 0.0, 2.7]:
		var lamp := OmniLight3D.new()
		lamp.name = "Cool fluorescent %s" % str(x)
		lamp.position = Vector3(x, 3.6, -0.2)
		lamp.light_color = Color("#b9d9e8")
		lamp.light_energy = 0.27 if x == 0.0 else 0.20
		lamp.omni_range = 5.6
		world.add_child(lamp)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon through classroom windows"
	moon.rotation_degrees = Vector3(-32, 28, 0)
	moon.light_color = Color("#7188ad")
	moon.light_energy = 0.24
	moon.shadow_enabled = true
	world.add_child(moon)


func _box(name: String, at: Vector3, size: Vector3, material: Material, solid := false) -> Node3D:
	var mesh := MeshInstance3D.new()
	mesh.name = name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	world.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.name = name + "Collision"
		body.position = at
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		world.add_child(body)
		body.collision_layer = 1
		body.collision_mask = 0
	return mesh


func _make_room() -> void:
	_box("Terrazzo floor", Vector3(0, -0.16, 0), Vector3(10, 0.3, 12), floor_mat, true)
	_box("Ceiling", Vector3(0, 4.05, 0), Vector3(10, 0.2, 12), wall_mat)
	_box("Front wall", Vector3(0, 2, 5.95), Vector3(10, 4, 0.2), wall_mat, true)
	_box("Back wall", Vector3(0, 2, -5.95), Vector3(10, 4, 0.2), wall_mat, true)
	_box("Left wall", Vector3(-4.95, 2, 0), Vector3(0.2, 4, 12), wall_mat, true)
	_box("Right wall", Vector3(4.95, 2, 0), Vector3(0.2, 4, 12), wall_mat, true)
	# Two-tone school paint: cool, worn blue-gray below the chair rail and dirty
	# ivory above, shared with the hallway and stairwell language.
	var lower_wall := _material("School blue-gray lower wall", Color("#3f5965"), 0.96)
	var trim := _material("Faded painted chair rail", Color("#66747a"), 0.9)
	_box("Front lower paint band", Vector3(0, 0.62, 5.82), Vector3(9.7, 1.24, .06), lower_wall)
	_box("Back lower paint band", Vector3(0, 0.62, -5.82), Vector3(9.7, 1.24, .06), lower_wall)
	for side_x in [-4.82, 4.82]:
		_box("Side lower paint band", Vector3(side_x, 0.62, 0), Vector3(.06, 1.24, 11.7), lower_wall)
		_box("Side chair rail", Vector3(side_x, 1.27, 0), Vector3(.09, .055, 11.7), trim)
	_box("Front chair rail", Vector3(0, 1.27, 5.79), Vector3(9.7, .055, .09), trim)
	_box("Back chair rail", Vector3(0, 1.27, -5.79), Vector3(9.7, .055, .09), trim)
	# Three rows of Vietnamese two-person desk forms; leave a broad center aisle
	# and the original approach to the teacher's desk unobstructed.
	var desk_steel := _material("Worn desk steel", Color("#41484a"), .78)
	var chair_steel := _material("Worn chair steel", Color("#566166"), .78)
	for row in range(3):
		for column in range(2):
			var x := -2.35 if column == 0 else 2.35
			var z := 1.75 - row * 1.78
			var desk_name := "Student desk %d-%d" % [row + 1, column + 1]
			_box(desk_name + " top", Vector3(x, 0.78, z), Vector3(1.48, 0.12, 0.78), wood_mat, true)
			for leg_x in [-0.60, 0.60]:
				for leg_z in [-0.25, 0.25]:
					_box(desk_name + " steel leg", Vector3(x + leg_x, 0.39, z + leg_z), Vector3(.055, .72, .055), desk_steel, true)
			_box("Desk front apron", Vector3(x, .66, z + .27), Vector3(1.36, .12, .05), wood_mat)
			# Simple chair immediately behind each desk, with a dark wood backrest
			# and painted metal tube legs rather than western classroom seating.
			var chair_z := z + .72
			_box("Student chair seat", Vector3(x, .48, chair_z), Vector3(.72, .09, .66), wood_mat)
			_box("Student chair back", Vector3(x, .91, chair_z + .28), Vector3(.72, .78, .08), wood_mat)
			for leg_x in [-.29, .29]:
				for leg_z in [-.24, .24]:
					_box("Student chair metal leg", Vector3(x + leg_x, .24, chair_z + leg_z), Vector3(.045, .48, .045), chair_steel)
	# Simple ceiling fan gives the otherwise ordinary morning room a quiet,
	# continuous environmental motion.
	fan_rotor = Node3D.new()
	fan_rotor.name = "CeilingFanRotor"
	fan_rotor.position = Vector3(0, 3.55, -.25)
	world.add_child(fan_rotor)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = .10
	hub_mesh.bottom_radius = .10
	hub_mesh.height = .16
	hub.mesh = hub_mesh
	hub.material_override = _material("Fan enamel", Color("#55544e"))
	fan_rotor.add_child(hub)
	for i in 3:
		var blade := MeshInstance3D.new()
		var blade_mesh := BoxMesh.new()
		blade_mesh.size = Vector3(.16, .035, .82)
		blade.mesh = blade_mesh
		blade.material_override = hub.material_override
		blade.position = Vector3(0, 0, -.43)
		blade.rotation.y = TAU * float(i) / 3.0
		fan_rotor.add_child(blade)


func _make_windows_and_board() -> void:
	# Large dark-green chalkboard and the school slogan/portrait composition from
	# the reference image, kept clear of the player's opening-note interaction.
	_box("Old green chalkboard", Vector3(-.45, 2.42, -5.78), Vector3(6.45, 1.72, .08), chalk_mat)
	_box("Chalkboard wood frame", Vector3(-.45, 2.42, -5.84), Vector3(6.62, 1.88, .06), wood_mat)
	_box("Chalkboard inner face", Vector3(-.45, 2.42, -5.72), Vector3(6.35, 1.62, .035), chalk_mat)
	_box("Chalk tray", Vector3(-.45, 1.52, -5.62), Vector3(6.45, .09, .16), wood_mat)
	var motto_board := _box("Classroom motto plaque", Vector3(0, 3.54, -5.72), Vector3(4.6, .34, .08), _material("Faded red motto cloth", Color("#54282a"), .9))
	_add_front_label(motto_board, "THI ĐUA DẠY TỐT - HỌC TỐT", Vector3(0, -.04, .055), Color("#d8c6a3"), 23)
	var portrait := _box("Teacher portrait frame", Vector3(0, 3.02, -5.66), Vector3(.62, .82, .08), wood_mat)
	_box("Teacher portrait", Vector3(0, 3.02, -5.60), Vector3(.49, .68, .025), _material("Faded portrait print", Color("#726b5b")))
	var class_info := _box("Class roster board", Vector3(3.82, 2.5, -5.77), Vector3(1.35, 1.65, .07), _material("Class roster dark board", Color("#24332f")))
	_add_front_label(class_info, "LỚP:\nSĨ SỐ:\nVẮNG:", Vector3(-.58, .33, .05), Color("#b8b7a9"), 18)
	var classroom_motto := _box("Classroom conduct poster", Vector3(-4.25, 2.20, -.6), Vector3(.08, 2.1, 1.25), paper_mat)
	_add_side_label(classroom_motto, "TIÊN HỌC LỄ\n\nHẬU HỌC VĂN", Vector3(.055, .35, 0), Color("#5a3533"), 17)
	# Dark, divided wooden windows look out onto the night from both side walls.
	var window_wood := _material("Dark classroom window wood", Color("#30251f"), .9)
	var night_glass := _material("Blue-black night glass", Color("#111e2c"), .22)
	for side_x in [-4.78, 4.78]:
		for z in [-3.35, .2, 3.65]:
			_box("Window dark glass", Vector3(side_x, 2.48, z), Vector3(.03, 1.35, 2.48), night_glass)
			for dz in [-1.27, 1.27]:
				_box("Window wood vertical", Vector3(side_x * .996, 2.48, z + dz), Vector3(.12, 1.62, .10), window_wood)
			for y in [1.69, 3.27]:
				_box("Window wood horizontal", Vector3(side_x * .996, y, z), Vector3(.12, .10, 2.58), window_wood)
			_box("Window central mullion", Vector3(side_x * .99, 2.48, z), Vector3(.13, 1.5, .10), window_wood)
			_box("Window center rail", Vector3(side_x * .99, 2.48, z), Vector3(.13, .10, 2.5), window_wood)
	# Wall-mounted fan cages and simple three-blade fans.
	for side_x in [-4.35, 4.35]:
		var fan := Node3D.new()
		fan.name = "WallFan"
		fan.position = Vector3(side_x, 2.75, -1.4)
		world.add_child(fan)
		var frame := MeshInstance3D.new()
		var hoop := TorusMesh.new()
		hoop.inner_radius = .31
		hoop.outer_radius = .36
		frame.mesh = hoop
		frame.material_override = _material("Old fan cage", Color("#3c4646"))
		frame.rotation.y = PI / 2.0 if side_x < 0.0 else -PI / 2.0
		fan.add_child(frame)
		for blade_index in range(3):
			var blade := MeshInstance3D.new()
			var blade_mesh := BoxMesh.new()
			blade_mesh.size = Vector3(.05, .39, .12)
			blade.mesh = blade_mesh
			blade.material_override = frame.material_override
			blade.rotation.z = TAU * float(blade_index) / 3.0
			blade.position = Vector3(.0, .0, .03)
			fan.add_child(blade)


func _add_front_label(parent: Node3D, text: String, at: Vector3, color: Color, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = .006
	label.modulate = color
	label.outline_size = 2
	label.outline_modulate = Color("#171b1b")
	label.position = at
	label.rotation.y = PI
	parent.add_child(label)


func _add_side_label(parent: Node3D, text: String, at: Vector3, color: Color, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = .006
	label.modulate = color
	label.outline_size = 2
	label.outline_modulate = Color("#171b1b")
	label.position = at
	label.rotation.y = -PI / 2.0
	parent.add_child(label)


func _make_duty_desk() -> void:
	duty_desk = StaticBody3D.new()
	duty_desk.name = "TeacherDutyDeskInteractable"
	duty_desk.position = Vector3(0, 0, -1.9)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.65, 0.95, 1.18)
	collision.position = Vector3(0, 0.47, 0)
	collision.shape = shape
	duty_desk.add_child(collision)
	world.add_child(duty_desk)
	_box("Teacher duty desk top", Vector3(0, 0.98, -1.9), Vector3(3.9, 0.16, 1.38), wood_mat)
	_box("Teacher desk front", Vector3(0, 0.48, -1.44), Vector3(3.55, 0.85, 0.18), wood_mat)
	for x in [-1.65, 1.65]:
		_box("Teacher desk side", Vector3(x, 0.48, -1.9), Vector3(0.18, 0.9, 1.2), wood_mat)
	desk_light = OmniLight3D.new()
	desk_light.name = "Letters faint warm highlight"
	desk_light.position = Vector3(0, 1.38, -1.85)
	desk_light.light_color = Color("#d7a675")
	desk_light.light_energy = 0.05
	desk_light.omni_range = 2.8
	world.add_child(desk_light)


func _make_letters() -> void:
	desk_message = Label3D.new()
	desk_message.name = "DeskMessage_CUU_TOI"
	desk_message.text = "CỨU TÔI"
	desk_message.font_size = 62
	desk_message.pixel_size = .0042
	desk_message.modulate = Color("#582d28")
	desk_message.rotation.x = -PI / 2.0
	desk_message.position = Vector3(0, 1.075, -1.88)
	desk_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desk_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desk_message.outline_size = 0
	world.add_child(desk_message)
	# The four matching physical envelopes are revealed in sequence. Only
	# Hoang's is present before the friends show theirs; no letter contents are
	# visible until the dedicated open-letter story beat.
	var positions := [Vector3(-1.15, 1.075, -1.88), Vector3(-2.45, .82, -1.1), Vector3(2.35, .82, -1.1), Vector3(.0, .82, -3.2)]
	for i in range(4):
		var envelope := Node3D.new()
		envelope.name = "MatchingEnvelope_%d" % (i + 1)
		envelope.position = positions[i]
		envelope.rotation.y = deg_to_rad(-8.0 + i * 4.0)
		var mesh := MeshInstance3D.new()
		mesh.name = "EnvelopePaper_%d" % (i + 1)
		var paper_shape := BoxMesh.new()
		paper_shape.size = Vector3(.42,.018,.29)
		mesh.mesh = paper_shape
		mesh.material_override = paper_mat
		envelope.add_child(mesh)
		var flap := MeshInstance3D.new()
		flap.name = "EnvelopeFlap_%d" % (i + 1)
		var flap_shape := BoxMesh.new()
		flap_shape.size = Vector3(.18,.005,.11)
		flap.mesh = flap_shape
		flap.material_override = _material("Envelope fold", Color("#b9ad96"))
		flap.position = Vector3(0,.012,-.04)
		envelope.add_child(flap)
		world.add_child(envelope)
		envelopes.append(envelope)
		if i > 0:
			envelope.visible = false


func _make_classmates() -> void:
	var specs := [
		["Bao", "res://assets/characters/npcs/bao.glb", Vector3(-2.35, 0, -1.15), "Sit"],
		["Huan", "res://assets/characters/npcs/huan.glb", Vector3(2.35, 0, -1.15), "Sit"],
		["Lan", "res://assets/characters/npcs/lan.glb", Vector3(0.0, 0, -3.15), "Sit"],
		["Background_01", "res://assets/characters/npcs/minh.glb", Vector3(-3.4, 0, -3.8), "Sit"],
		["Background_02", "res://assets/characters/npcs/bully_01.glb", Vector3(3.35, 0, -3.8), "Sit"],
		["Background_03", "res://assets/characters/npcs/bully_02.glb", Vector3(1.6, 0, -4.7), "Sit"],
	]
	for spec in specs:
		var packed := load(spec[1]) as PackedScene
		if packed == null:
			continue
		var student := packed.instantiate() as Node3D
		student.name = spec[0]
		student.position = spec[2]
		student.rotation.y = PI
		student.scale = Vector3.ONE * (.72 if str(spec[0]).begins_with("Background") else .82)
		world.add_child(student)
		classmates.append(student)
		var animation := _find_animation_player(student)
		classmate_animations.append(animation)
		if animation != null:
			for clip in animation.get_animation_list():
				if clip == "Sit" or clip.ends_with("/Sit"):
					animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
					animation.play(clip)
					break


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func set_opening_state(state: String) -> void:
	if desk_message != null:
		desk_message.visible = state in ["message", "dialogue", "remember", "reveal", "silence", "open_letter", "read_letter", "lan_react", "hoang_decision"]
	var reveal_through := 0
	if state.begins_with("reveal_"):
		reveal_through = int(state.trim_prefix("reveal_"))
	for i in envelopes.size():
		envelopes[i].visible = i <= reveal_through or state in ["all_envelopes", "silence", "open_letter", "read_letter", "lan_react", "hoang_decision"]
	if state == "reveal":
		for animation in classmate_animations:
			if animation != null:
				_play_named_animation(animation, "Pick_Up")
	elif state.begins_with("reveal_"):
		var reveal_index := int(state.trim_prefix("reveal_")) - 1
		if reveal_index >= 0 and reveal_index < classmate_animations.size() and classmate_animations[reveal_index] != null:
			_play_named_animation(classmate_animations[reveal_index], "Pick_Up")
	if state in ["silence", "open_letter", "read_letter", "lan_react", "hoang_decision"]:
		for animation in classmate_animations:
			if animation != null:
				_play_named_animation(animation, "Look_Behind")
	if state == "read_letter":
		var letter_text := Label3D.new()
		letter_text.name = "ReadableLetterContents"
		letter_text.text = "LÀM ƠN CỨU TÔI\n\nNhà vệ sinh tầng 3.\n11 giờ tối nay.\nXin đừng bỏ mặc tôi."
		letter_text.font_size = 32
		letter_text.pixel_size = .004
		letter_text.modulate = Color("#352c25")
		letter_text.outline_size = 0
		letter_text.position = Vector3(-1.15, 1.10, -1.88)
		letter_text.rotation.x = -PI / 2.0
		world.add_child(letter_text)
	elif world != null:
		var old_contents := world.get_node_or_null("ReadableLetterContents")
		if old_contents != null:
			old_contents.queue_free()


func play_establishing_shot() -> Tween:
	if cinematic_camera == null or desk_message == null:
		return null
	# Begin wide enough to read the classroom and the students surrounding Hoang,
	# then push to the writing before dialogue begins.
	actor.set_controls_enabled(false)
	actor.model.visible = true
	camera_set_current(false)
	cinematic_camera.current = true
	cinematic_camera.position = Vector3(4.4, 3.1, 4.7)
	cinematic_camera.look_at(Vector3(0.0, 1.0, -1.2))
	var focus_position := Vector3(0.65, 1.95, -0.05)
	var focus_transform := Transform3D(Basis.IDENTITY, focus_position).looking_at(
		desk_message.global_position + Vector3(0.0, 0.03, 0.0), Vector3.UP
	)
	var focus_rotation := focus_transform.basis.get_euler()
	var pan := create_tween()
	pan.tween_property(cinematic_camera, "position", focus_position, 1.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pan.parallel().tween_property(cinematic_camera, "rotation", focus_rotation, 1.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return pan

func return_to_group_view() -> Tween:
	if cinematic_camera == null:
		return null
	var target := Vector3(-2.9, 2.2, 3.1)
	var focus := Vector3(0.0, 1.0, -1.2)
	var transform := Transform3D(Basis.IDENTITY, target).looking_at(focus, Vector3.UP)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(cinematic_camera, "position", target, .45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cinematic_camera, "rotation", transform.basis.get_euler(), .45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func camera_set_current(enabled: bool) -> void:
	if actor != null and actor.camera != null:
		actor.camera.current = enabled


func _play_named_animation(animation: AnimationPlayer, clip_name: String) -> void:
	for clip in animation.get_animation_list():
		if clip == clip_name or clip.ends_with("/" + clip_name):
			animation.play(clip)
			return


func play_classmate_animation(student_name: String, clip_name: String) -> void:
	for i in classmates.size():
		if classmates[i].name == student_name and i < classmate_animations.size() and classmate_animations[i] != null:
			_play_named_animation(classmate_animations[i], clip_name)
			return


func play_player_interaction() -> void:
	if actor != null:
		actor.play_interaction(.85)


func near_desk() -> bool:
	if actor == null or duty_desk == null:
		return false
	var offset := actor.global_position - duty_desk.global_position
	return Vector2(offset.x, offset.z).length() <= 2.1


func set_controls_enabled(enabled: bool) -> void:
	if actor != null:
		actor.controls_enabled = enabled


func set_player_from_prototype(pos: Vector2) -> void:
	if actor != null:
		actor.teleport_to(Vector3(PLAYER_START.x + (pos.x - 480.0) / 95.0, 0, PLAYER_START.z + (pos.y - 405.0) / 100.0))


func get_projected_position() -> Vector2:
	if actor == null:
		return Vector2(480, 405)
	return Vector2(480.0 + (actor.global_position.x - PLAYER_START.x) * 95.0, 405.0 + (actor.global_position.z - PLAYER_START.z) * 100.0)


func orbit_mouse(relative: Vector2) -> void:
	if actor != null:
		actor.orbit_mouse(relative)


func toggle_flashlight() -> void:
	if actor != null:
		actor.toggle_flashlight()


func play_interaction() -> void:
	if actor != null:
		actor.play_interaction()
