extends SubViewportContainer

## Spatial-only chess-club backdrop. Gameplay and inventory remain owned by
## the existing scene; set_returned_count() drives the memory-light progression.
const HOANG: PackedScene = preload("res://assets/characters/hoang/hoang.glb")
const AN: PackedScene = preload("res://assets/characters/an/an.glb")

var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var an: Node3D
var hoang: Node3D
var memory_light: OmniLight3D
var candles: Array[Node3D] = []
var returned_count := 0

var plaster: StandardMaterial3D
var damp: StandardMaterial3D
var floor_wood: StandardMaterial3D
var shelf_wood: StandardMaterial3D
var dark_wood: StandardMaterial3D
var brass: StandardMaterial3D
var pewter: StandardMaterial3D
var ivory: StandardMaterial3D
var black_piece: StandardMaterial3D
var paper: StandardMaterial3D
var glass: StandardMaterial3D
var moon_glow: StandardMaterial3D
var flame: StandardMaterial3D


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "ChessClubViewport"
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	world = Node3D.new()
	world.name = "VietnameseSchoolChessClub"
	viewport.add_child(world)
	_make_materials()
	_make_environment()
	_make_room()
	_make_furniture()
	_make_chess_table(Vector3(.45, 0, -1.25), true)
	_make_chess_table(Vector3(3.15, 0, 2.25), false)
	_make_characters()
	camera = Camera3D.new()
	camera.name = "EntranceOverShoulderCamera"
	camera.position = Vector3(-3.42, 1.72, 4.6)
	camera.fov = 64.0
	camera.near = .08
	camera.far = 35.0
	camera.current = true
	world.add_child(camera)
	camera.look_at(Vector3(.45, 1.27, -1.55), Vector3.UP)
	set_returned_count(returned_count)


