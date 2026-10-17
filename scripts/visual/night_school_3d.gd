extends SubViewportContainer

## Playable dusk-to-night school route for Chapter 01. The school is built from
## Godot primitives so this scene has no hidden project or external-scene deps.
const CONTROLLER: Script = preload("res://scripts/visual/hoang_controller_3d.gd")
const GANG_SCENES := [
	"res://assets/characters/npcs/bully_01.glb",
	"res://assets/characters/npcs/bully_02.glb",
	"res://assets/characters/npcs/bully_03.glb",
]
const FRIENDS := [
	["Bao", "res://assets/characters/npcs/bao.glb", Vector3(-2.2, 0, 25.0)],
	["Huan", "res://assets/characters/npcs/huan.glb", Vector3(2.0, 0, 25.0)],
	["Lan", "res://assets/characters/npcs/lan.glb", Vector3(0.0, 0, 22.8)],
]

var viewport: SubViewport
var world: Node3D
var actor: HoangController3D
var friends: Array[Node3D] = []
var bullies: Array[Node3D] = []
var apparition: Node3D
var hallway_apparition: Node3D
var mirror_viewport: SubViewport
var mirror_world: Node3D
var mirror_player: Node3D
var mirror_camera: Camera3D
var mirror_animation: AnimationPlayer
var stick_audio: AudioStreamPlayer3D
var impact_audio: AudioStreamPlayer3D
var breach_audio: AudioStreamPlayer3D
var bell_audio: AudioStreamPlayer3D
var story_zone := "yard"
var red_realm := false
var stall_open := false
var stall_door_open: bool:
	get:
		return stall_open
var player_hidden := false
var hide_camera_tween: Tween
var mirror_text: Label3D
var entry_door: Node3D
var restroom_door: Node3D
var stall_door: Node3D
var entry_door_blocker: CollisionShape3D
var restroom_door_blocker: CollisionShape3D
var stall_door_blocker: CollisionShape3D
var restroom_entry_open := false
var mirror_condensation: MeshInstance3D
var night_env: Environment
var hide_campus_blockout_visuals := false
var show_route_visuals := false
var scene56_camera_snapshot: Dictionary = {}
var scene56_apparition_tween: Tween
var keepsake_memory_snapshot: Dictionary = {}
var keepsake_memory_root: Node3D
var keepsake_memory_light: OmniLight3D

## The imported campus labels its main gate at source Z=77.7. With the .68
## import scale and +1 Z placement below, the gate is at about Z=53.8.
## Start just inside it, with the friends gathered farther into the courtyard.
const YARD_START := Vector3(0, 0, 29.0)
const STAIR_BASE := Vector3(0, 0, -19.5)
const RESTROOM_DOOR := Vector3(14.0, 6.4, 1.0)
const STALL_POINT := Vector3(15.55, 6.52, -1.50)
const SCHOOL_ENVIRONMENT := preload("res://scenes/visual/school_environment_3d.tscn")
const NIGHT_STARFIELD := preload("res://assets/sky/night_starfield_2k.png")

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "NightSchoolViewport"
	viewport.size = Vector2i(960, 540)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	world = Node3D.new()
	world.name = "NightSchool"
	viewport.add_child(world)
	_make_environment()
	_add_test_neh_school_campus()
	_add_school_environment()
	hide_campus_blockout_visuals = true
	show_route_visuals = false
	_make_campus()
	_make_stairs_and_upper_hall()
	var restroom_children_before := world.get_child_count()
	show_route_visuals = true
	_make_restroom()
	_attach_restroom_overlay(restroom_children_before)
	show_route_visuals = false
	for item in FRIENDS:
		var packed := load(item[1]) as PackedScene
		if packed == null:
			continue
		var friend := packed.instantiate() as Node3D
		friend.name = str(item[0])
		friend.position = item[2]
		friend.rotation.y = PI
		friend.scale = Vector3.ONE * .8
		world.add_child(friend)
		friends.append(friend)
	actor = CONTROLLER.new() as HoangController3D
	world.add_child(actor)
	actor.teleport_to(YARD_START)
	actor.controls_enabled = true
	actor.camera_yaw = 0.0
	actor.call("_apply_camera_rotation")
	_setup_mirror_view()
	_setup_spatial_audio()
	var outside := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if outside != null:
		night_env = outside.environment

func _add_test_neh_school_campus() -> void:
	var packed := load("res://scenes/visual/test_neh_school_campus.tscn") as PackedScene
	if packed == null:
		push_warning("The imported Test-NEH-School campus scene could not be loaded.")
		return
	var campus := packed.instantiate() as Node3D
	if campus == null:
		push_warning("The imported Test-NEH-School campus root is not Node3D.")
		return
	campus.name = "TestNEHSchoolCampus"
	campus.scale = Vector3.ONE * 0.68
	campus.position = Vector3(0.0, -0.02, 1.0)
	world.add_child(campus)
	# Keep the pre-existing imported artifact in the live tree for rollback and
	# comparison, but deactivate its visuals/colliders while the mapped campus
	# scene is active. It is never deleted or rewritten.
	campus.visible = false
	# The source campus has a decorative wall panel directly across the custom
	# restroom entrance. Remove only that rendered panel instance; its imported
	# PhysicsChunk remains enabled so this visual fix cannot create a collision
	# hole elsewhere in the school.
	_set_imported_collision_layers(campus)

func _add_school_environment() -> void:
	var campus := SCHOOL_ENVIRONMENT.instantiate() as Node3D
	if campus == null:
		push_error("The mapped school environment could not be instantiated.")
		return
	campus.name = "MappedSchoolEnvironment"
	campus.set("standalone_player_enabled", false)
	campus.set("standalone_lighting_enabled", false)
	world.add_child(campus)

func _attach_restroom_overlay(first_child_index: int) -> void:
	var overlay := Node3D.new()
	overlay.name = "StoryRestroomGameplayOverlay"
	world.add_child(overlay)
	while world.get_child_count() > first_child_index + 1:
		world.get_child(first_child_index).reparent(overlay, true)
	overlay.transform = Transform3D(Basis(Vector3.UP, -PI * .5), Vector3(-13.0, 1.72, -4.0))
	for child in overlay.get_children():
		if child.name in ["ThirdFloorStairRestroomDirectionPlaque", "ThirdFloorStairRestroomDirection"]:
			child.visible = false

func _hide_campus_visual_instance(campus: Node3D, batch_name: String, index: int) -> void:
	var batch := campus.get_node_or_null("RuntimeGeometry/" + batch_name) as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		push_warning("Could not find restroom sightline visual %s." % batch_name)
		return
	var source := batch.multimesh
	var copy := MultiMesh.new()
	copy.transform_format = source.transform_format
	copy.mesh = source.mesh
	copy.use_colors = source.use_colors
	copy.use_custom_data = source.use_custom_data
	copy.instance_count = source.instance_count
	copy.custom_aabb = source.custom_aabb
	for placement_index in range(source.instance_count):
		copy.set_instance_transform(placement_index, source.get_instance_transform(placement_index))
		if source.use_colors:
			copy.set_instance_color(placement_index, source.get_instance_color(placement_index))
		if source.use_custom_data:
			copy.set_instance_custom_data(placement_index, source.get_instance_custom_data(placement_index))
	var placements: Array = source.get("placements")
	if index < 0 or index >= copy.instance_count or index >= placements.size():
		push_warning("Restroom sightline visual %s has no placement %d." % [batch_name, index])
		return
	var transform: Transform3D = placements[index]
	transform.basis = Basis.IDENTITY.scaled(Vector3.ONE * 0.00001)
	copy.set_instance_transform(index, transform)
	batch.multimesh = copy

