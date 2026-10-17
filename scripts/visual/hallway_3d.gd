extends SubViewportContainer

## Physical first-slice corridor. The 2D coordinates are only a legacy/test
## projection; CharacterBody3D owns movement and proximity in normal play.
const CONTROLLER: Script = preload("res://scripts/visual/hoang_controller_3d.gd")
const W := 960.0
const H := 540.0

var viewport: SubViewport
var world: Node3D
var actor: HoangController3D
var cinematic_camera: Camera3D
var letter: Node3D
var restroom_door: StaticBody3D
var restroom_door_open := false

var concrete: StandardMaterial3D
var wall: StandardMaterial3D
var wall_lower: StandardMaterial3D
var tile_a: StandardMaterial3D
var tile_b: StandardMaterial3D
var wood: StandardMaterial3D
var dark_wood: StandardMaterial3D
var metal: StandardMaterial3D
var glass: StandardMaterial3D
var paper: StandardMaterial3D
var red: StandardMaterial3D
var faded_paint: StandardMaterial3D
var notice_green: StandardMaterial3D
var aged_paper: StandardMaterial3D
var hallway_environment: Environment
var standalone_mode := false
var letter_prompt: Label3D
var letter_glow: OmniLight3D
var letter_idle_time := 0.0
var friends: Array[Node3D] = []
var friend_animations: Array[AnimationPlayer] = []
var friend_destinations: Array[Vector3] = []
var upstairs_knock_player: AudioStreamPlayer3D
var pickup_elapsed := -1.0
var letter_in_hand := false
var letter_being_pocketed := false


func _ready() -> void:
	# F6 makes this scene a direct child of the scene-tree root. When it is
	# embedded by game.gd, that parent owns input and the story state instead.
	standalone_mode = get_parent() == get_tree().root
	if standalone_mode:
		_setup_standalone_input()
	# The serialized preview is outside the SubViewport so Godot's 3D scene
	# editor can display it. Runtime builds the same corridor inside its own
	# SubViewport; remove the editor copy before the first rendered frame.
	var editor_preview := get_node_or_null("EditorPreview3D")
	if editor_preview != null:
		remove_child(editor_preview)
		editor_preview.free()
	viewport = SubViewport.new()
	viewport.name = "SpatialViewport"
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	world = Node3D.new()
	world.name = "SchoolHallway"
	viewport.add_child(world)
	_make_materials()
	_make_environment()
	_make_architecture()
	_make_story_props()
	_make_opening_characters()
	_make_upstairs_knock()
	actor = CONTROLLER.new() as HoangController3D
	world.add_child(actor)
	actor.teleport_to(Vector3(0, 0, 3.25))
	_make_cinematic_camera()
	if standalone_mode:
		actor.controls_enabled = true


func _process(delta: float) -> void:
	if pickup_elapsed >= 0.0:
		pickup_elapsed -= delta
		if pickup_elapsed <= 0.0:
			pickup_elapsed = -1.0
			_attach_letter_to_bone("R_hand", Vector3(0.0, 0.0, 0.0))
			letter_in_hand = true
	if letter != null and letter.visible and not letter_in_hand and not letter_being_pocketed:
		letter_idle_time += delta
		letter.position.y = .045 + sin(letter_idle_time * 1.8) * .008
		var close_to_letter := near_letter()
		if letter_prompt != null:
			letter_prompt.visible = close_to_letter
		if letter_glow != null:
			letter_glow.light_energy = .36 + (sin(letter_idle_time * 2.4) + 1.0) * .09


func _setup_standalone_input() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"run": [KEY_SHIFT],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in bindings[action]:
			var already_bound := false
			for event in InputMap.action_get_events(action):
				if event is InputEventKey and (event.keycode == keycode or event.physical_keycode == keycode):
					already_bound = true
					break
			if not already_bound:
				var key := InputEventKey.new()
				key.keycode = keycode
				InputMap.action_add_event(action, key)


func _unhandled_input(event: InputEvent) -> void:
	if not standalone_mode or actor == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		actor.orbit_mouse(event.relative)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_E and near_letter():
			play_interaction()
			play_letter_reveal()
		elif event.keycode == KEY_F:
			actor.toggle_flashlight()


