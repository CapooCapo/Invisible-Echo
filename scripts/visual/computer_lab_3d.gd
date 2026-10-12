extends SubViewportContainer

## Physical computer lab. The story/puzzle state remains in digital_mystery.gd.
## The main CRT is the only terminal that can unlock the code-entry overlay.
const CONTROLLER: Script = preload("res://scripts/visual/hoang_controller_3d.gd")
const BEAT_COMPUTER := 0
const BEAT_CAMERA := 1
const BEAT_POST := 2
const BEAT_DEDUCTION := 3

var viewport: SubViewport
var world: Node3D
var actor: HoangController3D
var main_screen: Label3D
var main_screen_glow: OmniLight3D
var current_beat := BEAT_COMPUTER

var plaster: StandardMaterial3D
var damp: StandardMaterial3D
var tile_a: StandardMaterial3D
var tile_b: StandardMaterial3D
var concrete: StandardMaterial3D
var wood: StandardMaterial3D
var metal: StandardMaterial3D
var dark_plastic: StandardMaterial3D
var crt_shell: StandardMaterial3D
var screen_glass: StandardMaterial3D
var screen_green: StandardMaterial3D
var paper: StandardMaterial3D
var window: StandardMaterial3D


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "ComputerLabViewport"
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	world = Node3D.new()
	world.name = "VietnameseSchoolComputerLab"
	viewport.add_child(world)
	_make_materials()
	_make_environment()
	_make_room()
	_make_furniture()
	_make_school_details()
	actor = CONTROLLER.new() as HoangController3D
	world.add_child(actor)
	actor.teleport_to(Vector3(0, 0, 4.2))
	actor.controls_enabled = true
	set_beat(BEAT_COMPUTER)