func _set_imported_collision_layers(node: Node) -> void:
	if node is CollisionObject3D:
		var body := node as CollisionObject3D
		body.collision_layer = 0
		body.collision_mask = 0
	for child in node.get_children():
		_set_imported_collision_layers(child)

func _process(_delta: float) -> void:
	if story_zone == "stairs" and actor.global_position.y >= 6.0:
		story_zone = "upper_hall"
	_sync_mirror_hoang()

func _sync_mirror_hoang() -> void:
	if actor == null or actor.model == null or mirror_player == null:
		return
	# The mirror plane reverses left/right, so reflect the player's yaw delta
	# around the initial front-facing pose instead of leaving the duplicate idle.
	mirror_player.rotation.y = PI * 2.0 - actor.model.rotation.y
	if actor.animation_player == null or mirror_animation == null:
		return
	var source_animation := actor.animation_player
	var clip := source_animation.current_animation
	if clip.is_empty():
		return
	if mirror_animation.current_animation != clip:
		mirror_animation.play(clip, 0.0, source_animation.speed_scale)
	mirror_animation.speed_scale = source_animation.speed_scale
	mirror_animation.seek(source_animation.current_animation_position, true)
	if source_animation.is_playing():
		if not mirror_animation.is_playing():
			mirror_animation.play()
	elif mirror_animation.is_playing():
		mirror_animation.pause()

func _map_old_story_point(point: Vector3) -> Vector3:
	return Transform3D(Basis(Vector3.UP, -PI * .5), Vector3(-13.0, 1.72, -4.0)) * point

func _material(name: String, color: Color, roughness := .82) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = name
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _textured_material(name: String, color: Color, texture_path: String, roughness := .82, tiles_per_metre := 1.0) -> StandardMaterial3D:
	var mat := _material(name, color, roughness)
	var texture := load(texture_path) as Texture2D
	if texture != null:
		mat.albedo_texture = texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * (2.0 if texture_path.ends_with("floor_ceramic.png") else tiles_per_metre)
	else:
		push_warning("Restroom material texture is missing: %s" % texture_path)
	return mat

func _make_environment() -> void:
	var env := Environment.new()
	# Keep a controlled low-poly night gradient; HDRI panoramas tested in this
	# courtyard produced a distracting bright moon or horizon band.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#060a16")
	sky_material.sky_horizon_color = Color("#111b2a")
	sky_material.ground_bottom_color = Color("#05070c")
	sky_material.ground_horizon_color = Color("#101721")
	sky_material.sky_curve = 0.28
	sky_material.ground_curve = 0.28
	sky_material.sky_energy_multiplier = 1.0
	sky_material.ground_energy_multiplier = 1.0
	sky_material.sky_cover = NIGHT_STARFIELD
	sky_material.sky_cover_modulate = Color(0.55, 0.65, 0.82)
	# The moon light still illuminates architecture, but no HDR disk is rendered.
	sky_material.sun_angle_max = 0.0
	var night_sky := Sky.new()
	night_sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = night_sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#758399")
	env.ambient_light_energy = .46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var camera_env := WorldEnvironment.new()
	camera_env.name = "WorldEnvironment"
	camera_env.environment = env
	world.add_child(camera_env)
	var moon := DirectionalLight3D.new()
	moon.name = "CourtyardMoonlight"
	moon.rotation_degrees = Vector3(-38, -32, 0)
	moon.light_color = Color("#8296ba")
	moon.light_energy = .62
	moon.shadow_enabled = true
	world.add_child(moon)

func _box(name: String, at: Vector3, size: Vector3, mat: Material, solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var item := MeshInstance3D.new()
	item.name = name
	item.mesh = mesh
	item.material_override = mat
	item.visible = show_route_visuals or not hide_campus_blockout_visuals
	item.position = at
	world.add_child(item)
	# The old courtyard/facade is a hidden, superseded blockout. Leaving its
	# collisions active would create invisible walls inside the campus and
	# across the restroom; the imported campus supplies the real exterior
	# collision while route geometry created below keeps its own solids.
	if solid and (show_route_visuals or not hide_campus_blockout_visuals):
		var body := StaticBody3D.new()
		body.name = name + "Collision"
		body.position = at
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		world.add_child(body)
	return item

func _door_blocker(blocker_name: String, at: Vector3, size: Vector3) -> CollisionShape3D:
	var body := StaticBody3D.new()
	body.name = blocker_name
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	return shape

func _make_campus() -> void:
	var concrete := _material("Night concrete", Color("#55534e"))
	var wall := _material("School plaster", Color("#aaa28e"))
	var brick := _material("Old brick", Color("#51484a"))
	var glass := _material("Night windows", Color("#26313d"), .22)
	# Legacy courtyard/facade blockout. Its visuals and collisions stay hidden;
	# the imported campus provides the actual yard ground and collision.
	_box("Courtyard", Vector3(0,-.16,25), Vector3(100,.3,120), concrete, true)
	# Leave a real ground-level doorway in the front wall so the player can enter.
	_box("School front facade left", Vector3(-8,3,-9), Vector3(12,6,.45), wall, true)
	_box("School front facade right", Vector3(8,3,-9), Vector3(12,6,.45), wall, true)
	_box("School entrance header", Vector3(0,4.5,-9), Vector3(4.2,3,.45), wall, true)
	_box("School left wing", Vector3(-13,3,-20), Vector3(.45,6,22), wall, true)
	_box("School right wing", Vector3(13,3,-20), Vector3(.45,6,22), wall, true)
	_box("School back wall", Vector3(0,3,-31), Vector3(26,6,.45), wall, true)
	_box("Main entrance sign", Vector3(0,5.3,-9.27), Vector3(5,.5,.1), brick)
	var sign := Label3D.new()
	sign.text = "TRƯỜNG TRUNG HỌC"
	sign.font_size = 34
	sign.pixel_size = .009
	sign.position = Vector3(0,5.3,-9.18)
	sign.modulate = Color("#e1d2b3")
	sign.visible = show_route_visuals or not hide_campus_blockout_visuals
	world.add_child(sign)
	# Recessed entry recess reads clearly from the yard and is an E interaction.
	entry_door = _box("MainEntranceDoor", Vector3(0,1.45,-8.72), Vector3(2.6,2.9,.18), brick)
	# This door belongs to the hidden legacy facade at z=-8.72, not the
	# mapped school's story entrance at z=-19.5. Keep its collider inactive
	# while the mapped campus is the playable environment.
	if not hide_campus_blockout_visuals:
		entry_door_blocker = _door_blocker("MainEntranceDoorBlocker", Vector3(0,1.45,-8.72), Vector3(2.6,2.9,.18))
	for x in [-8,-4,4,8]:
		_box("Facade window", Vector3(x,3.7,-9.27), Vector3(2.1,2.0,.08), glass)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x,4.8,-8.4)
		lamp.light_color = Color("#ffce86")
		lamp.light_energy = .65
		lamp.omni_range = 5.0
		lamp.visible = show_route_visuals or not hide_campus_blockout_visuals
		world.add_child(lamp)
	var fence := _material("Courtyard iron", Color("#252b32"), .55)
	for x in range(-20,21,2):
		_box("Courtyard fence", Vector3(x,1,25), Vector3(.08,2,.08), fence)
	_box("Courtyard fence rail", Vector3(0,1.75,25), Vector3(42,.08,.08), fence)
	_box("Courtyard fence rail", Vector3(0,.35,25), Vector3(42,.08,.08), fence)
	for tree_x in [-17,17]:
		_box("Courtyard tree trunk", Vector3(tree_x,2,11), Vector3(.55,4,.55), brick)
		var crown := _material("Night foliage", Color("#20332e"))
		var canopy := SphereMesh.new()
		canopy.radius = 2.3
		canopy.height = 4.6
		var foliage := MeshInstance3D.new()
		foliage.mesh = canopy
		foliage.material_override = crown
		foliage.visible = show_route_visuals or not hide_campus_blockout_visuals
		foliage.position = Vector3(tree_x,5,11)
		world.add_child(foliage)