func _material(name: String, color: Color, roughness := .86, glow := Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = name
	mat.albedo_color = color
	mat.roughness = roughness
	if glow != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = 1.3
	return mat


func _make_materials() -> void:
	plaster = _material("M_ChessClub_OldPlaster", Color("#b9aea0"))
	plaster.albedo_texture = load("res://assets/materials/school/old_plaster.png") as Texture2D
	plaster.uv1_scale = Vector3(3, 2, 1)
	damp = _material("M_ChessClub_DampBase", Color("#74736e"))
	damp.albedo_texture = load("res://assets/materials/school/damp_base.png") as Texture2D
	floor_wood = _material("M_ChessClub_WornFloor", Color("#a48d79"), .62)
	floor_wood.albedo_texture = load("res://assets/materials/school/worn_wood.png") as Texture2D
	shelf_wood = _material("M_ChessClub_ShelfWood", Color("#715240"))
	shelf_wood.albedo_texture = floor_wood.albedo_texture
	dark_wood = _material("M_ChessClub_DarkWood", Color("#3d2b28"))
	brass = _material("M_ChessClub_AgedBrass", Color("#a98951"), .42)
	pewter = _material("M_ChessClub_Pewter", Color("#717778"), .44)
	ivory = _material("M_ChessClub_IvoryPieces", Color("#d8c6a2"), .59)
	black_piece = _material("M_ChessClub_DarkPieces", Color("#292b2b"), .46)
	paper = _material("M_ChessClub_AgedPaper", Color("#c7b796"))
	glass = _material("M_ChessClub_NightGlass", Color("#243141"), .19)
	moon_glow = _material("M_ChessClub_Moon", Color("#b9c4d1"), .73, Color("#7084a6"))
	flame = _material("M_ChessClub_CandleFlame", Color("#ffc477"), .2, Color("#ff9e38"))


func _box(name: String, at: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	(parent if parent != null else world).add_child(instance)
	return instance


func _cylinder(name: String, at: Vector3, top_radius: float, bottom_radius: float, height: float, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	(parent if parent != null else world).add_child(instance)
	return instance


func _static_box(name: String, at: Vector3, size: Vector3, mat: Material) -> void:
	_box(name, at, size, mat)
	var body := StaticBody3D.new()
	body.name = name + "Collision"
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)


func _light(name: String, at: Vector3, color: Color, energy: float, range_m: float, shadows := false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = name
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadows
	world.add_child(light)
	return light


func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#080d16")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8193ad")
	env.ambient_light_energy = .28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var node := WorldEnvironment.new()
	node.environment = env
	world.add_child(node)
	var moonlight := DirectionalLight3D.new()
	moonlight.name = "ColdMoonlightThroughWindow"
	moonlight.rotation_degrees = Vector3(-34, 28, 0)
	moonlight.light_color = Color("#8fa5ca")
	moonlight.light_energy = .42
	moonlight.shadow_enabled = true
	world.add_child(moonlight)
	memory_light = _light("ReturnedMemoriesWarmLight", Vector3(.3, 2.5, -1.0), Color("#ffc278"), 0.0, 6.5, true)
	_light("MoonWindowBounce", Vector3(.6, 2.4, -4.55), Color("#9badc8"), .67, 6.2)
	_light("DoorwayFill", Vector3(-3, 2.35, 3.3), Color("#a6a2a0"), .23, 4.5)


func _make_room() -> void:
	_static_box("SchoolFloor", Vector3(0, -.17, 0), Vector3(10.3, .34, 11.1), floor_wood)
	_static_box("SchoolCeiling", Vector3(0, 3.45, 0), Vector3(10.3, .18, 11.1), damp)
	_static_box("WestWall", Vector3(-5.16, 1.66, 0), Vector3(.22, 3.35, 11.1), plaster)
	_static_box("EastWall", Vector3(5.16, 1.66, 0), Vector3(.22, 3.35, 11.1), plaster)
	_static_box("SouthWall", Vector3(0, 1.66, 5.56), Vector3(10.3, 3.35, .22), plaster)
	# Window openings are framed by real wall sections rather than a flat room image.
	for x in [-4.15, 4.15]:
		_static_box("NorthWallPier", Vector3(x, 1.66, -5.56), Vector3(2.0, 3.35, .22), plaster)
	_static_box("NorthWindowSillWall", Vector3(0, .55, -5.56), Vector3(6.3, 1.12, .22), plaster)
	_static_box("NorthWindowHeaderWall", Vector3(0, 3.04, -5.56), Vector3(6.3, .59, .22), plaster)
	_box("NightWindowGlass", Vector3(0, 1.88, -5.59), Vector3(6.23, 1.86, .04), glass)
	for x in [-3.1, -1.55, 0.0, 1.55, 3.1]:
		_box("WeatheredWindowMullion", Vector3(x, 1.88, -5.48), Vector3(.075, 1.91, .15), dark_wood)
	for y in [1.0, 2.72]:
		_box("WeatheredWindowRail", Vector3(0, y, -5.48), Vector3(6.3, .085, .15), dark_wood)
	var moon := _cylinder("VisibleMoonBeyondWindow", Vector3(1.75, 2.57, -9.2), .42, .42, .035, moon_glow)
	moon.rotation.x = PI / 2.0
	for x in [-4.99, 4.99]:
		_box("DampWallSkirting", Vector3(x, .34, 0), Vector3(.065, .67, 10.8), damp)
	for z in [-5.38, 5.38]:
		_box("DampWallSkirting", Vector3(0, .34, z), Vector3(10.1, .67, .065), damp)
	for i in range(22):
		var z := -5.1 + i * .48
		_box("WornFloorPlank_%02d" % i, Vector3(0, .014, z), Vector3(10.08, .019, .455), floor_wood)
	_box("FluorescentFixture", Vector3(-.7, 3.30, .4), Vector3(1.33, .08, .17), pewter)
	_box("WeakFluorescentTube", Vector3(-.7, 3.25, .4), Vector3(1.17, .026, .08), moon_glow)
	_light("WeakFluorescent", Vector3(-.7, 3.08, .4), Color("#a2afbf"), .22, 4.0)
	_label("CÂU LẠC BỘ CỜ VUA", Vector3(4.995, 2.15, -1.9), -PI / 2.0, Color("#c8b691"))
	_make_club_notice()


func _label(content: String, at: Vector3, yaw: float, color: Color, size := 39) -> void:
	var label := Label3D.new()
	label.name = "SchoolClubSign"
	label.text = content
	label.font_size = size
	label.pixel_size = .002
	label.modulate = color
	label.position = at
	label.rotation.y = yaw
	world.add_child(label)


func _make_club_notice() -> void:
	_box("ClubNoticeBoard", Vector3(-5.03, 1.82, 1.35), Vector3(.08, 1.25, 1.65), shelf_wood)
	for i in range(4):
		_box("OldChessTournamentNotice_%d" % i, Vector3(-4.975, 2.13 - i * .24, 1.3 + (i % 2) * .2), Vector3(.018, .18, .56), paper)
	_box("FramedSchoolChessPoster", Vector3(-5.02, 2.12, -2.3), Vector3(.09, 1.24, 1.15), dark_wood)
	_box("SchoolChessPosterPaper", Vector3(-4.961, 2.12, -2.3), Vector3(.01, 1.08, 1.0), paper)
	_label("GIẢI CỜ VUA\n HỌC SINH", Vector3(-4.948, 2.13, -2.3), PI / 2.0, Color("#49382f"), 30)


func _make_furniture() -> void:
	_make_bookshelf(Vector3(-4.25, 0, -3.1), 0)
	_make_bookshelf(Vector3(-4.25, 0, -.7), 1)
	_make_bookshelf(Vector3(4.35, 0, -3.3), 2)
	_make_trophy_case(Vector3(4.3, 0, .4))
	_make_chair(Vector3(1.45, 0, -2.37), 0)
	_make_chair(Vector3(-.35, 0, .02), PI)
	_make_chair(Vector3(3.8, 0, 3.15), PI)
	for i in range(6):
		_box("AbandonedExerciseBook_%d" % i, Vector3(-2.15 + (i % 3) * .26, .045 + int(i / 3) * .025, 1.55 + int(i / 3) * .35), Vector3(.22, .023, .31), paper)


func _make_bookshelf(at: Vector3, index: int) -> void:
	var root := Node3D.new()
	root.name = "SchoolBookshelf_%d" % index
	root.position = at
	world.add_child(root)
	for x in [-.68, .68]:
		_box("ShelfUpright", Vector3(x, 1.13, 0), Vector3(.10, 2.25, .48), shelf_wood, root)
	for y in [.16, .72, 1.3, 1.88, 2.3]:
		_box("WoodShelf", Vector3(0, y, 0), Vector3(1.45, .085, .53), shelf_wood, root)
	for row in range(4):
		for book in range(9):
			var color := Color.from_hsv(fmod(.07 + (book * .113) + index * .07, 1.0), .28, .28 + (book % 3) * .09)
			var binding := _material("M_OldBook", color)
			_box("SchoolBook_%d_%d" % [row, book], Vector3(-.57 + book * .13, .19 + row * .58 + .13, .035), Vector3(.085 + (book % 2) * .015, .23 + (book % 3) * .035, .32), binding, root)
	for top in range(2):
		_make_trophy(root, Vector3(-.36 + top * .7, 2.46, -.05), .45)


func _make_trophy_case(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "SchoolTrophyCase"
	root.position = at
	world.add_child(root)
	for y in [.18, 1.05, 1.88]:
		_box("TrophyShelf", Vector3(0, y, 0), Vector3(1.35, .1, .56), shelf_wood, root)
	for x in [-.63, .63]:
		_box("TrophyCaseSide", Vector3(x, 1.12, 0), Vector3(.08, 2.15, .56), dark_wood, root)
	for x in [-.37, .32]:
		_make_trophy(root, Vector3(x, 1.1, 0), .55)
	_make_trophy(root, Vector3(0, 1.93, 0), .48)
	_light("TrophyGlint", Vector3(4.0, 2.25, 1.1), Color("#caa875"), .18, 2.5)


func _make_trophy(parent: Node3D, at: Vector3, height: float) -> void:
	var root := Node3D.new()
	root.name = "SchoolChessTrophy"
	root.position = at
	parent.add_child(root)
	_box("BlackBase", Vector3(0, .035, 0), Vector3(.27, .07, .19), dark_wood, root)
	_cylinder("Stem", Vector3(0, .13, 0), .035, .048, .17, brass, root)
	_cylinder("Cup", Vector3(0, .23 + height * .2, 0), .08, .14, height * .40, brass, root)
	for x in [-.13, .13]:
		_box("CupHandle", Vector3(x, .23 + height * .2, 0), Vector3(.08, .14, .035), brass, root)


func _make_chair(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "WornSchoolChair"
	root.position = at
	root.rotation.y = yaw
	world.add_child(root)
	_box("Seat", Vector3(0, .55, 0), Vector3(.62, .09, .58), shelf_wood, root)
	_box("Back", Vector3(0, 1.05, -.29), Vector3(.62, .86, .09), shelf_wood, root)
	for x in [-.25, .25]:
		for z in [-.22, .22]:
			_box("ChairLeg", Vector3(x, .27, z), Vector3(.065, .53, .065), dark_wood, root)


func _make_chess_table(at: Vector3, featured: bool) -> void:
	var root := Node3D.new()
	root.name = "MemoryChessTable" if featured else "SideChessTable"
	root.position = at
	world.add_child(root)
	_box("TableTop", Vector3(0, .83, 0), Vector3(1.75, .11, 1.55), shelf_wood, root)
	for x in [-.72, .72]:
		for z in [-.61, .61]:
			_box("TableLeg", Vector3(x, .39, z), Vector3(.09, .78, .09), dark_wood, root)
	var board := Node3D.new()
	board.name = "PlayableWorldChessBoard"
	board.position = Vector3(0, .9, 0)
	root.add_child(board)
	_box("BoardRim", Vector3.ZERO, Vector3(1.23, .07, 1.23), dark_wood, board)
	var light_square := _material("M_Board_LightSquare", Color("#c5b493"), .72)
	var dark_square := _material("M_Board_DarkSquare", Color("#4e3b36"), .78)
	for rank in range(8):
		for file in range(8):
			_box("Square_%d_%d" % [file, rank], Vector3(-.525 + file * .15, .042, -.525 + rank * .15), Vector3(.149, .012, .149), light_square if (file + rank) % 2 == 0 else dark_square, board)
	for side in range(2):
		var rank := 0 if side == 0 else 7
		var pawn_rank := 1 if side == 0 else 6
		var piece_mat := black_piece if side == 0 else ivory
		for file in range(8):
			_make_piece(board, file, pawn_rank, "Pawn", piece_mat)
			_make_piece(board, file, rank, ["Rook", "Knight", "Bishop", "Queen", "King", "Bishop", "Knight", "Rook"][file], piece_mat)
	if featured:
		for i in range(3):
			var candle := Node3D.new()
			candle.name = "MemoryCandle_%d" % i
			candle.position = Vector3(-.69 + i * .13, .89, -.68)
			root.add_child(candle)
			_cylinder("Wax", Vector3(0, .09 + (i % 2) * .03, 0), .025, .03, .17 + (i % 2) * .06, ivory, candle)
			_cylinder("Flame", Vector3(0, .20 + (i % 2) * .06, 0), .012, .024, .07, flame, candle)
			candles.append(candle)
		_light("CandlePool", at + Vector3(-.5, 1.16, -.5), Color("#ffb36b"), .85, 2.55, true)
	else:
		_box("StackedOldScorebook", Vector3(.53, .94, .62), Vector3(.22, .05, .29), paper, root)


func _make_piece(board: Node3D, file: int, rank: int, kind: String, mat: Material) -> void:
	var root := Node3D.new()
	root.name = "%s_%s_%d_%d" % ["Dark" if mat == black_piece else "Ivory", kind, file, rank]
	root.position = Vector3(-.525 + file * .15, .058, -.525 + rank * .15)
	board.add_child(root)
	var height := .075 if kind == "Pawn" else (.16 if kind == "King" or kind == "Queen" else .125)
	_cylinder("Foot", Vector3(0, .011, 0), .049, .054, .022, mat, root)
	_cylinder("Body", Vector3(0, .022 + height * .5, 0), .019, .038, height, mat, root)
	if kind == "Rook":
		_box("CastleCrown", Vector3(0, height + .035, 0), Vector3(.065, .035, .065), mat, root)
	elif kind == "Knight":
		var head := _box("HorseHead", Vector3(.012, height + .022, 0), Vector3(.05, .056, .033), mat, root)
		head.rotation.z = -.42
	elif kind == "Bishop":
		_cylinder("Mitre", Vector3(0, height + .045, 0), 0.0, .034, .058, mat, root)
	elif kind == "Queen":
		_cylinder("QueenCrown", Vector3(0, height + .036, 0), .045, .025, .04, mat, root)
	elif kind == "King":
		_box("CrossVertical", Vector3(0, height + .058, 0), Vector3(.013, .07, .015), mat, root)
		_box("CrossHorizontal", Vector3(0, height + .065, 0), Vector3(.05, .014, .015), mat, root)
	else:
		_cylinder("PawnHead", Vector3(0, height + .035, 0), .026, .026, .04, mat, root)


func _make_characters() -> void:
	hoang = HOANG.instantiate() as Node3D
	hoang.name = "HoangAtChessClubEntrance"
	hoang.position = Vector3(-2.38, 0, 2.28)
	hoang.rotation.y = PI
	world.add_child(hoang)
	_play_character_animation(hoang, "Idle")
	an = AN.instantiate() as Node3D
	an.name = "AnAtChessTable"
	an.position = Vector3(1.45, 0, -2.43)
	an.rotation.y = .15
	world.add_child(an)
	_play_character_animation(an, "Sit")
	_light("AnPalePresence", Vector3(1.5, 1.65, -2.2), Color("#bbc6d5"), .38, 2.4)


func _play_character_animation(character: Node3D, name: String) -> void:
	var player := _find_animation_player(character)
	if player == null:
		return
	for animation_name in player.get_animation_list():
		if String(animation_name).get_file() == name or String(animation_name).ends_with("/" + name):
			player.play(animation_name)
			return


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null


func set_returned_count(count: int) -> void:
	returned_count = clampi(count, 0, 6)
	if memory_light != null:
		memory_light.light_energy = .17 + float(returned_count) * .22
	for i in range(candles.size()):
		candles[i].visible = returned_count >= i * 2 + 1
