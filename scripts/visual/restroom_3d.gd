extends SubViewportContainer

## Physical restroom for the timed-hide and mirror beats.
## The ghost is rendered by a second 3D viewport onto the mirror surface; it
## never exists in the walkable room, so turning around shows an empty room.
const HOANG: PackedScene = preload("res://assets/characters/hoang/hoang.glb")
const CONTROLLER: Script = preload("res://scripts/visual/hoang_controller_3d.gd")
const BULLY_01: PackedScene = preload("res://assets/characters/npcs/bully_01.glb")
const BULLY_02: PackedScene = preload("res://assets/characters/npcs/bully_02.glb")
const BULLY_03: PackedScene = preload("res://assets/characters/npcs/bully_03.glb")
const REFLECTION_BEAT := 6
const TOILET_BEAT := 3
const DEATH_BEAT := 4

var viewport: SubViewport
var world: Node3D
var actor: HoangController3D
var mirror_viewport: SubViewport
var ghost: Node3D
var mirror_actor: Node3D
var current_beat := -1
var stall_glow: OmniLight3D
var threat_figures: Array[Node3D] = []
var stall_doors: Array[StaticBody3D] = []
var stall_door_open := false

var tile: StandardMaterial3D
var tile_dark: StandardMaterial3D
var wall: StandardMaterial3D
var metal: StandardMaterial3D
var porcelain: StandardMaterial3D
var glass: StandardMaterial3D
var grout: StandardMaterial3D
var chipped_porcelain: StandardMaterial3D
var water: StandardMaterial3D
var rust: StandardMaterial3D


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "RestroomViewport"
	viewport.size = Vector2i(960,540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	world = Node3D.new()
	world.name = "SchoolRestroom"
	viewport.add_child(world)
	_make_materials()
	_make_environment()
	_make_room()
	_make_mirror_effect()
	actor = CONTROLLER.new() as HoangController3D
	world.add_child(actor)
	actor.teleport_to(Vector3(-.8,0,2.0))
	_make_threat_figures()


func _make_threat_figures() -> void:
	# The three bullies are a visual threat only. Timed hiding, hit detection,
	# and checkpoints remain owned by the existing first-slice controller.
	var models: Array[PackedScene] = [BULLY_01, BULLY_02, BULLY_03]
	var locations := [
		Vector3(-.55, 0, -1.25),
		Vector3(.85, 0, -1.85),
		Vector3(2.20, 0, -.80),
	]
	for i in models.size():
		var figure := models[i].instantiate() as Node3D
		figure.name = "Bully_%02d_Threat" % (i + 1)
		figure.position = locations[i]
		figure.rotation.y = -.10 + i * .13
		figure.visible = false
		world.add_child(figure)
		threat_figures.append(figure)
		var player := _find_animation_player(figure)
		if player != null:
			for candidate in player.get_animation_list():
				if candidate == "Idle" or candidate.ends_with("/Idle"):
					player.play(candidate)
					break


func _mat(name: String, color: Color, roughness := .86) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = name
	mat.albedo_color = color
	mat.roughness = roughness
	return mat


func _make_materials() -> void:
	tile = _mat("M_Restroom_Tile", Color("#a5a7a0"), .52)
	tile.albedo_texture = load("res://assets/materials/school/floor_ceramic.png") as Texture2D
	tile_dark = _mat("M_Restroom_DampTile", Color("#6e7773"), .38)
	tile_dark.albedo_texture = load("res://assets/materials/school/damp_base.png") as Texture2D
	wall = _mat("M_Restroom_OldWall", Color("#bac0b6"))
	wall.albedo_texture = load("res://assets/materials/school/old_plaster.png") as Texture2D
	wall.uv1_scale = Vector3(3,3,1)
	metal = _mat("M_Restroom_StallMetal", Color("#b9c2c3"), .7)
	metal.albedo_texture = load("res://assets/materials/school/painted_metal.png") as Texture2D
	porcelain = _mat("M_Restroom_Porcelain", Color("#c6c8bf"), .28)
	glass = _mat("M_Restroom_TarnishedMirrorFrame", Color("#272a2b"), .25)
	grout = _mat("M_Restroom_GroutAndDrain", Color("#202b2c"), .85)
	chipped_porcelain = _mat("M_Restroom_PorcelainEdge", Color("#a5b0a9"), .42)
	rust = _mat("M_Restroom_OxidizedSteel", Color("#604b3e"), .84)
	water = _mat("M_Restroom_ShallowWater", Color("#68818a", .34), .19)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED


func _box(name: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	world.add_child(node)
	return node


func _collision(name: String, at: Vector3, size: Vector3, mat: Material, show_box := true) -> StaticBody3D:
	if show_box:
		_box(name, at, size, mat)
	var body := StaticBody3D.new()
	body.name = name + "_Collision"
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	return body


func _mesh(name: String, at: Vector3, shape: PrimitiveMesh, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = name
	item.mesh = shape
	item.material_override = mat
	item.position = at
	item.scale = scale
	world.add_child(item)
	return item


func _cylinder(name: String, at: Vector3, top: float, bottom: float, height: float, mat: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = top
	shape.bottom_radius = bottom
	shape.height = height
	shape.radial_segments = 12
	shape.rings = 1
	return _mesh(name, at, shape, mat, scale)


func _sphere(name: String, at: Vector3, mat: Material, scale: Vector3) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radial_segments = 12
	shape.rings = 6
	return _mesh(name, at, shape, mat, scale)


func _door_trim(door: MeshInstance3D, name: String, offset: Vector3, size: Vector3, mat: Material) -> void:
	# A child of the moving door mesh follows the existing hide-door translation.
	var trim := MeshInstance3D.new()
	trim.name = name
	var shape := BoxMesh.new()
	shape.size = size
	trim.mesh = shape
	trim.material_override = mat
	trim.position = offset
	door.add_child(trim)


func _light(name: String, at: Vector3, color: Color, power: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = name
	light.position = at
	light.light_color = color
	light.light_energy = power
	light.omni_range = radius
	world.add_child(light)
	return light


func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#080e13")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#758996")
	env.ambient_light_energy = .32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("#536976")
	env.fog_density = .008
	var node := WorldEnvironment.new()
	node.environment = env
	world.add_child(node)


func _make_room() -> void:
	_collision("WetTileFloor", Vector3(0,-.13,.5), Vector3(7.4,.26,10.2), tile_dark)
	_collision("LeftWall", Vector3(-3.72,1.6,.5), Vector3(.18,3.2,10.2), wall)
	_collision("RightWall", Vector3(3.72,1.6,.5), Vector3(.18,3.2,10.2), wall)
	_collision("MirrorWall", Vector3(0,1.6,-4.58), Vector3(7.4,3.2,.18), wall)
	_collision("EntranceWall", Vector3(0,1.6,5.58), Vector3(7.4,3.2,.18), wall)
	_box("Ceiling", Vector3(0,3.25,.5), Vector3(7.4,.16,10.2), tile_dark)
	for x in range(-3,4):
		for z in range(-4,6):
			_box("FloorTile_%d_%d" % [x,z], Vector3(float(x),.016,float(z)+.5),
				Vector3(.97,.025,.97), tile if (x+z)%2 == 0 else tile_dark)
	for z in [2.2,-.5,-3.2]:
		_box("FluorescentHousing", Vector3(0,3.12,z), Vector3(1.35,.08,.15), metal)
		var lamp_mat := _mat("M_Restroom_Lamp", Color("#e0e9e7"),.35)
		lamp_mat.emission_enabled = true
		lamp_mat.emission = Color("#a4c7d6")
		_box("FluorescentTube", Vector3(0,3.07,z), Vector3(1.2,.03,.07), lamp_mat)
		_light("ColdFluorescent", Vector3(0,2.78,z), Color("#9ec1d1"), .65, 4.5)
	_light("DangerRedThroughWindow", Vector3(-3,2.1,-2.8), Color("#a83c46"), .85, 2.8)
	_light("MirrorCoolFill", Vector3(1.65,2.18,-3.35), Color("#a6c4cb"), .65, 3.2)
	_make_floor_wear()
	# Stalls and the hide zone stay on the left as in the supplied reference.
	for i in range(3):
		var z := 2.15 - i*2.0
		_collision("StallPartition_%d" % i, Vector3(-2.15,1.16,z-1.0), Vector3(2.45,2.25,.085), metal)
		_box("PartitionCap_%d" % i, Vector3(-2.15,2.29,z-1.0), Vector3(2.48,.045,.12), grout)
		_box("PartitionFrontPost_%d" % i, Vector3(-.93,1.18,z-1.0), Vector3(.10,2.3,.12), grout)
		var door := _collision("StallDoor_%d" % i, Vector3(-1.04,1.08,z), Vector3(.09,2.10,1.55), metal)
		stall_doors.append(door)
		var door_mesh := world.get_node("StallDoor_%d" % i) as MeshInstance3D
		_door_trim(door_mesh, "TopRail", Vector3(-.005,1.02,0), Vector3(.12,.045,1.57), grout)
		_door_trim(door_mesh, "BottomRail", Vector3(-.005,-1.02,0), Vector3(.12,.05,1.57), grout)
		for side in [-1,1]:
			_door_trim(door_mesh, "SideRail_%d" % side, Vector3(-.006,0,float(side)*.755), Vector3(.12,2.04,.045), grout)
			_door_trim(door_mesh, "Hinge_%d" % side, Vector3(.065,float(side)*.58,.76), Vector3(.08,.18,.08), rust)
		_door_trim(door_mesh, "LatchPlate", Vector3(.063,.07,-.49), Vector3(.025,.16,.18), grout)
		# Keep this node name: existing door movement uses it.
		_box("StallHandle_%d" % i, Vector3(-.97,1.1,z-.48), Vector3(.055,.055,.10), chipped_porcelain)
		_make_toilet(i, z)
	stall_glow = _light("FinalStallGuide", Vector3(-2.35,1.65,1.6), Color("#d1c9a3"), .45, 2.1)
	# Twin basins and a framed mirror, all real geometry.
	for x in [.85,2.35]:
		_collision("SinkBasin", Vector3(x,.98,-3.97), Vector3(1.05,.21,.57), porcelain, false)
		_make_sink(x)
	_box("MirrorFrame", Vector3(1.61,2.04,-4.44), Vector3(3.04,1.72,.08), glass)
	_box("MirrorTarnishTop", Vector3(1.61,2.85,-4.39), Vector3(3.04,.07,.09), metal)
	for x in [.17,3.05]:
		_box("MirrorTarnishSide", Vector3(x,2.04,-4.39), Vector3(.06,1.72,.09), metal)
	_box("MirrorBottomEdge", Vector3(1.61,1.24,-4.38), Vector3(3.04,.045,.09), rust)


func _make_floor_wear() -> void:
	# Thin low-poly puddles catch the existing lamp pools; no screen-space decals.
	for i in range(7):
		var x: float = [-1.0,.25,1.12,2.68,-2.85,.48,2.0][i]
		var z: float = [3.22,2.03,.83,-.16,-1.85,-2.6,-3.32][i]
		_cylinder("WetPuddle_%d" % i, Vector3(x,.039,z), .5,.5,.008,
			water, Vector3([.80,.72,.55,.73,.61,.43,.57][i],1,[.38,.45,.32,.48,.42,.30,.36][i]))
	for i in range(3):
		_cylinder("FloorDrain_%d" % i, Vector3(-.35,.043,2.6-i*2.0), .12,.12,.008,grout)
		_box("DrainSlot_%d" % i, Vector3(-.35,.048,2.6-i*2.0), Vector3(.16,.007,.018),metal)


func _make_toilet(index: int, z: float) -> void:
	var x := -2.6
	var center_z := z-.52
	# Twelve-sided bowl, dark opening, separate seat, tapered pedestal and cistern.
	_cylinder("ToiletFoot_%d" % index, Vector3(x,.16,center_z), .22,.27,.28,chipped_porcelain,Vector3(1,1,1.2))
	_cylinder("ToiletBowl_%d" % index, Vector3(x,.43,center_z), .31,.22,.32,porcelain,Vector3(1,1,1.22))
	_cylinder("ToiletSeat_%d" % index, Vector3(x,.60,center_z), .33,.33,.045,chipped_porcelain,Vector3(1,1,1.25))
	_cylinder("ToiletOpening_%d" % index, Vector3(x,.626,center_z), .24,.24,.009,grout,Vector3(1,1,1.28))
	_cylinder("ToiletWater_%d" % index, Vector3(x,.632,center_z), .16,.16,.009,water,Vector3(1,1,1.20))
	_box("ToiletCistern_%d" % index, Vector3(x,.83,center_z-.34), Vector3(.58,.48,.24),porcelain)
	_box("ToiletCisternLid_%d" % index, Vector3(x,1.09,center_z-.34), Vector3(.63,.045,.28),chipped_porcelain)
	_cylinder("FlushButton_%d" % index, Vector3(x+.19,1.12,center_z-.34), .035,.035,.025,metal)
	_box("ToiletPipe_%d" % index, Vector3(x,.21,center_z-.51),Vector3(.10,.12,.37),grout)


func _make_sink(x: float) -> void:
	_cylinder("SinkPedestal",Vector3(x,.51,-4.03),.13,.18,.86,porcelain,Vector3(1,1,.72))
	_cylinder("SinkUnderside",Vector3(x,.93,-3.97),.43,.27,.22,chipped_porcelain,Vector3(1,1,.62))
	_cylinder("SinkRim",Vector3(x,1.045,-3.97),.51,.47,.075,porcelain,Vector3(1,1,.59))
	_cylinder("SinkWell",Vector3(x,1.09,-3.97),.37,.37,.012,chipped_porcelain,Vector3(1,1,.48))
	_cylinder("SinkDrain",Vector3(x,1.099,-3.96),.045,.045,.013,grout)
	_cylinder("FaucetStem",Vector3(x,1.18,-4.24),.035,.045,.23,metal)
	_box("FaucetSpout",Vector3(x,1.29,-4.13),Vector3(.065,.045,.25),metal)
	_cylinder("FaucetNozzle",Vector3(x,1.26,-4.02),.026,.026,.065,grout)
	for side in [-1,1]:
		_cylinder("FaucetKnob",Vector3(x+float(side)*.16,1.14,-4.25),.055,.055,.035,metal)


func _make_mirror_effect() -> void:
	mirror_viewport = SubViewport.new()
	mirror_viewport.name = "MirrorOnly3DRender"
	mirror_viewport.size = Vector2i(480,270)
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mirror_viewport.own_world_3d = true
	world.add_child(mirror_viewport)
	var mirror_world := Node3D.new()
	mirror_viewport.add_child(mirror_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1a252b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#a8b9bb")
	env.ambient_light_energy = .68
	var env_node := WorldEnvironment.new()
	env_node.environment = env
	mirror_world.add_child(env_node)
	var reflected_wall := MeshInstance3D.new()
	reflected_wall.name = "ReflectedRestroomWall"
	var backdrop := PlaneMesh.new()
	backdrop.size = Vector2(4.0,2.7)
	reflected_wall.mesh = backdrop
	var backdrop_mat := _mat("M_ReflectedStainedWall",Color("#a7b7b3"))
	backdrop_mat.albedo_texture = wall.albedo_texture
	backdrop_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	reflected_wall.material_override = backdrop_mat
	reflected_wall.position = Vector3(0,1.35,-1.22)
	reflected_wall.rotation_degrees.x = 90
	mirror_world.add_child(reflected_wall)
	mirror_actor = HOANG.instantiate() as Node3D
	mirror_actor.name = "HoangReflection"
	mirror_actor.position = Vector3(-.43,-.1,.03)
	mirror_world.add_child(mirror_actor)
	if ResourceLoader.exists("res://assets/characters/an/an.glb"):
		ghost = load("res://assets/characters/an/an.glb").instantiate() as Node3D
	else:
		ghost = _make_fallback_ghost()
	ghost.name = "AnOnlyInMirror"
	ghost.position = Vector3(.49,-.04,-.38)
	ghost.scale = Vector3.ONE * 1.12
	ghost.visible = false
	mirror_world.add_child(ghost)
	var camera_m := Camera3D.new()
	camera_m.name = "MirrorCamera"
	camera_m.current = true
	camera_m.fov = 46.0
	camera_m.position = Vector3(0,1.49,1.43)
	mirror_world.add_child(camera_m)
	camera_m.look_at(Vector3(0,1.35,-.02),Vector3.UP)
	var light := OmniLight3D.new()
	light.position = Vector3(0,2.4,1.0)
	light.light_color = Color("#c6d6d3")
	light.light_energy = 1.05
	light.omni_range = 4.0
	mirror_world.add_child(light)
	var ghost_light := OmniLight3D.new()
	ghost_light.position = Vector3(.62,1.63,.02)
	ghost_light.light_color = Color("#b2cbd0")
	ghost_light.light_energy = 1.05
	ghost_light.omni_range = 2.4
	mirror_world.add_child(ghost_light)
	var red_edge := OmniLight3D.new()
	red_edge.name = "AnDistantRedRim"
	red_edge.position = Vector3(.85,1.55,-.92)
	red_edge.light_color = Color("#ac343e")
	red_edge.light_energy = .65
	red_edge.omni_range = 1.8
	mirror_world.add_child(red_edge)
	var mirror_mat := StandardMaterial3D.new()
	mirror_mat.resource_name = "M_Mirror3DViewport"
	mirror_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mirror_mat.albedo_texture = mirror_viewport.get_texture()
	mirror_mat.albedo_color = Color(.82,.88,.88,1)
	var surface := MeshInstance3D.new()
	surface.name = "MirrorSurfaceShowing3D"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.88,1.57)
	surface.mesh = quad
	surface.material_override = mirror_mat
	surface.position = Vector3(1.61,2.04,-4.38)
	world.add_child(surface)


func _make_fallback_ghost() -> Node3D:
	var root := Node3D.new()
	var pale := _mat("M_An_PaleUniform", Color("#8e9a99"))
	var dark := _mat("M_An_Hair", Color("#11171c"))
	for item in [
		[Vector3(0,1.1,0),Vector3(.36,.58,.18),pale],
		[Vector3(0,1.52,0),Vector3(.25,.27,.19),pale],
		[Vector3(0,1.66,0),Vector3(.31,.36,.22),dark],
	]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = item[1]
		m.mesh = b
		m.material_override = item[2]
		m.position = item[0]
		root.add_child(m)
	return root


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result != null:
			return result
	return null


func set_state_from_prototype(pos: Vector2, beat: int, hidden: bool) -> void:
	current_beat = beat
	var lateral := (pos.x-480.0)/145.0
	var depth := (pos.y-300.0)/39.0
	var mapped := Vector3(clampf(lateral,-2.5,2.5),0,
		clampf(depth,-3.4,4.0))
	if actor != null:
		actor.teleport_to(mapped)
		actor.hidden = hidden and beat == TOILET_BEAT
	update_story_state(beat, hidden)


func update_story_state(beat: int, hidden: bool) -> void:
	current_beat = beat
	if actor != null:
		actor.hidden = hidden and beat == TOILET_BEAT
	if ghost != null:
		ghost.visible = beat == REFLECTION_BEAT
	for figure in threat_figures:
		figure.visible = beat in [TOILET_BEAT, DEATH_BEAT]
	if stall_glow != null:
		stall_glow.visible = beat == 3


func get_player_position() -> Vector3:
	return actor.position if actor != null else Vector3.ZERO


func get_projected_position() -> Vector2:
	var pos := get_player_position()
	return Vector2(pos.x * 145.0 + 480.0, pos.z * 39.0 + 300.0)


func near_stall_door() -> bool:
	return actor != null and actor.position.distance_to(Vector3(-.75,0,2.15)) < 1.35


func inside_hide_stall() -> bool:
	return actor != null and actor.position.x < -1.42 and actor.position.z > 1.20 and actor.position.z < 3.1


func open_hide_stall() -> void:
	if stall_door_open or stall_doors.is_empty():
		return
	stall_door_open = true
	var first_door := stall_doors[0]
	(first_door.get_child(0) as CollisionShape3D).set_deferred("disabled", true)
	var mesh := world.get_node_or_null("StallDoor_0") as MeshInstance3D
	if mesh != null:
		mesh.position.z += 1.45
	var handle := world.get_node_or_null("StallHandle_0") as MeshInstance3D
	if handle != null:
		handle.position.z += 1.45


func reset_hide_stall() -> void:
	if not stall_door_open or stall_doors.is_empty():
		return
	stall_door_open = false
	(stall_doors[0].get_child(0) as CollisionShape3D).set_deferred("disabled", false)
	var mesh := world.get_node_or_null("StallDoor_0") as MeshInstance3D
	if mesh != null:
		mesh.position.z -= 1.45
	var handle := world.get_node_or_null("StallHandle_0") as MeshInstance3D
	if handle != null:
		handle.position.z -= 1.45


func near_mirror() -> bool:
	return actor != null and actor.position.distance_to(Vector3(1.6,0,-3.75)) < 1.8


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