func _make_stairs_and_upper_hall() -> void:
	var floor_mat := _material("Stairwell terrazzo", Color("#686963"))
	var railing := _material("Stairwell rail", Color("#3f494c"), .48)
	# Ground-floor hall through the main entrance to the open stairwell.
	_box("Ground school floor", Vector3(0,-.12,-20), Vector3(24,.24,22), floor_mat, true)
	# The restroom occupies the space beyond this hallway endpoint; a full-width
	# wall here used to bisect and hide the custom restroom interior.
	for floor_level in range(1,4):
		var y := float(floor_level) * 1.6
		var hall_center_z := -23.0 if floor_level == 3 else -25.0
		var hall_length_z := 8.0 if floor_level == 3 else 12.0
		# Leave a vertical atrium on the west side so the long stair does not
		# collide with overhead slabs while Hoang climbs between storeys.
		_box("Floor %d corridor" % floor_level, Vector3(3.0,y-.12,hall_center_z), Vector3(16,.24,hall_length_z), floor_mat, true)
		for side_x in [-12.0,12.0]:
			_box("Floor %d corridor wall" % floor_level, Vector3(side_x,y+1.3,hall_center_z), Vector3(.2,2.6,hall_length_z), wall_material(), true)
	# One open, broad concrete flight rises 4.8 m with visible treads at each
	# floor threshold; a matching hidden ramp lets the first-person controller
	# ascend smoothly without a snap/teleport.
	for step in range(30):
		var rise := float(step+1) * .16
		var at := Vector3(-7.0,rise-.08,-11.5-float(step)*.42)
		_box("Stair tread %02d" % (step+1), at, Vector3(2,.16,.50), floor_mat)
	# The mapped school supplies three aligned stair cores. Do not instantiate
	# the hidden legacy ramp (and its physics RID) in that configuration.
	if not hide_campus_blockout_visuals:
		var ramp := StaticBody3D.new()
		ramp.name = "WalkableThreeFloorStairRamp"
		ramp.position = Vector3(-7.0,2.4,-17.6)
		ramp.rotation.x = atan(4.8/12.6)
		var ramp_shape := CollisionShape3D.new()
		var ramp_box := BoxShape3D.new()
		ramp_box.size = Vector3(2,.2,12.8)
		ramp_shape.shape = ramp_box
		ramp.add_child(ramp_shape)
		world.add_child(ramp)
	_box("Stair rail west", Vector3(-8.1,2.9,-17.6), Vector3(.08,1.2,13), railing)
	_box("Stair rail east", Vector3(-5.9,2.9,-17.6), Vector3(.08,1.2,13), railing)
	_box("Third floor stair landing", Vector3(-7,4.68,-24.3), Vector3(2,.24,2), floor_mat, true)
	_box("Third floor connector", Vector3(-5.5,4.68,-24.3), Vector3(3,.24,2), floor_mat, true)
	_box("Third floor outside wall", Vector3(11.2,6.1,-23), Vector3(.2,3,8), wall_material(), true)
	for floor_level in range(1,4):
		var level_label := Label3D.new()
		level_label.text = "TẦNG %d" % floor_level
		level_label.font_size = 28
		level_label.pixel_size = .008
		level_label.position = Vector3(-8.8,float(floor_level)*1.6,-11.3)
		level_label.visible = show_route_visuals or not hide_campus_blockout_visuals
		world.add_child(level_label)
	_box("ThirdFloorNoticeBoard", Vector3(0.0,5.9,-19.15), Vector3(3.2,1.7,.13), _material("Notice board felt", Color("#24332d")))
	var board_label := Label3D.new()
	board_label.text = "THÔNG BÁO"
	board_label.font_size = 25
	board_label.pixel_size = .009
	board_label.position = Vector3(0.0,6.3,-19.05)
	board_label.modulate = Color("#d5cbb6")
	board_label.visible = show_route_visuals or not hide_campus_blockout_visuals
	world.add_child(board_label)

func wall_material() -> StandardMaterial3D:
	return _material("School aged plaster", Color("#918c80"))