func _exit_tree() -> void:
	if standalone_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _material(name: String, color: Color, roughness: float = 0.92, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = name
	mat.albedo_color = color
	mat.roughness = roughness
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.5
	return mat


func _make_materials() -> void:
	concrete = _material("M_Ceiling_Concrete", Color("#454b4b"))
	concrete.albedo_texture = load("res://assets/materials/school/ceiling_concrete.png") as Texture2D
	concrete.uv1_scale = Vector3(3,3,1)
	wall = _material("M_Wall_OldPaint", Color("#777872"))
	wall.albedo_texture = load("res://assets/materials/school/old_plaster.png") as Texture2D
	wall.uv1_scale = Vector3(5,3,1)
	wall_lower = _material("M_Wall_DampLower", Color("#344b55"))
	wall_lower.albedo_texture = load("res://assets/materials/school/damp_base.png") as Texture2D
	wall_lower.uv1_scale = Vector3(3,2,1)
	faded_paint = _material("M_Wall_FadedTrim", Color("#53636a"))
	faded_paint.albedo_texture = wall.albedo_texture
	tile_a = _material("M_Floor_Old_Tile_A", Color("#493a32"), 0.58)
	tile_a.albedo_texture = load("res://assets/materials/school/worn_wood.png") as Texture2D
	tile_a.uv1_scale = Vector3(1.1, 1.0, 1.0)
	tile_b = _material("M_Floor_Old_Tile_B", Color("#332c29"), 0.64)
	tile_b.albedo_texture = tile_a.albedo_texture
	wood = _material("M_Door_WornWood", Color("#4b4038"))
	wood.albedo_texture = load("res://assets/materials/school/worn_wood.png") as Texture2D
	dark_wood = _material("M_Door_Recess", Color("#1a1818"))
	metal = _material("M_Railing_OldMetal", Color("#78858a"), 0.72)
	metal.albedo_texture = load("res://assets/materials/school/painted_metal.png") as Texture2D
	glass = _material("M_Window_NightGlass", Color("#0b1720"), 0.42)
	paper = _material("M_Letter_Yellowed", Color("#c4b8a0"))
	aged_paper = _material("M_Notices_AgedPaper", Color("#a89b81"))
	notice_green = _material("M_SchoolNoticeboard_Green", Color("#b9c5bd"))
	notice_green.albedo_texture = load("res://assets/materials/school/notice_felt.png") as Texture2D
	red = _material("M_DistantRed", Color("#341b20"), 0.7, Color("#61232d"))


func _box(name: String, at: Vector3, size: Vector3, mat: Material, cast_shadow := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	node.mesh = box_mesh
	node.material_override = mat
	node.position = at
	if not cast_shadow:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)
	return node


func _static_box(name: String, at: Vector3, size: Vector3, mat: Material, collision_name: StringName = &"") -> void:
	_box(name, at, size, mat)
	var body := StaticBody3D.new()
	body.name = String(collision_name) if not collision_name.is_empty() else name + "_Collision"
	body.position = at
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	world.add_child(body)


func _light(name: String, at: Vector3, color: Color, energy: float, range_m: float, shadows := false) -> void:
	var light := OmniLight3D.new()
	light.name = name
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadows
	world.add_child(light)


func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#08131c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7894a5")
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#172632")
	env.fog_density = .006
	hallway_environment = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.name = "ColdMoonlight"
	moon.rotation_degrees = Vector3(-46, 28, 0)
	moon.light_color = Color("#7898b0")
	moon.light_energy = 0.20
	moon.shadow_enabled = true
	world.add_child(moon)


func _make_architecture() -> void:
	_static_box("FloorSlab", Vector3(0,-0.14,-3.6), Vector3(4.8,.28,19.8), concrete)
	_static_box("Ceiling", Vector3(0,3.35,-3.6), Vector3(4.8,.20,19.8), concrete)
	_static_box("ClassroomWall", Vector3(2.39,1.64,-3.6), Vector3(.2,3.3,19.8), wall)
	# Keep the original full-height collision barrier, but hide its render mesh:
	# the exterior edge is an open colonnade, not a glazed/solid wall.
	var exterior_barrier_mesh := _box("ExteriorWall", Vector3(-2.39,1.64,-3.6), Vector3(.2,3.3,19.8), wall)
	exterior_barrier_mesh.visible = false
	var exterior_barrier := StaticBody3D.new()
	exterior_barrier.name = "ExteriorWallCollision"
	exterior_barrier.position = Vector3(-2.39,1.64,-3.6)
	var exterior_shape := CollisionShape3D.new()
	var exterior_box := BoxShape3D.new()
	exterior_box.size = Vector3(.2,3.3,19.8)
	exterior_shape.shape = exterior_box
	exterior_barrier.add_child(exterior_shape)
	world.add_child(exterior_barrier)
	for side in [-1, 1]:
		var x_wall := float(side) * 2.27
		if side == -1:
			# Waist-high plaster parapet keeps the familiar school corridor edge
			# while leaving each bay visibly open to the dark exterior.
			_box("ExteriorParapet", Vector3(x_wall,.39,-3.6), Vector3(.18,.78,19.65), wall_lower)
			_box("ExteriorParapetCap", Vector3(x_wall,.80,-3.6), Vector3(.23,.08,19.65), faded_paint)
			continue
		_box("Wall_DampBase_%d" % side, Vector3(x_wall,.42,-3.6), Vector3(.035,.8,19.7), wall_lower)
		_box("Wall_ChairRail_%d" % side, Vector3(x_wall,.87,-3.6), Vector3(.065,.055,19.7), faded_paint)
		_box("Wall_UpperTrim_%d" % side, Vector3(x_wall,2.92,-3.6), Vector3(.06,.045,19.7), faded_paint)
	for z in [5,-1,-4,-7,-10,-13]:
		_box("ExteriorColonnadePillar_%d" % z, Vector3(-2.31,1.62,float(z)), Vector3(.28,3.18,.30), wall)
	_box("CeilingBeam", Vector3(0,3.17,-3.6), Vector3(4.6,.20,.28), wall_lower)
	for z in range(-12,7,3):
		_box("CrossBeam_%d" % z, Vector3(0,3.18,float(z)), Vector3(4.6,.16,.22), wall_lower)
		_box("FluorescentCase_%d" % z, Vector3(0,3.13,float(z)), Vector3(.17,.08,1.46), metal)
		_box("FluorescentTube_%d" % z, Vector3(0,3.075,float(z)), Vector3(.09,.025,1.37),
			_material("M_Fluorescent", Color("#a9c2cf"), .4, Color("#476b82")), false)
		_light("Lamp_%d" % z, Vector3(0,2.8,float(z)), Color("#b9d8e8"), .58 if z % 2 else .22, 3.35, z == 0)
	for z in [3,-1,-5,-9]:
		_box("DoorLintel_%d" % z, Vector3(2.215,2.69,float(z)), Vector3(.15,.10,1.72), faded_paint)
		for edge in [-.82,.82]:
			_box("DoorJamb_%d_%d" % [z,int(edge*100)],
				Vector3(2.205,1.34,float(z)+edge), Vector3(.15,2.58,.09), faded_paint)
		_box("ClassDoorFrame_%d" % z, Vector3(2.26,1.35,float(z)), Vector3(.10,2.6,1.55), dark_wood)
		_box("ClassDoor_%d" % z, Vector3(2.19,1.32,float(z)), Vector3(.12,2.42,1.39), wood)
		_box("DoorWindow_%d" % z, Vector3(2.115,1.9,float(z)), Vector3(.025,.58,.78), glass, false)
		_box("DoorWindowMullion_%d" % z, Vector3(2.10,1.9,float(z)), Vector3(.035,.04,.79), metal)
		_box("DoorHandle_%d" % z, Vector3(2.10,1.15,float(z)-.52), Vector3(.09,.04,.1), metal)
		_box("ClassroomSign_%d" % z, Vector3(2.09,2.72,float(z)), Vector3(.035,.24,.98), aged_paper)
		var class_number := 3 - int((3 - z) / 4)
		_add_wall_label("LỚP 11A%d" % maxi(class_number, 1), Vector3(2.055,2.72,float(z)))
	# The old repeated window meshes on this side have been removed so the open
	# bays remain legible from the gameplay camera.
	for z in [1,-3,-7,-11]:
		_make_noticeboard(z)
	for z in [0,-4,-8]:
		# Keep the existing alarm above a wall-mounted fire cabinet; these are
		# visual-only meshes so the corridor's collision and routes stay intact.
		_box("PCCC_CabinetFrame_%d" % z, Vector3(2.13,.96,float(z)), Vector3(.10,.78,.48), dark_wood)
		_box("PCCC_Cabinet_%d" % z, Vector3(2.065,.96,float(z)), Vector3(.055,.70,.40), red, false)
		_box("PCCC_CabinetWindow_%d" % z, Vector3(2.025,1.00,float(z)), Vector3(.014,.27,.30), aged_paper, false)
		_add_wall_label("PCCC", Vector3(2.005,.99,float(z)))
		_box("RedAlarmFrame_%d" % z, Vector3(2.125,2.34,float(z)), Vector3(.07,.22,.25), dark_wood)
		_box("RedAlarm_%d" % z, Vector3(2.075,2.34,float(z)), Vector3(.035,.12,.15), red, false)
	_box("StairSignPlaque", Vector3(2.09,2.72,-11.25), Vector3(.035,.24,1.10), aged_paper)
	_add_wall_label("CẦU THANG", Vector3(2.055,2.72,-11.25))
	# Overhead wayfinding is visible from the corridor approach and points
	# forward toward the restroom door without changing any route geometry.
	_box("RestroomWayfindingPlaque", Vector3(0,2.72,-1.8), Vector3(1.55,.42,.055), aged_paper)
	var restroom_sign := Label3D.new()
	restroom_sign.name = "RestroomWayfindingSign"
	restroom_sign.text = "NHÀ VỆ SINH\n↓ CUỐI HÀNH LANG"
	restroom_sign.font_size = 28
	restroom_sign.pixel_size = .0022
	restroom_sign.modulate = Color("#20282b")
	restroom_sign.outline_size = 3
	restroom_sign.outline_modulate = Color("#c8bda7")
	restroom_sign.position = Vector3(0,2.72,-1.765)
	world.add_child(restroom_sign)
	# Seal the near end of the corridor. The player starts on the inside, so
	# this closes the visible opening without blocking the letter or exit route.
	_static_box("NearEntranceWall", Vector3(0,1.64,6.42), Vector3(4.8,3.3,.2), wall)
	_light("StairwellCoolSpill", Vector3(.2,2.2,-12.7), Color("#7895a7"), .20, 4.2, true)
	# Close the full end-wall opening; the narrower slab left a visible dark
	# strip on either side of the door when viewed down the corridor.
	_box("ExitDoor", Vector3(0,1.36,-13.27), Vector3(2.0,2.72,.05), wood)
	_box("ExitWindow", Vector3(.1,1.96,-13.225), Vector3(.66,.59,.015), glass, false)
	_box("ExitWindowBar", Vector3(.1,1.96,-13.20), Vector3(.75,.045,.018), metal)
	_box("ExitDoorHandle", Vector3(-.48,1.17,-13.18), Vector3(.07,.035,.08), metal)
	var exit_label := Label3D.new()
	exit_label.name = "AfternoonExitSign"
	exit_label.text = "CỬA THOÁT"
	exit_label.font_size = 28
	exit_label.pixel_size = .006
	exit_label.modulate = Color("#d1d7b0")
	exit_label.outline_size = 4
	exit_label.outline_modulate = Color("#171c1a")
	exit_label.position = Vector3(0,2.88,-13.12)
	world.add_child(exit_label)
	# The end door is a physical obstacle until interacted with; its frame
	# leaves an actual opening after the door body is disabled.
	_static_box("EndWallLeft", Vector3(-2.05,1.55,-13.37), Vector3(2.1,3.1,.18), wall)
	_static_box("EndWallRight", Vector3(2.05,1.55,-13.37), Vector3(2.1,3.1,.18), wall)
	_static_box("EndWallTop", Vector3(0,2.92,-13.37), Vector3(2.0,.4,.18), wall)
	_static_box("ExitLanding", Vector3(0,-.14,-14.05), Vector3(2.0,.28,1.8), concrete)
	restroom_door = StaticBody3D.new()
	restroom_door.name = "RestroomDoorCollision"
	restroom_door.position = Vector3(0,1.36,-13.27)
	var door_shape := CollisionShape3D.new()
	door_shape.name = "DoorCollisionShape"
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(2.0,2.72,.15)
	door_shape.shape = door_box
	restroom_door.add_child(door_shape)
	world.add_child(restroom_door)
	_make_floor_tiles()
	_make_puddles()
	_make_stairwell()


func _make_stairwell() -> void:
	# A compact visible flight and landing establish the upstairs source of the
	# later knock without placing a person or silhouette there.
	for i in range(7):
		var depth := -12.5 - float(i) * .42
		var rise := .12 + float(i) * .23
		_box("UpstairsStep_%d" % i, Vector3(1.1, rise, depth), Vector3(1.7, .18, .48), dark_wood)
	_box("StairwellLanding", Vector3(1.1, 1.78, -15.6), Vector3(2.0, .18, 1.1), concrete)
	_box("StairwellDarkUpper", Vector3(1.1, 2.45, -16.0), Vector3(2.0, 1.2, .12), dark_wood)


func _make_opening_characters() -> void:
	# Three named friends join Hoang. Their entrance finishes before player control.
	var specs := [
		["Bao", "res://assets/characters/npcs/bao.glb", Vector3(-1.15, 0, -2.6), 0.0],
		["Huan", "res://assets/characters/npcs/huan.glb", Vector3(-0.45, 0, -2.9), 0.0],
		["Lan", "res://assets/characters/npcs/lan.glb", Vector3(0.30, 0, -3.0), 0.0],
	]
	for spec in specs:
		var packed := load(spec[1]) as PackedScene
		if packed == null:
			continue
		var student := packed.instantiate() as Node3D
		student.name = spec[0]
		var destination: Vector3 = spec[2]
		student.position = destination + Vector3(0, 0, -2.5)
		student.rotation.y = PI
		student.scale = Vector3.ONE * 0.92
		world.add_child(student)
		friends.append(student)
		friend_destinations.append(destination)
		var animation := _find_animation_player(student)
		if animation != null:
			_play_named_animation(animation, "Idle")
			friend_animations.append(animation)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _make_upstairs_knock() -> void:
	upstairs_knock_player = AudioStreamPlayer3D.new()
	upstairs_knock_player.name = "UpstairsKnock"
	upstairs_knock_player.position = Vector3(1.1, 3.2, -15.5)
	upstairs_knock_player.max_distance = 28.0
	upstairs_knock_player.unit_size = 4.0
	upstairs_knock_player.volume_db = -3.0
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := PackedByteArray()
	var sample_count := 11025
	samples.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(wav.mix_rate)
		var envelope := exp(-t * 28.0) * minf(t * 75.0, 1.0)
		var value := sin(TAU * 76.0 * t) * 0.56 + sin(TAU * 113.0 * t) * 0.24
		var sample := int(clampf(value * envelope, -1.0, 1.0) * 23000.0)
		samples.encode_s16(i * 2, sample)
	wav.data = samples
	upstairs_knock_player.stream = wav
	world.add_child(upstairs_knock_player)


func _make_cinematic_camera() -> void:
	cinematic_camera = Camera3D.new()
	cinematic_camera.name = "OpeningCinematicCamera"
	cinematic_camera.fov = 58.0
	cinematic_camera.near = 0.08
	cinematic_camera.far = 60.0
	cinematic_camera.current = false
	world.add_child(cinematic_camera)


func play_upstairs_knock() -> void:
	if upstairs_knock_player != null:
		upstairs_knock_player.play()


func play_establishing_camera() -> void:
	if actor == null or cinematic_camera == null:
		return
	actor.model.visible = true
	actor.camera.current = false
	cinematic_camera.global_position = Vector3(0.0, 2.7, 9.4)
	cinematic_camera.look_at(Vector3(0.0, 1.15, -2.5))
	cinematic_camera.current = true
	var push_in := create_tween()
	push_in.tween_property(cinematic_camera, "position", Vector3(0.0, 2.7, 7.8), 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in friends.size():
		var friend := friends[i]
		var destination: Vector3 = friend_destinations[i]
		if i < friend_animations.size() and friend_animations[i] != null:
			_play_named_animation(friend_animations[i], "Walk")
		var entrance := create_tween()
		entrance.tween_property(friend, "position", destination, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if i < friend_animations.size() and friend_animations[i] != null:
			var idle_animation := friend_animations[i]
			entrance.tween_callback(_play_named_animation.bind(idle_animation, "Idle"))


func use_gameplay_camera() -> void:
	if actor != null and actor.camera != null:
		actor.set_third_person(false)
		actor.model.visible = false
		actor.camera.current = true
	if cinematic_camera != null:
		cinematic_camera.current = false
		cinematic_camera.visible = false


func play_pickup_camera() -> void:
	if actor == null or cinematic_camera == null:
		return
	actor.set_third_person(true)
	actor.model.visible = true
	actor.camera.current = false
	cinematic_camera.visible = true
	cinematic_camera.global_position = actor.global_position + Vector3(2.1, 1.8, -3.2)
	cinematic_camera.look_at(actor.global_position + Vector3(0.0, .95, 0.0))
	cinematic_camera.current = true


func end_pickup_camera() -> void:
	use_gameplay_camera()


func _play_named_animation(animation: AnimationPlayer, clip_name: String) -> void:
	for clip in animation.get_animation_list():
		if clip == clip_name or clip.ends_with("/" + clip_name):
			animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			animation.play(clip)
			return


func react_to_knock() -> void:
	if actor != null:
		actor.play_look_behind()
	for animation in friend_animations:
		if animation == null:
			continue
		for clip in animation.get_animation_list():
			if clip.ends_with("/Look_Behind") or clip == "Look_Behind":
				animation.play(clip)
				break


func play_friend_animation(friend_name: String, clip_name: String) -> void:
	for i in friends.size():
		if friends[i].name != friend_name or i >= friend_animations.size() or friend_animations[i] == null:
			continue
		for clip in friend_animations[i].get_animation_list():
			if clip == clip_name or clip.ends_with("/" + clip_name):
				friend_animations[i].play(clip)
				return


func play_player_interaction() -> void:
	if actor != null:
		actor.play_interaction(.85)


func _make_noticeboard(z: int) -> void:
	var center := float(z)
	_box("BoardFrame_%d" % z, Vector3(2.225,1.75,center), Vector3(.07,1.03,1.15), wood)
	_box("BoardFelt_%d" % z, Vector3(2.174,1.75,center), Vector3(.015,.91,1.03), notice_green, false)
	_add_wall_label("THÔNG BÁO", Vector3(2.145,2.08,center))
	for i in range(4):
		var column := i % 2
		var row := i / 2
		var paper_z := center - .27 + float(column)*.54
		var paper_y := 1.75 - float(row)*.27
		_box("Notice_%d_%d" % [z,i], Vector3(2.149,paper_y,paper_z),
			Vector3(.009,.19,.39), aged_paper if i == 1 else paper, false)
		_box("NoticeText_%d_%d" % [z,i], Vector3(2.138,paper_y+.012,paper_z),
			Vector3(.003,.008,.29), metal, false)
		_box("NoticePin_%d_%d" % [z,i], Vector3(2.135,paper_y+.08,paper_z),
			Vector3(.008,.012,.012), red, false)


func _add_wall_label(content: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.name = "VietnameseSign"
	label.text = content
	label.font_size = 42
	label.pixel_size = .0017
	label.modulate = Color("#22282a")
	label.outline_size = 3
	label.outline_modulate = Color("#a99f8b")
	label.position = at
	label.rotation.y = -PI / 2.0
	world.add_child(label)


func _make_puddles() -> void:
	var wet := _material("M_WetFloor_Patch", Color(.35,.44,.49,.23), .16)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for z in [2.1,-1.8,-6.4,-10.2]:
		_box("WetFloor_%d" % int(z*10), Vector3(-.55,.038,z), Vector3(.8,.006,.43), wet, false)


func _make_floor_tiles() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.775,.034,1.46)
	for parity in range(2):
		var mm := MultiMesh.new()
		mm.instance_count = 0
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = 6 * 13 / 2
		var index := 0
		for row in range(13):
			for col in range(6):
				if (row + col) % 2 != parity:
					continue
				var pos := Vector3(-1.95 + col*.79, .013, 5.7-row*1.5)
				mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, pos))
				index += 1
		var node := MultiMeshInstance3D.new()
		node.name = "WeatheredTiles_%d" % parity
		node.multimesh = mm
		node.material_override = tile_a if parity == 0 else tile_b
		world.add_child(node)


func _make_story_props() -> void:
	# An old metal locker sits along the wall; the unmarked envelope is tucked
	# at its base, matching the supplied reference rather than floating in the
	# middle of the corridor.
	var locker_mat := _material("M_Locker_DulledMetal", Color("#59605e"), .78)
	locker_mat.albedo_texture = load("res://assets/materials/school/painted_metal.png") as Texture2D
	_static_box("HallwayLocker", Vector3(1.98,.70,-7.1), Vector3(.58,1.4,1.0), locker_mat)
	_box("HallwayLockerSeam", Vector3(1.68,.70,-7.1), Vector3(.018,1.3,.025), metal, false)
	_box("HallwayLockerHandle", Vector3(1.66,.72,-6.84), Vector3(.025,.12,.035), metal, false)
	letter = Node3D.new()
	letter.name = "FoldedLetter3D"
	letter.position = Vector3(1.55,.045,-7.1)
	world.add_child(letter)
	var letter_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.32,.008,.22)
	letter_mesh.mesh = mesh
	letter_mesh.material_override = paper
	letter_mesh.rotation_degrees.y = -17
	letter.add_child(letter_mesh)
	# Envelope seams and a small wax mark make the clue read as a tangible
	# object before the player is close enough to interact.
	var envelope_ink := _material("M_Letter_FoldInk", Color("#766d5e"), .95)
	for seam in [
		[Vector3(-.075,.005,-.025), Vector3(.15,.002,.003), -18.0],
		[Vector3(.075,.005,-.025), Vector3(.15,.002,.003), 18.0],
		[Vector3(0,.005,.046), Vector3(.19,.002,.003), 0.0],
	]:
		var crease := MeshInstance3D.new()
		var crease_mesh := BoxMesh.new()
		crease_mesh.size = seam[1]
		crease.mesh = crease_mesh
		crease.material_override = envelope_ink
		crease.position = seam[0]
		crease.rotation_degrees.y = seam[2]
		letter.add_child(crease)
	var seal := MeshInstance3D.new()
	var seal_mesh := SphereMesh.new()
	seal_mesh.radius = .018
	seal_mesh.height = .012
	seal_mesh.radial_segments = 10
	seal_mesh.rings = 5
	seal.mesh = seal_mesh
	seal.material_override = envelope_ink
	seal.position = Vector3(.075,.012,.035)
	letter.add_child(seal)
	letter_prompt = Label3D.new()
	letter_prompt.name = "LetterInteractionPrompt"
	letter_prompt.text = "E  ·  NHẶT LÁ THƯ"
	letter_prompt.font_size = 30
	letter_prompt.pixel_size = .003
	letter_prompt.modulate = Color("#f0dfbd")
	letter_prompt.outline_size = 6
	letter_prompt.outline_modulate = Color("#101114")
	letter_prompt.position = Vector3(0,.37,0)
	letter_prompt.visible = false
	letter.add_child(letter_prompt)
	letter_glow = OmniLight3D.new()
	letter_glow.name = "LetterFocalLight"
	letter_glow.light_color = Color("#d6b88b")
	letter_glow.light_energy = .45
	letter_glow.omni_range = 1.4
	letter_glow.position = letter.position + Vector3(0,.32,0)
	world.add_child(letter_glow)
	_light("LetterReadability", letter.position + Vector3(0,1.25,0), Color("#edd2a3"), .58, 2.8)
	for z in [1.2,-2.6,-6.4]:
		_box("ScatteredPaper", Vector3(2.55,.041,z), Vector3(.20,.005,.27), paper, false)