func _mat(name: String, color: Color, roughness := .9, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name = name
	result.albedo_color = color
	result.roughness = roughness
	if emission != Color.BLACK:
		result.emission_enabled = true
		result.emission = emission
		result.emission_energy_multiplier = 1.5
	return result


func _make_materials() -> void:
	plaster = _mat("M_Lab_OldPlaster", Color("#b8b4aa"))
	plaster.albedo_texture = load("res://assets/materials/school/old_plaster.png") as Texture2D
	plaster.uv1_scale = Vector3(3, 3, 1)
	damp = _mat("M_Lab_DampBase", Color("#6e7775"))
	damp.albedo_texture = load("res://assets/materials/school/damp_base.png") as Texture2D
	tile_a = _mat("M_Lab_Tile_A", Color("#888d88"), .58)
	tile_a.albedo_texture = load("res://assets/materials/school/floor_ceramic.png") as Texture2D
	tile_b = _mat("M_Lab_Tile_B", Color("#757e7d"), .52)
	tile_b.albedo_texture = tile_a.albedo_texture
	concrete = _mat("M_Lab_Ceiling", Color("#777f80"))
	concrete.albedo_texture = load("res://assets/materials/school/ceiling_concrete.png") as Texture2D
	wood = _mat("M_Lab_WornWood", Color("#9a795e"))
	wood.albedo_texture = load("res://assets/materials/school/worn_wood.png") as Texture2D
	metal = _mat("M_Lab_DarkMetal", Color("#343d3e"), .68)
	dark_plastic = _mat("M_Lab_BlackPlastic", Color("#1a2224"), .65)
	crt_shell = _mat("M_Lab_AgedCRT", Color("#a4a79b"), .79)
	screen_glass = _mat("M_Lab_DarkScreen", Color("#0c2220"), .27)
	screen_green = _mat("M_Lab_GreenPhosphor", Color("#496b62"), .32, Color("#467a68"))
	paper = _mat("M_Lab_StainedPaper", Color("#c4bba5"))
	window = _mat("M_Lab_NightWindow", Color("#17212c"), .31)


func _box(name: String, pos: Vector3, size: Vector3, material: Material, shadow := true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var result := MeshInstance3D.new()
	result.name = name
	result.mesh = mesh
	result.material_override = material
	result.position = pos
	if not shadow:
		result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(result)
	return result


func _solid(name: String, pos: Vector3, size: Vector3, material: Material) -> void:
	_box(name, pos, size, material)
	var body := StaticBody3D.new()
	body.name = name + "_Collision"
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)


func _omni(name: String, pos: Vector3, color: Color, energy: float, radius: float, shadows := false) -> OmniLight3D:
	var result := OmniLight3D.new()
	result.name = name
	result.position = pos
	result.light_color = color
	result.light_energy = energy
	result.omni_range = radius
	result.shadow_enabled = shadows
	world.add_child(result)
	return result


func _label(name: String, value: String, pos: Vector3, font_size := 36, color: Color = Color("#c6c6b8")) -> Label3D:
	var result := Label3D.new()
	result.name = name
	result.text = value
	result.font_size = font_size
	result.pixel_size = .0016
	result.modulate = color
	result.position = pos
	result.no_depth_test = false
	world.add_child(result)
	return result


func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#071015")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#819aa5")
	env.ambient_light_energy = .39
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var node := WorldEnvironment.new()
	node.environment = env
	world.add_child(node)
	var moon := DirectionalLight3D.new()
	moon.name = "ColdWindowMoonlight"
	moon.rotation_degrees = Vector3(-45, -66, 0)
	moon.light_color = Color("#69849f")
	moon.light_energy = .27
	moon.shadow_enabled = true
	world.add_child(moon)
	for z in [3.25, -.4, -4.05]:
		_box("FluorescentHousing", Vector3(0, 3.10, z), Vector3(1.55, .10, .19), metal)
		var tube := _mat("M_Lab_Fluorescent", Color("#c1d3cc"), .43, Color("#8bb0ac"))
		_box("FluorescentTube", Vector3(0, 3.045, z), Vector3(1.42, .025, .11), tube, false)
		_omni("FlickeringCeilingLamp", Vector3(0, 2.81, z), Color("#b0c6ba"), .43 if z < 0 else .62, 5.0, z == -.4)
	_omni("NightAisleFill", Vector3(-3.6, 2.2, -2.9), Color("#697f9e"), .35, 6.0)


func _make_room() -> void:
	_solid("FloorSlab", Vector3(0, -.15, -.65), Vector3(10.2, .30, 13.7), concrete)
	_solid("Ceiling", Vector3(0, 3.26, -.65), Vector3(10.2, .18, 13.7), concrete)
	_solid("BackWall", Vector3(0, 1.63, -7.5), Vector3(10.2, 3.26, .18), plaster)
	_solid("EntranceWall", Vector3(0, 1.63, 6.20), Vector3(10.2, 3.26, .18), plaster)
	_solid("RightWall", Vector3(5.1, 1.63, -.65), Vector3(.18, 3.26, 13.7), plaster)
	_solid("LeftWall", Vector3(-5.1, 1.63, -.65), Vector3(.18, 3.26, 13.7), plaster)
	_box("DampBackSkirting", Vector3(0, .33, -7.39), Vector3(10.0, .66, .03), damp)
	for x in [-5.0, 5.0]:
		_box("DampSideSkirting", Vector3(x, .34, -.65), Vector3(.03, .68, 13.4), damp)
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(.79, .029, .79)
	for parity in range(2):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tile_mesh
		mm.instance_count = 12 * 17 / 2
		var index := 0
		for z in range(17):
			for x in range(12):
				if (x + z) % 2 != parity:
					continue
				mm.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(-4.52 + x * .82, .015, 5.90 - z * .82)))
				index += 1
		var node := MultiMeshInstance3D.new()
		node.name = "WeatheredFloorTiles_%d" % parity
		node.multimesh = mm
		node.material_override = tile_a if parity == 0 else tile_b
		world.add_child(node)
	# Windows are physically framed in the left wall, with night glass over
	# plaster. They contribute spatial rhythm rather than a flat backdrop.
	for z in [3.1, -.25, -3.6]:
		_box("WindowRecess", Vector3(-4.98, 1.92, z), Vector3(.055, 1.72, 2.5), dark_plastic)
		_box("BlueNightGlass", Vector3(-4.945, 1.92, z), Vector3(.017, 1.56, 2.32), window, false)
		for dz in [-1.19, 0, 1.19]:
			_box("WindowMullion", Vector3(-4.90, 1.92, z + dz), Vector3(.06, 1.74, .055), metal)
		_box("WindowCrossbar", Vector3(-4.90, 1.90, z), Vector3(.06, .055, 2.4), metal)
	_box("ClassBoardFrame", Vector3(0, 1.92, -7.36), Vector3(4.80, 1.54, .06), wood)
	_box("ClassBoard", Vector3(0, 1.92, -7.31), Vector3(4.62, 1.37, .05), _mat("M_Lab_Chalkboard", Color("#1b3731")))
	_label("ClassroomSlogan", "TIÊN HỌC LỄ - HẬU HỌC VĂN", Vector3(0, 2.90, -7.28), 32, Color("#b7a66e"))
	_box("EntranceDoor", Vector3(3.36, 1.25, 6.075), Vector3(1.48, 2.42, .09), wood)
	_box("DoorGlass", Vector3(3.36, 1.84, 6.01), Vector3(.92, .86, .025), window, false)
	_label("RoomNumber", "PHÒNG TIN HỌC", Vector3(3.36, 2.76, 6.01), 28)