func _make_restroom() -> void:
	var metal := _textured_material("Restroom painted metal", Color("#819092"), "res://assets/materials/school/painted_metal.png", .68, .9)
	var wayfinding_board := _material("Restroom wayfinding enamel", Color("#17363b"), .48)
	# The mapped campus owns the only WC shell, floor, partition walls, and
	# fixture layout. Keep this overlay strictly for story interactions and the
	# one mirror-event surface; a second shell here would overlap the approved map.
	var campus := world.find_child("MappedSchoolEnvironment", true, false)
	if campus != null:
		# Keep the mapped opening and its jambs, but render only the interactive
		# story leaf in this production scene.
		var mapped_entry_hinge := campus.find_child("WC NAM door hinge pivot", true, false) as Node3D
		if mapped_entry_hinge != null:
			mapped_entry_hinge.visible = false
		for mirror_name in [
			"WC NAM mirror 01", "WC NAM mirror top frame 01", "WC NAM mirror bottom frame 01",
			"WC NAM mirror 02", "WC NAM mirror top frame 02", "WC NAM mirror bottom frame 02",
		]:
			var mapped_mirror := campus.find_child(mirror_name, true, false) as Node3D
			if mapped_mirror != null:
				mapped_mirror.visible = false
		stall_door = campus.find_child("WC NAM stall door pivot 01", true, false) as Node3D
		if stall_door != null:
			stall_door_blocker = stall_door.find_child("Door leaf blocker", true, false) as CollisionShape3D
		if stall_door == null or stall_door_blocker == null:
			push_error("The mapped WC NAM first cubicle door or its collision leaf is missing.")
	# The mapped west-wall aperture is exactly 1.55 m. This jamb pivot and closed
	# blocker cover that same opening without widening it or adding duplicate walls.
	restroom_door = Node3D.new()
	restroom_door.name = "ThirdFloorRestroomDoorHinge"
	restroom_door.position = Vector3(4.225,4.80,-27.0)
	world.add_child(restroom_door)
	var door_slab := _box("ThirdFloorRestroomDoor", Vector3(.775,1.09,0), Vector3(1.55,2.18,.12), metal)
	world.remove_child(door_slab)
	restroom_door.add_child(door_slab)
	restroom_door_blocker = _door_blocker("RestroomDoorBlocker", Vector3(5,5.89,-27), Vector3(1.57,2.18,.22))
	# Plaque sits just outside the mapped wall, above the aperture and below the
	# top band. Its local +Z face points back toward the corridor approach.
	_box("RestroomDoorWayfindingPlaque", Vector3(5,6.72,-26.86), Vector3(2.25,.40,.10), wayfinding_board)
	var restroom_sign := Label3D.new()
	restroom_sign.name = "RestroomWayfindingSign"
	restroom_sign.text = "WC NAM"
	restroom_sign.font_size = 30
	restroom_sign.pixel_size = .0075
	restroom_sign.position = Vector3(5,6.72,-26.79)
	restroom_sign.rotation.y = 0.0 # Label3D front faces +Z; the approach is from +Z.
	restroom_sign.modulate = Color("#fff1bd")
	world.add_child(restroom_sign)
	# Put a readable sign directly in front of the stair landing, on the west side
	# of the corridor wall. This keeps the wall from occluding it as Hoang arrives.
	# Facing -Z, the player's screen-right is +X: the direction of the restroom.
	_box("ThirdFloorStairRestroomDirectionPlaque", Vector3(-6.4,6.62,-25.45), Vector3(4.4,.92,.12), wayfinding_board)
	var direction_sign := Label3D.new()
	direction_sign.name = "ThirdFloorStairRestroomDirection"
	direction_sign.text = "WC NAM  →"
	direction_sign.font_size = 27
	direction_sign.pixel_size = .006
	direction_sign.position = Vector3(-6.4,6.62,-25.37)
	direction_sign.rotation.y = 0.0 # Label3D front faces +Z, toward the landing.
	direction_sign.modulate = Color("#fff1bd")
	world.add_child(direction_sign)
	# Shared vanity wall is the mapped south wall at z≈3.9; this single broad
	# event mirror replaces the two small map mirrors without adding a shell.
	var mirror_frame := MeshInstance3D.new()
	mirror_frame.name = "Restroom mirror event frame"
	var frame_mesh := QuadMesh.new()
	frame_mesh.size = Vector2(2.94,1.56)
	mirror_frame.mesh = frame_mesh
	mirror_frame.material_override = metal
	# Center the event mirror at 1.56 m above the mapped floor, immediately
	# above the twin basin rims rather than floating high on the wall.
	mirror_frame.position = Vector3(7.84,6.24,-30.20)
	mirror_frame.rotation.y = -PI*.5
	mirror_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mirror_frame)
	var mirror_quad := QuadMesh.new()
	mirror_quad.size = Vector2(2.78,1.40)
	var mirror_glass := MeshInstance3D.new()
	mirror_glass.name = "Mirror glass"
	mirror_glass.mesh = mirror_quad
	mirror_glass.position = Vector3(7.82,6.24,-30.20)
	mirror_glass.rotation.y = -PI*.5
	mirror_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mirror_glass)
	# Condensation stays on the glass rim only. The previous full-size, no-depth
	# test alpha box blended pale grey over every reflected pixel and erased the
	# figures precisely when the writing event enabled it.
	var mist_shader := Shader.new()
	mist_shader.code = """
	shader_type spatial;
	render_mode unshaded, blend_mix, depth_draw_never;
	uniform vec4 mist_color : source_color = vec4(0.72, 0.79, 0.78, 1.0);
	uniform float mist_strength = 0.0;
	void fragment() {
		vec2 edge = min(UV, vec2(1.0) - UV);
		float side_fog = 1.0 - smoothstep(0.015, 0.13, edge.x);
		float top_fog = 1.0 - smoothstep(0.008, 0.055, edge.y);
		float bottom_fog = 1.0 - smoothstep(0.008, 0.055, edge.y);
		float irregularity = 0.72 + 0.28 * sin(UV.y * 31.0 + sin(UV.x * 17.0) * 1.7);
		float rim_mask = max(side_fog, max(top_fog, bottom_fog) * 0.32);
		ALBEDO = mist_color.rgb;
		ALPHA = mist_strength * rim_mask * irregularity;
	}
	"""
	var mist_material := ShaderMaterial.new()
	mist_material.resource_name = "Mirror edge condensation"
	mist_material.shader = mist_shader
	mist_material.set_shader_parameter("mist_color", Color("#b8c3bd"))
	mist_material.set_shader_parameter("mist_strength", 0.0)
	var mist_mesh := QuadMesh.new()
	mist_mesh.size = Vector2(2.70,1.32)
	mirror_condensation = MeshInstance3D.new()
	mirror_condensation.name = "MirrorCondensation"
	mirror_condensation.mesh = mist_mesh
	mirror_condensation.material_override = mist_material
	mirror_condensation.position = Vector3(7.80,6.24,-30.20)
	mirror_condensation.rotation.y = -PI*.5
	mirror_condensation.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mirror_condensation.visible = false
	world.add_child(mirror_condensation)
	var fluorescent := _material("Cold fluorescent diffuser", Color("#d3e0dc"), .42)
	fluorescent.emission_enabled = true
	fluorescent.emission = Color("#9bb9c4")
	fluorescent.emission_energy_multiplier = .32
	for fixture_x in [4.0, 7.0]:
		_box("Restroom fluorescent fixture", Vector3(fixture_x,7.40,-31.1), Vector3(1.35,.08,.36), fluorescent)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(fixture_x,6.85,-31.1)
		lamp.light_color = Color("#c8d9df")
		lamp.light_energy = .82
		lamp.omni_range = 6.5
		lamp.visible = show_route_visuals or not hide_campus_blockout_visuals
		world.add_child(lamp)
	var emergency_spill := OmniLight3D.new()
	emergency_spill.name = "Restroom restrained red emergency spill"
	emergency_spill.position = Vector3(7.3,5.45,-31.2)
	emergency_spill.light_color = Color("#a93132")
	emergency_spill.light_energy = .16
	emergency_spill.omni_range = 2.8
	emergency_spill.shadow_enabled = false
	emergency_spill.visible = show_route_visuals or not hide_campus_blockout_visuals
	world.add_child(emergency_spill)
	mirror_text = Label3D.new()
	mirror_text.name = "BloodWriting_CUU_TOI"
	mirror_text.text = "CỨU TÔI"
	mirror_text.font_size = 54
	mirror_text.pixel_size = .006
	mirror_text.modulate = Color("#9b1012")
	# Keep the plea in the clear upper mirror band so it does not cover the
	# reflection silhouettes when An appears behind Hoang.
	mirror_text.position = Vector3(7.79,6.63,-30.20)
	mirror_text.rotation.y = -PI*.5
	mirror_text.visible = false
	world.add_child(mirror_text)
	for i in GANG_SCENES.size():
		var bully_scene := load(GANG_SCENES[i]) as PackedScene
		if bully_scene == null:
			continue
		var bully := bully_scene.instantiate() as Node3D
		bully.name = "GangMember_%d" % (i+1)
		bully.position = _map_old_story_point(Vector3(6.0 + i*1.0,4.8,-27.4))
		bully.rotation.y = PI
		bully.visible = false
		world.add_child(bully)
		bullies.append(bully)
	var an_scene := load("res://assets/characters/an/an.glb") as PackedScene
	if an_scene != null:
		hallway_apparition = an_scene.instantiate() as Node3D
		hallway_apparition.name = "An_HallwayApparition"
		hallway_apparition.position = Vector3(-17.0,6.4,-20.5)
		hallway_apparition.scale = Vector3.ONE * .82
		hallway_apparition.visible = false
		world.add_child(hallway_apparition)

