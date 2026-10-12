extends SubViewportContainer

## Physical first-slice corridor. The 2D coordinates are only a legacy/test
## projection; CharacterBody3D owns movement and proximity in normal play.
const CONTROLLER: Script = preload("res://scripts/visual/hoang_controller_3d.gd")
const W := 960.0
const H := 540.0

var viewport: SubViewport
var world: Node3D
var actor: HoangController3D
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
var blood_paint: StandardMaterial3D
var hallway_environment: Environment
var reveal_tint: ColorRect
var reveal_started := false
var reveal_labels: Array[Label3D] = []
var reveal_drips: Array[MeshInstance3D] = []


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "SpatialViewport"
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	reveal_tint = ColorRect.new()
	reveal_tint.name = "BloodRedWorldTint"
	reveal_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reveal_tint.color = Color(0.55, 0.015, 0.04, 0.28)
	reveal_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal_tint.visible = false
	viewport.add_child(reveal_tint)
	world = Node3D.new()
	world.name = "SchoolHallway"
	viewport.add_child(world)
	_make_materials()
	_make_environment()
	_make_architecture()
	_make_story_props()
	actor = CONTROLLER.new() as HoangController3D
	world.add_child(actor)
	actor.teleport_to(Vector3(0, 0, 3.25))


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
	concrete = _material("M_Ceiling_Concrete", Color("#303b49"))
	concrete.albedo_texture = load("res://assets/materials/school/ceiling_concrete.png") as Texture2D
	concrete.uv1_scale = Vector3(3,3,1)
	wall = _material("M_Wall_OldPaint", Color("#344f63"))
	wall.albedo_texture = load("res://assets/materials/school/old_plaster.png") as Texture2D
	wall.uv1_scale = Vector3(5,3,1)
	wall_lower = _material("M_Wall_DampLower", Color("#253b4b"))
	wall_lower.albedo_texture = load("res://assets/materials/school/damp_base.png") as Texture2D
	wall_lower.uv1_scale = Vector3(3,2,1)
	faded_paint = _material("M_Wall_FadedTrim", Color("#647b88"))
	faded_paint.albedo_texture = wall.albedo_texture
	tile_a = _material("M_Floor_Dark_Wood_A", Color("#493329"), 0.72)
	tile_a.albedo_texture = load("res://assets/materials/school/worn_wood.png") as Texture2D
	tile_a.uv1_scale = Vector3(1.1, 1.0, 1.0)
	tile_b = _material("M_Floor_Dark_Wood_B", Color("#39271f"), 0.78)
	tile_b.albedo_texture = tile_a.albedo_texture
	wood = _material("M_Door_WornWood", Color("#bb9f85"))
	wood.albedo_texture = load("res://assets/materials/school/worn_wood.png") as Texture2D
	dark_wood = _material("M_Door_Recess", Color("#1a1818"))
	metal = _material("M_Railing_OldMetal", Color("#c2c8c8"), 0.66)
	metal.albedo_texture = load("res://assets/materials/school/painted_metal.png") as Texture2D
	glass = _material("M_Window_BlackGlass", Color("#0a141d"), 0.22)
	paper = _material("M_Letter_Yellowed", Color("#c4b8a0"))
	aged_paper = _material("M_Notices_AgedPaper", Color("#a89b81"))
	blood_paint = _material("M_BloodWriting", Color("#b10a16"), 0.96)
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
	env.background_color = Color("#05080b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#405a70")
	env.ambient_light_energy = 0.20
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	hallway_environment = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	var moon := DirectionalLight3D.new()
	moon.name = "ColdMoonlight"
	moon.rotation_degrees = Vector3(-46, 28, 0)
	moon.light_color = Color("#6385a0")
	moon.light_energy = 0.14
	moon.shadow_enabled = true
	world.add_child(moon)