func set_player_from_prototype(pos: Vector2) -> void:
	var mapped := Vector3(clampf((pos.x - 492.0) / 145.0, -2.55, 2.55), 0,
		clampf((pos.y - 291.0) / 35.0, -11.5, 4.7))
	if actor != null:
		actor.teleport_to(mapped)


func get_player_position() -> Vector3:
	return actor.position if actor != null else Vector3.ZERO


func get_projected_position() -> Vector2:
	var pos := get_player_position()
	return Vector2(pos.x * 145.0 + 492.0, pos.z * 35.0 + 291.0)


func near_letter() -> bool:
	return actor != null and letter != null and actor.position.distance_to(letter.position) < 1.12


func near_restroom_door() -> bool:
	return actor != null and actor.position.distance_to(Vector3(0,0,-12.45)) < 1.65


func open_restroom_door() -> void:
	if restroom_door_open:
		return
	restroom_door_open = true
	var shape := restroom_door.get_node("DoorCollisionShape") as CollisionShape3D
	shape.set_deferred("disabled", true)
	var door_mesh := world.get_node_or_null("ExitDoor") as MeshInstance3D
	if door_mesh != null:
		door_mesh.rotation.y = -PI / 2.0
		door_mesh.position.x = -.78


func set_controls_enabled(enabled: bool) -> void:
	if actor != null:
		actor.controls_enabled = enabled