func _setup_mirror_view() -> void:
	mirror_viewport = SubViewport.new()
	mirror_viewport.name = "MirrorReflectionViewport"
	mirror_viewport.size = Vector2i(512, 384)
	mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mirror_viewport.own_world_3d = true
	world.add_child(mirror_viewport)
	mirror_world = Node3D.new()
	mirror_world.name = "MirrorReflectionWorld"
	mirror_viewport.add_child(mirror_world)
	var environment := WorldEnvironment.new()
	var reflection_environment := Environment.new()
	reflection_environment.background_mode = Environment.BG_COLOR
	reflection_environment.background_color = Color("#17191c")
	reflection_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	reflection_environment.ambient_light_color = Color("#8a8580")
	reflection_environment.ambient_light_energy = .55
	environment.environment = reflection_environment
	mirror_world.add_child(environment)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 180, 0)
	fill.light_energy = .7
	mirror_world.add_child(fill)
	mirror_camera = Camera3D.new()
	mirror_camera.position = Vector3(0,1.15,3.3)
	mirror_camera.fov = 48.0
	mirror_camera.current = true
	mirror_world.add_child(mirror_camera)
	mirror_camera.look_at(Vector3(0,1.1,0), Vector3.UP)
	if actor != null and actor.model != null:
		mirror_player = actor.model.duplicate() as Node3D
		if mirror_player != null:
			mirror_player.name = "HoangMirrorReflection"
			mirror_player.position = Vector3(0,0,0.4)
			mirror_player.scale = Vector3.ONE * .8
			mirror_player.rotation.y = PI
			# The gameplay model starts hidden for first-person play; the isolated
			# reflection copy must opt back in so the mirror is not blank.
			mirror_player.visible = true
			mirror_world.add_child(mirror_player)
			var reflected_idle := _find_animation_player(mirror_player)
			mirror_animation = reflected_idle
			if reflected_idle != null:
				_play_named_animation(reflected_idle, "Idle")
	var an_scene := load("res://assets/characters/an/an.glb") as PackedScene
	if an_scene != null:
		apparition = an_scene.instantiate() as Node3D
		apparition.name = "An_OnlyVisibleInMirror"
		# Keep An behind and slightly to Hoang's right in the mirror framing so
		# she remains legible instead of being hidden by his silhouette.
		apparition.position = Vector3(.78,0,-.72)
		apparition.scale = Vector3.ONE * .68
		apparition.visible = false
		mirror_world.add_child(apparition)
	var mirror_surface := world.find_child("Mirror glass",true,false) as MeshInstance3D
	if mirror_surface != null:
		var material := StandardMaterial3D.new()
		material.resource_name = "MirrorReflectionTexture"
		material.albedo_texture = mirror_viewport.get_texture()
		material.roughness = .18
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mirror_surface.material_override = material

func _setup_spatial_audio() -> void:
	stick_audio = _make_spatial_player("MetalStick", "res://assets/audio/sfx/night_stick_scrape.wav", _map_old_story_point(Vector3(5,4.8,-25.5)), -5.0)
	impact_audio = _make_spatial_player("StallImpacts", "res://assets/audio/sfx/night_door_thud.wav", _map_old_story_point(Vector3(2.9,5.2,-31.0)), -4.0)
	breach_audio = _make_spatial_player("BathroomDoorBreach", "res://assets/audio/sfx/night_door_thud.wav", _map_old_story_point(Vector3(5,5.2,-27.0)), -3.0)
	bell_audio = _make_spatial_player("SchoolBell", "res://assets/audio/sfx/school_bell.wav", Vector3(0,9.5,-22.5), -8.0)