func _make_furniture() -> void:
	# Two desk banks leave an unobstructed 1.9 m central aisle.
	for row in range(3):
		var z := 2.45 - row * 2.75
		for side in [-1, 1]:
			var x := float(side) * 2.45
			var tag := "R%d_%s" % [row, "L" if side < 0 else "R"]
			_make_desk(tag, x, z)
			_make_crt(tag, x, z)
			_make_chair(tag, x, z + .92)
			if row != 0 or side < 0:
				_make_books(tag, x + .78, z - .03)
			_omni("CRTGlow_" + tag, Vector3(x, 1.47, z - .12), Color("#5ca98b"), .16, 1.55)
	# A real printer/cabinet cluster against the rear-right wall.
	_solid("PrinterCabinet", Vector3(4.24, .55, -5.75), Vector3(.92, 1.1, 1.12), wood)
	_solid("PrinterBody", Vector3(4.25, 1.27, -5.75), Vector3(.72, .38, .77), crt_shell)
	_box("PrinterOutputSlot", Vector3(4.25, 1.26, -5.30), Vector3(.53, .045, .02), dark_plastic)
	_box("PrinterPaper", Vector3(4.25, 1.45, -5.69), Vector3(.40, .015, .42), paper, false)


func _make_desk(tag: String, x: float, z: float) -> void:
	_solid("DeskTop_" + tag, Vector3(x, .78, z), Vector3(2.45, .10, .84), wood)
	for dx in [-1.05, 1.05]:
		for dz in [-.30, .30]:
			_box("DeskLeg_" + tag, Vector3(x + dx, .37, z + dz), Vector3(.055, .73, .055), metal)
	_box("DeskRearBrace_" + tag, Vector3(x, .32, z - .31), Vector3(2.12, .055, .055), metal)
	_box("Keyboard_" + tag, Vector3(x, .86, z + .20), Vector3(.55, .035, .16), crt_shell)
	for key in range(7):
		_box("Key_" + tag, Vector3(x - .22 + key * .073, .885, z + .20), Vector3(.038, .006, .042), damp, false)
	_box("Mouse_" + tag, Vector3(x + .47, .875, z + .23), Vector3(.105, .055, .15), crt_shell)