func _make_architecture() -> void:
	_static_box("FloorSlab", Vector3(0,-0.14,-3.6), Vector3(4.8,.28,19.8), concrete)
	_static_box("Ceiling", Vector3(0,3.35,-3.6), Vector3(4.8,.20,19.8), concrete)
	_static_box("ClassroomWall", Vector3(2.39,1.64,-3.6), Vector3(.2,3.3,19.8), wall)
	_static_box("ExteriorWall", Vector3(-2.39,1.64,-3.6), Vector3(.2,3.3,19.8), wall, &"ExteriorWallCollision")
	for side in [-1, 1]:
		var x_wall := float(side) * 2.27
		_box("Wall_DampBase_%d" % side, Vector3(x_wall,.42,-3.6), Vector3(.035,.8,19.7), wall_lower)
		_box("Wall_ChairRail_%d" % side, Vector3(x_wall,.87,-3.6), Vector3(.065,.055,19.7), faded_paint)
		_box("Wall_UpperTrim_%d" % side, Vector3(x_wall,2.92,-3.6), Vector3(.06,.045,19.7), faded_paint)
	_box("CeilingBeam", Vector3(0,3.17,-3.6), Vector3(4.6,.20,.28), wall_lower)
	for z in range(-12,7,3):
		_box("CrossBeam_%d" % z, Vector3(0,3.18,float(z)), Vector3(4.6,.16,.22), wall_lower)
		_box("FluorescentCase_%d" % z, Vector3(0,3.13,float(z)), Vector3(.17,.08,1.46), metal)
		_box("FluorescentTube_%d" % z, Vector3(0,3.075,float(z)), Vector3(.09,.025,1.37),
			_material("M_Fluorescent", Color("#a9c2cf"), .4, Color("#476b82")), false)
		_light("Lamp_%d" % z, Vector3(0,2.8,float(z)), Color("#aec6d2"), .28 if z % 2 else .16, 3.35, z == 0)
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
		_box("ClassroomSign_%d" % z, Vector3(2.09,2.72,float(z)), Vector3(.035,.17,.72), metal)
		_add_wall_label("LỚP 12A%d" % int(1 + (3-z)/4), Vector3(2.055,2.72,float(z)))
	for z in [2,-2,-6,-10]:
		var center := float(z)
		_box("LeftWindowFrame_%d" % z, Vector3(-2.25,1.94,center), Vector3(.12,1.42,1.88), faded_paint)
		_box("LeftWindowGlass_%d" % z, Vector3(-2.175,1.94,center), Vector3(.025,1.18,1.62), glass, false)
		_box("LeftWindowBarV_%d" % z, Vector3(-2.15,1.94,center), Vector3(.035,1.2,.035), metal)
		_box("LeftWindowBarH_%d" % z, Vector3(-2.15,1.94,center), Vector3(.035,.035,1.65), metal)
		_box("LeftWindowSill_%d" % z, Vector3(-2.19,1.18,center), Vector3(.18,.10,1.92), concrete)
	for z in [1,-3,-7,-11]:
		_make_noticeboard(z)
	for z in [0,-4,-8]:
		_box("RedAlarmFrame_%d" % z, Vector3(2.125,2.34,float(z)), Vector3(.07,.22,.25), dark_wood)
		_box("RedAlarm_%d" % z, Vector3(2.075,2.34,float(z)), Vector3(.035,.12,.15), red, false)
	_light("RedExitGlow", Vector3(.2,2.2,-12.7), Color("#a5222d"), 1.12, 4.2, true)
	_box("FarExitLeft", Vector3(-2.05,1.55,-13.38), Vector3(2.1,3.12,.13), dark_wood)
	_box("FarExitRight", Vector3(2.05,1.55,-13.38), Vector3(2.1,3.12,.13), dark_wood)
	_box("FarExitLintel", Vector3(0,2.92,-13.38), Vector3(2.0,.38,.13), dark_wood)
	_box("ExitDoor", Vector3(.1,1.38,-13.27), Vector3(1.55,2.63,.05), wood)
	_box("ExitWindow", Vector3(.1,1.96,-13.225), Vector3(.66,.59,.015), red, false)
	_box("ExitWindowBar", Vector3(.1,1.96,-13.20), Vector3(.75,.045,.018), metal)
	_box("ExitDoorHandle", Vector3(-.48,1.17,-13.18), Vector3(.07,.035,.08), metal)
	# The end door is a physical obstacle until interacted with; its frame
	# leaves an actual opening after the door body is disabled.
	_static_box("EndWallLeft", Vector3(-2.05,1.55,-13.37), Vector3(2.1,3.1,.18), wall)
	_static_box("EndWallRight", Vector3(2.05,1.55,-13.37), Vector3(2.1,3.1,.18), wall)
	_static_box("EndWallTop", Vector3(0,2.92,-13.37), Vector3(2.0,.4,.18), wall)
	_static_box("ExitLanding", Vector3(0,-.14,-14.05), Vector3(2.0,.28,1.8), concrete)
	restroom_door = StaticBody3D.new()
	restroom_door.name = "RestroomDoorCollision"
	restroom_door.position = Vector3(0,1.3,-13.27)
	var door_shape := CollisionShape3D.new()
	door_shape.name = "DoorCollisionShape"
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(1.85,2.6,.15)
	door_shape.shape = door_box
	restroom_door.add_child(door_shape)
	world.add_child(restroom_door)
	_make_floor_tiles()
	_make_puddles()


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
	label.font_size = 38
	label.pixel_size = .0017
	label.modulate = Color("#d6c7a5")
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
	letter = Node3D.new()
	letter.name = "FoldedLetter3D"
	letter.position = Vector3(0,.045,0)
	world.add_child(letter)
	var letter_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.32,.008,.22)
	letter_mesh.mesh = mesh
	letter_mesh.material_override = paper
	letter_mesh.rotation_degrees.y = -17
	letter.add_child(letter_mesh)
	for side in [-1, 1]:
		var plea := Label3D.new()
		plea.name = "BloodPlea_%d" % side
		plea.text = "CỨU TÔI"
		plea.font_size = 72
		plea.pixel_size = .0055
		plea.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		plea.modulate = Color("#ad0713")
		plea.outline_size = 5
		plea.outline_modulate = Color("#280009")
		# Slightly inset from existing trim while staying visually wall-mounted.
		var writing_z := -4.0 if side < 0 else -3.0
		plea.position = Vector3(-2.12 if side < 0 else 1.99, 2.8, writing_z)
		plea.rotation.y = PI / 2.0 if side < 0 else -PI / 2.0
		plea.visible = false
		world.add_child(plea)
		reveal_labels.append(plea)
		for drip_index in range(4):
			var drip_offset: float = [-0.55, -0.18, 0.24, 0.58][drip_index]
			var drip_length: float = [0.13, 0.22, 0.16, 0.1][drip_index]
			var drip := _box("BloodDrip_%d_%d" % [side, drip_index],
				Vector3(-2.105 if side < 0 else 1.975, 2.58 - drip_length * 0.5,
					writing_z + float(side) * drip_offset),
				Vector3(.012, drip_length, .04), blood_paint, false)
			drip.visible = false
			reveal_drips.append(drip)
	_light("LetterReadability", Vector3(0,1.4,0), Color("#edd2a3"), .58, 2.8)
	_box("DiscardedDesk", Vector3(2.42,.56,-7.1), Vector3(.96,.07,.54), wood)
	for x in [2.04,2.8]:
		for z in [-7.31,-6.9]:
			_box("DeskLeg", Vector3(x,.27,z), Vector3(.045,.52,.045), metal)
	for z in [1.2,-2.6,-6.4]:
		_box("ScatteredPaper", Vector3(2.55,.041,z), Vector3(.20,.005,.27), paper, false)