func orbit_mouse(relative: Vector2) -> void:
	if actor != null:
		actor.orbit_mouse(relative)


func toggle_flashlight() -> void:
	if actor != null:
		actor.toggle_flashlight()


func play_interaction() -> void:
	if actor != null:
		actor.play_interaction()


func play_pickup() -> void:
	if actor == null or letter == null or letter_in_hand:
		return
	actor.controls_enabled = false
	actor.play_pickup()
	if letter_prompt != null:
		letter_prompt.visible = false
	pickup_elapsed = .52


func put_letter_away() -> Tween:
	if actor == null or letter == null or not letter_in_hand:
		return null
	actor.play_interaction(.82)
	_attach_letter_to_bone("pelvis", Vector3(.12, .12, -.12), false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(letter, "position", Vector3(.12, .12, -.12), .72).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(letter, "scale", Vector3(.2, .2, .2), .72)
	tween.chain().tween_callback(_finish_letter_pocket)
	letter_being_pocketed = true
	letter_in_hand = false
	return tween


func _finish_letter_pocket() -> void:
	if letter != null:
		letter.visible = false
	letter_being_pocketed = false


func _attach_letter_to_bone(bone_name: String, local_position: Vector3, snap_to_bone := true) -> void:
	if actor == null or actor.model == null or letter == null:
		return
	var skeleton := _find_skeleton(actor.model)
	if skeleton == null:
		letter.visible = false
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "LetterAttachment_%s" % bone_name
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	letter.reparent(attachment, true)
	if snap_to_bone:
		letter.position = local_position
		letter.rotation = Vector3.ZERO
		letter.scale = Vector3.ONE
	letter.visible = true


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


func is_interacting() -> bool:
	return actor != null and actor.is_interacting()


func set_letter_visible(is_visible: bool) -> void:
	if letter != null:
		letter.visible = is_visible


func play_letter_reveal() -> void:
	# The opening script deliberately leaves the envelope unopened. Kept as a
	# compatibility entry point for older callers, but never applies horror tint.
	if letter != null:
		letter.visible = false


func restore_letter_reveal() -> void:
	if letter != null:
		letter.visible = false