func _make_crt(tag: String, x: float, z: float) -> void:
	_box("CRTStand_" + tag, Vector3(x, .88, z - .19), Vector3(.28, .13, .25), crt_shell)
	_solid("CRTBezel_" + tag, Vector3(x, 1.22, z - .24), Vector3(.77, .59, .45), crt_shell)
	_box("CRTScreen_" + tag, Vector3(x, 1.24, z + .003), Vector3(.62, .43, .015), screen_glass, false)
	_box("CRTPhosphor_" + tag, Vector3(x, 1.24, z + .014), Vector3(.56, .36, .008), screen_green, false)
	_box("CRTPowerButton_" + tag, Vector3(x + .32, .99, z + .018), Vector3(.018, .018, .008), dark_plastic, false)
	_solid("PCBeigeTower_" + tag, Vector3(x + .82, .39, z - .14), Vector3(.32, .70, .55), crt_shell)
	_box("PCTowerSlot_" + tag, Vector3(x + .82, .54, z + .141), Vector3(.23, .026, .008), dark_plastic, false)
	if tag == "R0_R":
		main_screen = _label("InteractiveMonitorDisplay", "", Vector3(x, 1.25, z + .027), 22, Color("#b3f4c2"))
		main_screen_glow = _omni("MissionComputerGlow", Vector3(x, 1.44, z + .23), Color("#82d9af"), .37, 2.6)
	else:
		_label("CRTStatus_" + tag, "TIN HỌC\nC:\\>_", Vector3(x, 1.25, z + .027), 20, Color("#94d4aa"))


func _make_chair(tag: String, x: float, z: float) -> void:
	_solid("ChairSeat_" + tag, Vector3(x, .47, z), Vector3(.50, .085, .43), wood)
	_solid("ChairBack_" + tag, Vector3(x, .87, z + .19), Vector3(.50, .70, .065), wood)
	for dx in [-.20, .20]:
		for dz in [-.15, .15]:
			_box("ChairLeg_" + tag, Vector3(x + dx, .23, z + dz), Vector3(.042, .46, .042), metal)


func _make_books(tag: String, x: float, z: float) -> void:
	for i in range(3):
		_box("ExerciseBook_" + tag, Vector3(x, .85 + i * .026, z), Vector3(.26, .018, .31), paper, false)


func _make_school_details() -> void:
	_box("HCMPhotoFrame", Vector3(0, 2.71, -7.28), Vector3(.38, .46, .055), wood)
	_box("HCMPhotoInset", Vector3(0, 2.71, -7.24), Vector3(.31, .38, .012), paper, false)
	for z in [2.6, -.8, -4.2]:
		_box("LearningPoster", Vector3(5.0, 2.18, z), Vector3(.025, .80, .60), paper, false)
		_box("PosterLine", Vector3(4.975, 2.28, z), Vector3(.008, .025, .44), damp, false)
		_box("PosterLine", Vector3(4.975, 2.10, z), Vector3(.008, .025, .34), damp, false)
	for i in range(7):
		var x := -3.65 + i * 1.1
		_box("LooseSheet", Vector3(x, .038, -5.62 + (i % 3) * .55), Vector3(.23, .006, .31), paper, false)
	# Thin transparent patches pick up screen and lamp colors without obscuring tiles.
	var wet := _mat("M_Lab_WetPatch", Color(.29, .40, .38, .19), .14)
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for z in [2.0, -1.8, -5.4]:
		_box("WetFloorPatch", Vector3(.06, .035, z), Vector3(.82, .005, .48), wet, false)


func set_beat(beat: int) -> void:
	current_beat = clampi(beat, BEAT_COMPUTER, BEAT_DEDUCTION)
	if main_screen == null:
		return
	match current_beat:
		BEAT_COMPUTER:
			main_screen.text = "MÁY CHỦ\nC:\\>_"
			main_screen_glow.light_color = Color("#82d9af")
		BEAT_CAMERA:
			main_screen.text = "CAM 03\n23:17:06"
			main_screen_glow.light_color = Color("#8fdac3")
		BEAT_POST:
			main_screen.text = "DIỄN ĐÀN\nBẢN NHÁP"
			main_screen_glow.light_color = Color("#81b3d4")
		BEAT_DEDUCTION:
			main_screen.text = "DỮ KIỆN\n6 / 6"
			main_screen_glow.light_color = Color("#d3b98b")


func near_main_computer() -> bool:
	# Reach the unique archive terminal from the walkable side of its desk.
	# Vertical offset is ignored because the monitor sits above desk height.
	if actor == null:
		return false
	var flat_delta := Vector2(actor.position.x - 2.45, actor.position.z - 2.45)
	return flat_delta.length() <= 1.8


func get_player_position() -> Vector3:
	return actor.position if actor != null else Vector3.ZERO


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