func _make_spatial_player(player_name: String, stream_path: String, at: Vector3, volume: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.stream = load(stream_path) as AudioStream
	player.position = at
	player.volume_db = volume
	player.max_distance = 30.0
	player.unit_size = 8.0
	world.add_child(player)
	return player

func play_stick_scrape() -> void:
	if stick_audio != null:
		stick_audio.play()

func play_stall_impact_sound() -> void:
	if impact_audio != null:
		impact_audio.play()

func play_bathroom_door_breach() -> void:
	if breach_audio != null:
		breach_audio.play()

func play_school_bell() -> void:
	if bell_audio != null:
		bell_audio.play()

func play_interaction(duration: float = 0.65) -> void:
	if actor != null:
		actor.play_interaction(duration)

func get_player_position() -> Vector3:
	return actor.global_position if actor != null else Vector3.ZERO

func set_controls_enabled(enabled: bool) -> void:
	if actor != null:
		actor.controls_enabled = enabled

func set_third_person(enabled: bool) -> void:
	if actor != null:
		actor.set_third_person(enabled)

func orbit_mouse(relative: Vector2) -> void:
	if actor != null:
		# A player look input takes priority over the automatic hide-state aim.
		_cancel_hide_camera_tween()
		actor.orbit_mouse(relative)

func toggle_flashlight() -> void:
	if actor != null:
		actor.toggle_flashlight()

func near_main_entry() -> bool:
	if actor == null:
		return false
	var position := actor.global_position
	return (
		position.distance_to(Vector3(0,0,-19.5)) < 2.5
		or position.distance_to(Vector3(-18,0,6)) < 2.5
		or position.distance_to(Vector3(18,0,6)) < 2.5
	)

func inside_mapped_school_from_yard() -> bool:
	if actor == null:
		return false
	var position := actor.global_position
	# Stair B's south approach is the central threshold into the north block.
	var at_stair_b_approach := absf(position.x) <= 2.5 and position.z >= -22.0 and position.z <= -17.2
	# The mapped ground-floor side wings begin at the two courtyard portals.
	var inside_west_wing := absf(position.x + 18.0) <= 2.0 and position.z >= -22.0 and position.z <= 6.0
	var inside_east_wing := absf(position.x - 18.0) <= 2.0 and position.z >= -22.0 and position.z <= 6.0
	return at_stair_b_approach or inside_west_wing or inside_east_wing

func enter_school() -> void:
	if entry_door != null:
		entry_door.visible = false
	if entry_door_blocker != null:
		entry_door_blocker.set_deferred("disabled", true)
	story_zone = "ground_hall"

func restore_ground_hall() -> void:
	enter_school()
	if actor != null:
		actor.teleport_to(STAIR_BASE)

func near_stairwell() -> bool:
	return actor != null and story_zone == "ground_hall" and actor.global_position.distance_to(STAIR_BASE) < 3.0

func enter_stairs() -> void:
	story_zone = "stairs"

func enter_upper_hall() -> void:
	story_zone = "upper_hall"

func near_restroom_door() -> bool:
	return actor != null and story_zone == "upper_hall" and actor.global_position.distance_to(RESTROOM_DOOR) < 2.3

func open_restroom_entry() -> void:
	restroom_entry_open = true
	if restroom_door != null:
		var door_tween := create_tween()
		door_tween.tween_property(restroom_door, "rotation:y", PI*.5, .3)
	if restroom_door_blocker != null:
		restroom_door_blocker.set_deferred("disabled", true)

func crossed_restroom_threshold() -> bool:
	return actor != null and restroom_entry_open and story_zone == "upper_hall" and actor.global_position.x > 14.8 and absf(actor.global_position.z - RESTROOM_DOOR.z) < 1.1

func enter_restroom() -> void:
	actor.set_flashlight_on(true)
	story_zone = "restroom"

func resume_restroom_threat() -> void:
	story_zone = "restroom"
	hide_friends()
	actor.teleport_to(_map_old_story_point(Vector3(5,4.8,-28.2)))
	actor.set_flashlight_on(true)
	actor.set_controls_enabled(true)

func resume_restroom_approach() -> void:
	story_zone = "restroom"
	restroom_entry_open = true
	actor.teleport_to(_map_old_story_point(Vector3(5,4.8,-28.2)))
	actor.set_flashlight_on(true)
	actor.set_controls_enabled(false)
	bring_friends_to_third_floor()

func resume_notice_board_stage() -> void:
	story_zone = "scene56"
	if GameState.scene_id == "scene_06":
		actor.teleport_to(Vector3(-16.55,6.4,-27.05))
	elif actor.global_position.y < 5.0 or actor.global_position.z > -18.0:
		actor.teleport_to(Vector3(-17.0,6.4,-22.4))
	actor.set_flashlight_on(true)
	actor.set_third_person(true)
	actor.set_controls_enabled(true)
	bring_scene56_companions()
	if not bool(GameState.flags.get("ghost_revealed", false)):
		show_scene56_apparition()

func show_scene56_apparition() -> void:
	if hallway_apparition == null or actor == null:
		return
	hallway_apparition.position = Vector3(-17.0,6.4,-27.5)
	hallway_apparition.rotation.y = PI
	hallway_apparition.visible = true
	# A nearby fluorescent pool flickers once while An is visible. Gameplay
	# control stays live, and the camera is already aligned down the hallway.
	var mapped_school := world.find_child("MappedSchoolEnvironment", true, false)
	var level3 := mapped_school.get_node_or_null("Level3") as Node3D if mapped_school != null else null
	var lamp := level3.find_child("Cool Fluorescent", true, false) as OmniLight3D if level3 != null else null
	if lamp != null:
		var original_energy := lamp.light_energy
		var flicker := create_tween()
		flicker.tween_property(lamp, "light_energy", original_energy * .12, .08)
		flicker.tween_property(lamp, "light_energy", original_energy * .72, .11)
		flicker.tween_property(lamp, "light_energy", original_energy, .16)
	if scene56_apparition_tween != null and scene56_apparition_tween.is_running():
		scene56_apparition_tween.kill()
	scene56_apparition_tween = create_tween()
	scene56_apparition_tween.tween_interval(1.35)
	scene56_apparition_tween.tween_callback(func():
		if hallway_apparition != null:
			hallway_apparition.visible = false
	)

func bring_scene56_companions() -> void:
	# Gather the three friends just inside the mapped board bay, outside the
	# center aisle and the route to the provisional locker row.
	var spots := [Vector3(-18.85,6.4,-23.8), Vector3(-18.35,6.4,-23.8), Vector3(-17.85,6.4,-23.8)]
	for i in friends.size():
		friends[i].position = spots[i % spots.size()]
		friends[i].visible = true

func begin_scene56_inspection(kind: String) -> void:
	if actor == null:
		return
	scene56_camera_snapshot = {
		"position": actor.global_position,
		"transform": actor.global_transform,
		"yaw": actor.camera_yaw,
		"pitch": actor.camera_pitch,
		"third_person": actor.spring_arm != null and actor.spring_arm.spring_length > .01,
		"controls": actor.controls_enabled,
		"mouse_mode": Input.mouse_mode,
		"camera_fov": actor.camera.fov if actor.camera != null else 76.0,
	}
	actor.set_controls_enabled(false)
	actor.set_third_person(false)
	var target := Vector3(-17.0, 8.15, -30.25) if kind == "board" else Vector3(-15.42, 7.5, -27.05)
	var look_direction := target - actor.camera.global_position if actor.camera != null else Vector3.FORWARD
	actor.camera_yaw = atan2(-look_direction.x, -look_direction.z)
	actor.camera_pitch = -atan2(look_direction.y, Vector2(look_direction.x, look_direction.z).length())
	if actor.camera != null:
		actor.camera.fov = 43.0
	actor.call("_apply_camera_rotation")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func end_scene56_inspection() -> void:
	if actor == null or scene56_camera_snapshot.is_empty():
		return
	actor.teleport_to(scene56_camera_snapshot.get("position", actor.global_position))
	var prior_transform: Transform3D = scene56_camera_snapshot.get("transform", actor.global_transform)
	actor.global_transform = prior_transform
	actor.velocity = Vector3.ZERO
	actor.camera_yaw = float(scene56_camera_snapshot.get("yaw", actor.camera_yaw))
	actor.camera_pitch = float(scene56_camera_snapshot.get("pitch", actor.camera_pitch))
	actor.set_third_person(bool(scene56_camera_snapshot.get("third_person", true)))
	if actor.camera != null:
		actor.camera.fov = float(scene56_camera_snapshot.get("camera_fov", 76.0))
	actor.call("_apply_camera_rotation")
	actor.set_controls_enabled(bool(scene56_camera_snapshot.get("controls", true)))
	Input.mouse_mode = int(scene56_camera_snapshot.get("mouse_mode", Input.MOUSE_MODE_VISIBLE))
	scene56_camera_snapshot.clear()

func near_locker_a17() -> bool:
	if actor == null:
		return false
	return Vector2(actor.global_position.x + 15.10, actor.global_position.z + 27.05).length() < 1.75

func near_math_test() -> bool:
	if actor == null:
		return false
	return Vector2(actor.global_position.x + 15.10, actor.global_position.z + 27.05).length() < 2.15

func open_locker_a17() -> void:
	var mapped_school := world.find_child("MappedSchoolEnvironment", true, false)
	var pivot := mapped_school.find_child("A17LockerDoorPivot", true, false) as Node3D if mapped_school != null else null
	var contents := mapped_school.find_child("A17DiaryContents", true, false) as Node3D if mapped_school != null else null
	if pivot != null:
		pivot.rotation.y = PI * .5
		var collision := pivot.get_node_or_null("DoorCollision/CollisionShape3D") as CollisionShape3D
		if collision != null:
			collision.set_deferred("disabled", true)
	if contents != null:
		contents.visible = true

func set_math_test_visible(visible: bool) -> void:
	var mapped_school := world.find_child("MappedSchoolEnvironment", true, false)
	var reward := mapped_school.find_child("A17 100 over 100 math test reward", true, false) as MeshInstance3D if mapped_school != null else null
	var marking := mapped_school.find_child("A17 Math test 100 over 100 marking", true, false) as Label3D if mapped_school != null else null
	if reward != null:
		reward.visible = visible
	if marking != null:
		marking.visible = visible

func begin_keepsake_memory() -> void:
	if actor == null:
		return
	keepsake_memory_snapshot = {
		"yaw": actor.camera_yaw,
		"pitch": actor.camera_pitch,
		"third_person": actor.spring_arm != null and actor.spring_arm.spring_length > .01,
		"controls": actor.controls_enabled,
		"mouse_mode": Input.mouse_mode,
	}
	actor.set_controls_enabled(false)
	actor.set_third_person(false)
	actor.camera_yaw = PI
	actor.camera_pitch = -.04
	actor.call("_apply_camera_rotation")
	if keepsake_memory_root == null:
		_build_keepsake_memory()
	keepsake_memory_root.visible = true
	if keepsake_memory_light != null:
		keepsake_memory_light.visible = true

func end_keepsake_memory() -> void:
	if actor == null or keepsake_memory_snapshot.is_empty():
		return
	if keepsake_memory_root != null:
		keepsake_memory_root.visible = false
	if keepsake_memory_light != null:
		keepsake_memory_light.visible = false
	actor.camera_yaw = float(keepsake_memory_snapshot.get("yaw", actor.camera_yaw))
	actor.camera_pitch = float(keepsake_memory_snapshot.get("pitch", actor.camera_pitch))
	actor.set_third_person(bool(keepsake_memory_snapshot.get("third_person", true)))
	actor.call("_apply_camera_rotation")
	actor.set_controls_enabled(bool(keepsake_memory_snapshot.get("controls", true)))
	keepsake_memory_snapshot.clear()

func _build_keepsake_memory() -> void:
	keepsake_memory_root = Node3D.new()
	keepsake_memory_root.name = "Keepsake01WarmMemoryStaging"
	keepsake_memory_root.visible = false
	world.add_child(keepsake_memory_root)
	var an_scene := load("res://assets/characters/an/an.glb") as PackedScene
	if an_scene != null:
		var an_model := an_scene.instantiate() as Node3D
		an_model.name = "An showing her mathematics test"
		an_model.position = Vector3(-16.85,6.4,-24.85)
		an_model.rotation.y = PI
		an_model.scale = Vector3.ONE * .72
		keepsake_memory_root.add_child(an_model)
	# A simple, non-identifying warm silhouette is only a staging partner for the
	# scripted action; it adds no name or backstory beyond “mẹ” in the supplied text.
	var mother := Node3D.new()
	mother.name = "Mother silhouette"
	mother.position = Vector3(-18.0,6.4,-24.85)
	keepsake_memory_root.add_child(mother)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("#98724e")
	cloth.roughness = .96
	var torso := CapsuleMesh.new()
	torso.radius = .28
	torso.height = 1.22
	var torso_node := MeshInstance3D.new()
	torso_node.mesh = torso
	torso_node.material_override = cloth
	torso_node.position.y = .92
	mother.add_child(torso_node)
	var head := SphereMesh.new()
	head.radius = .20
	head.height = .40
	var head_node := MeshInstance3D.new()
	head_node.mesh = head
	head_node.material_override = cloth
	head_node.position.y = 1.68
	mother.add_child(head_node)
	var held_test := MeshInstance3D.new()
	held_test.name = "Warm memory 100 over 100 test"
	var sheet := BoxMesh.new()
	sheet.size = Vector3(.01,.34,.27)
	held_test.mesh = sheet
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("#e7d6a8")
	held_test.material_override = paper
	held_test.position = Vector3(-17.42,7.32,-24.82)
	held_test.rotation.y = -PI * .5
	keepsake_memory_root.add_child(held_test)
	var grade := Label3D.new()
	grade.name = "Warm memory 100 over 100 grade"
	grade.text = "100/100"
	grade.font_size = 15
	grade.pixel_size = .006
	grade.modulate = Color("#4c3928")
	grade.position = Vector3(-17.43,7.33,-24.80)
	grade.rotation.y = PI
	keepsake_memory_root.add_child(grade)
	keepsake_memory_light = OmniLight3D.new()
	keepsake_memory_light.name = "Keepsake01WarmMemoryLight"
	keepsake_memory_light.position = Vector3(-17.4,8.0,-24.2)
	keepsake_memory_light.light_color = Color("#f4c98c")
	keepsake_memory_light.light_energy = 1.1
	keepsake_memory_light.omni_range = 4.5
	keepsake_memory_light.visible = false
	world.add_child(keepsake_memory_light)

func scene56_physical_board() -> Node3D:
	var mapped_school := world.find_child("MappedSchoolEnvironment", true, false)
	var level3 := mapped_school.get_node_or_null("Level3") as Node3D if mapped_school != null else null
	if level3 == null:
		return null
	return level3.find_child("BẢNG TIN TẦNG 3 framed bulletin board", true, false) as Node3D

func resume_mirror_stage() -> void:
	story_zone = "mirror"
	actor.teleport_to(_map_old_story_point(Vector3(6.0,4.8,-30.2)))
	actor.camera_yaw = PI
	actor.call("_apply_camera_rotation")
	actor.set_flashlight_on(true)
	actor.set_controls_enabled(true)
	bring_friends_to_third_floor()

func near_stall_door() -> bool:
	return actor != null and story_zone == "restroom" and actor.global_position.distance_to(Vector3(16.4,6.52,-1.5)) < 1.35

func open_stall() -> void:
	stall_open = true
	if stall_door_blocker != null:
		stall_door_blocker.set_deferred("disabled", true)
	if stall_door != null:
		stall_door.rotation.y = PI*.5

func inside_stall() -> bool:
	if actor == null or not stall_open:
		return false
	var position := actor.global_position
	# First mapped cubicle bounds: x=14.10..16.40, z=−2..−1. Keep the
	# interaction inside its walkable interior, not in the shared center aisle.
	var planar_position := Vector2(position.x,position.z)
	return position.x > 15.38 and position.x < 16.13 and absf(position.z + 1.5) < .36 and planar_position.distance_to(Vector2(STALL_POINT.x,STALL_POINT.z)) < .72

func open_hide_stall() -> void:
	open_stall()

func inside_hide_stall() -> bool:
	return inside_stall()

func set_hidden(value: bool) -> void:
	if actor == null:
		return
	if value and not inside_stall():
		return
	# Keep the last camera direction on exit: +X faces the stall opening in the
	# mapped WC, so the player can step back out without a camera snap.
	if not value:
		_cancel_hide_camera_tween()
	player_hidden = value
	actor.hidden = value
	actor.set_controls_enabled(not value)
	if value:
		stall_open = false
		if stall_door != null:
			stall_door.rotation = Vector3.ZERO
		if stall_door_blocker != null:
			stall_door_blocker.set_deferred("disabled", false)
		_orient_camera_toward_hide_opening()

func _orient_camera_toward_hide_opening() -> void:
	if actor == null or actor.pivot == null:
		return
	_cancel_hide_camera_tween()
	# The production restroom map places the opening/approach on world +X.
	# Convert that direction to actor-local camera yaw so the aim also holds if
	# the player root is rotated, without moving the actor or changing the stall.
	var local_direction := actor.global_transform.basis.orthonormalized().inverse() * Vector3.RIGHT
	if local_direction.length_squared() < 0.0001:
		return
	local_direction = local_direction.normalized()
	var target_yaw := atan2(-local_direction.x, -local_direction.z)
	var start_yaw: float = actor.camera_yaw
	var end_yaw := start_yaw + angle_difference(start_yaw, target_yaw)
	if is_equal_approx(start_yaw, end_yaw):
		actor.call("_apply_camera_rotation")
		return
	hide_camera_tween = create_tween()
	hide_camera_tween.tween_method(
		Callable(self, "_apply_hide_camera_yaw"), start_yaw, end_yaw, 0.55
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_hide_camera_yaw(yaw: float) -> void:
	if actor == null:
		return
	actor.camera_yaw = yaw
	actor.call("_apply_camera_rotation")

func _cancel_hide_camera_tween() -> void:
	if hide_camera_tween != null:
		if hide_camera_tween.is_running():
			hide_camera_tween.kill()
		hide_camera_tween = null

func gang_enters() -> void:
	hide_friends()
	if restroom_door != null:
		restroom_door.rotation.y = 0.0
	if restroom_door_blocker != null:
		restroom_door_blocker.set_deferred("disabled", true)
		var door_burst := create_tween()
		door_burst.tween_property(restroom_door, "rotation:y", -1.15, .18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in bullies.size():
		var bully := bullies[i]
		var end_position := _map_old_story_point(Vector3(6.0 + i*1.0, 4.8, -30.0))
		var animator := _find_animation_player(bully)
		if animator != null:
			_play_named_animation(animator, "Walk")
		bully.visible = true
		var entrance := create_tween()
		entrance.tween_property(bully, "position", end_position, .8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		if animator != null:
			entrance.tween_callback(_play_named_animation.bind(animator, "Idle"))

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _play_named_animation(animator: AnimationPlayer, clip_name: String) -> void:
	for clip in animator.get_animation_list():
		if clip == clip_name or clip.ends_with("/" + clip_name):
			animator.play(clip)
			return

func hide_friends() -> void:
	for friend in friends:
		friend.visible = false

func set_red_realm(enabled: bool) -> void:
	red_realm = enabled
	if night_env != null:
		night_env.adjustment_enabled = enabled
		night_env.adjustment_saturation = .3 if enabled else 1.0
		# Environment has no adjustment_color property in Godot 4.7. The red
		# ColorRect overlay in game.gd supplies the tint; keep the valid grading
		# and glow effects here for the 3D scene itself.
		night_env.glow_enabled = enabled

func fade_red_realm(duration: float) -> void:
	if night_env == null:
		return
	night_env.adjustment_enabled = true
	var fade := create_tween()
	fade.set_parallel(true)
	fade.tween_property(night_env, "adjustment_saturation", 1.0, duration)
	fade.chain().tween_callback(func():
		if night_env != null:
			night_env.glow_enabled = false
			night_env.adjustment_enabled = false
	)

func impact_stall_door(_hit_number: int) -> void:
	if stall_door == null:
		return
	var base_angle := stall_door.rotation.y
	var shake := create_tween()
	shake.tween_property(stall_door, "rotation:y", base_angle + .10, .07)
	shake.tween_property(stall_door, "rotation:y", base_angle - .07, .06)
	shake.tween_property(stall_door, "rotation:y", base_angle, .08)
	if actor != null and actor.pivot != null:
		var base_pivot := actor.pivot.position
		var camera_bump := create_tween()
		camera_bump.tween_property(actor.pivot, "position:y", base_pivot.y - .045, .06)
		camera_bump.tween_property(actor.pivot, "position:y", base_pivot.y + .02, .07)
		camera_bump.tween_property(actor.pivot, "position:y", base_pivot.y, .09)

func reveal_mirror_writing() -> void:
	set_hidden(false)
	if mirror_condensation != null:
		mirror_condensation.visible = true
		var mist_material := mirror_condensation.material_override as ShaderMaterial
		if mist_material != null:
			var mist := create_tween()
			mist.tween_property(mist_material, "shader_parameter/mist_strength", .2, .5)
			mist.tween_callback(func():
				if mirror_text != null:
					mirror_text.visible = true
			)
	if mirror_text != null:
		mirror_text.visible = false
	story_zone = "mirror"
	for bully in bullies:
		bully.visible = false

func bring_friends_to_third_floor() -> void:
	var spots := [Vector3(15.0,6.4,.5), Vector3(15.2,6.4,1.0), Vector3(15.0,6.4,1.5)]
	for i in friends.size():
		friends[i].position = spots[i % spots.size()]
		friends[i].visible = true

func reveal_friend(index: int) -> void:
	if index >= 0 and index < friends.size():
		friends[index].visible = true

func hide_apparition() -> void:
	if apparition != null:
		apparition.visible = false
	if hallway_apparition != null:
		hallway_apparition.visible = false

func show_mirror_apparition() -> void:
	_face_camera_toward_mirror_surface()
	if apparition != null:
		apparition.visible = true

func _face_camera_toward_mirror_surface() -> void:
	if actor == null or world == null:
		return
	var mirror_surface := world.find_child("Mirror glass", true, false) as MeshInstance3D
	if mirror_surface == null or actor.camera == null:
		return
	var to_mirror := mirror_surface.global_position - actor.camera.global_position
	if to_mirror.length_squared() < 0.0001:
		return
	# Resolve the aim in Hoang's local frame so this also works if the actor's
	# root has been rotated. Yaw follows the physical mirror's horizontal
	# direction; pitch aligns the first-person camera with its actual center.
	var local_direction := actor.global_transform.basis.orthonormalized().inverse() * to_mirror.normalized()
	actor.camera_yaw = atan2(-local_direction.x, -local_direction.z)
	actor.camera_pitch = asin(clampf(local_direction.y, -1.0, 1.0))
	actor.call("_apply_camera_rotation")

func show_hallway_apparition() -> void:
	if hallway_apparition != null:
		hallway_apparition.visible = true

func focus_scene56_board() -> void:
	if actor == null:
		return
	var target := Vector3(-17.0, 7.5, -28.45)
	var direction := target - actor.camera.global_position
	var local_direction := actor.global_transform.basis.orthonormalized().inverse() * direction.normalized()
	var target_yaw := atan2(-local_direction.x, -local_direction.z)
	var target_pitch := asin(clampf(local_direction.y, -1.0, 1.0))
	var initial_yaw := actor.camera_yaw
	var initial_pitch := actor.camera_pitch
	var camera_tween := create_tween()
	camera_tween.tween_method(func(alpha: float):
		actor.camera_yaw = lerp_angle(initial_yaw, target_yaw, alpha)
		actor.camera_pitch = lerpf(initial_pitch, target_pitch, alpha)
		actor.call("_apply_camera_rotation")
	, 0.0, 1.0, .42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var mapped_school := world.find_child("MappedSchoolEnvironment", true, false)
	var level3 := mapped_school.get_node_or_null("Level3") as Node3D if mapped_school != null else null
	var lamp := level3.find_child("Cool Fluorescent", true, false) as OmniLight3D if level3 != null else null
	if lamp != null:
		var original_energy := lamp.light_energy
		var flicker := create_tween()
		flicker.tween_property(lamp, "light_energy", original_energy * .10, .08)
		flicker.tween_property(lamp, "light_energy", original_energy * .72, .12)
		flicker.tween_property(lamp, "light_energy", original_energy, .18)

func near_mirror() -> bool:
	return actor != null and actor.global_position.distance_to(_map_old_story_point(Vector3(6.0,4.8,-30.2))) < 2.2

func near_notice_board() -> bool:
	return actor != null and Vector2(actor.global_position.x + 17.0, actor.global_position.z + 27.0).length() < 2.15

func turn_from_mirror() -> void:
	if actor != null:
		# Dialogue does not fully suppress captured mouse look. Re-align first so
		# the next-E turn remains relative to the mirror, not the orbited yaw.
		_face_camera_toward_mirror_surface()
		actor.camera_yaw += PI
		actor.call("_apply_camera_rotation")

func turn_back_to_hallway() -> void:
	if actor != null:
		actor.camera_yaw -= PI
		actor.call("_apply_camera_rotation")

func reset_restroom_event() -> void:
	story_zone = "restroom"
	stall_open = false
	set_hidden(false)
	actor.teleport_to(_map_old_story_point(Vector3(5,4.8,-28.2)))
	if stall_door_blocker != null:
		stall_door_blocker.set_deferred("disabled", false)
	if restroom_door_blocker != null:
		restroom_door_blocker.set_deferred("disabled", false)
	if stall_door != null:
		stall_door.rotation = Vector3.ZERO
	if restroom_door != null:
		restroom_door.rotation = Vector3.ZERO
	for i in bullies.size():
		var bully := bullies[i]
		bully.position = _map_old_story_point(Vector3(6.0 + i*1.0,4.8,-27.4))
		bully.rotation.y = PI
		bully.visible = false
	hide_friends()