func set_player_from_prototype(pos: Vector2) -> void:
	var mapped := Vector3(clampf((pos.x - 492.0) / 145.0, -2.55, 2.55), 0,
		clampf((pos.y - 291.0) / 35.0, -5.4, 4.7))
	if actor != null:
		actor.teleport_to(mapped)


func get_player_position() -> Vector3:
	return actor.position if actor != null else Vector3.ZERO


func get_projected_position() -> Vector2:
	var pos := get_player_position()
	return Vector2(pos.x * 145.0 + 492.0, pos.z * 35.0 + 291.0)


func near_letter() -> bool:
	return actor != null and actor.position.distance_to(Vector3.ZERO) < 1.12


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


func is_interacting() -> bool:
	return actor != null and actor.is_interacting()


func set_letter_visible(is_visible: bool) -> void:
	if letter != null:
		letter.visible = is_visible


func play_letter_reveal() -> void:
	if not _apply_letter_reveal_world():
		return
	if actor != null:
		actor.play_letter_reveal()


func restore_letter_reveal() -> void:
	# A scene-02 checkpoint needs the persistent result, not pickup shake/tween.
	if not _apply_letter_reveal_world():
		return
	if actor != null:
		actor.restore_letter_reveal()


func _apply_letter_reveal_world() -> bool:
	if reveal_started:
		return false
	reveal_started = true
	letter.visible = false
	for plea in reveal_labels:
		plea.visible = true
	for drip in reveal_drips:
		drip.visible = true
	reveal_tint.visible = true
	if hallway_environment != null:
		hallway_environment.ambient_light_color = Color("#8d1828")
		hallway_environment.ambient_light_energy = .62
	for node in world.get_children():
		if node is OmniLight3D:
			var light := node as OmniLight3D
			light.light_color = Color("#e3233b")
			light.light_energy *= 1.6
	return true
