extends Node3D

## Standalone, additive school environment built from reusable low-poly modules.
## Coordinates follow SCHOOL_ARCHITECTURE_MAP.md: +X east, -Z north.
const PLAYER_SCRIPT := preload("res://scripts/visual/hoang_controller_3d.gd")
const FLOOR_HEIGHT := 3.2
const LEVELS := 3
var standalone_player_enabled := true
var standalone_lighting_enabled := true

var mats: Dictionary = {}
var world_root: Node3D
var player: HoangController3D

func _ready() -> void:
	_setup_input()
	_build_materials()
	if standalone_lighting_enabled:
		var env := WorldEnvironment.new()
		env.name = "NightEnvironment"
		var environment := Environment.new()
		environment.background_mode = Environment.BG_SKY
		var sky := Sky.new()
		var sky_mat := ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color("#071323")
		sky_mat.sky_horizon_color = Color("#253444")
		sky_mat.ground_bottom_color = Color("#10151a")
		sky_mat.ground_horizon_color = Color("#252d35")
		sky.sky_material = sky_mat
		environment.sky = sky
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("#405562")
		environment.ambient_light_energy = .22
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.environment = environment
		add_child(env)
		var moon := DirectionalLight3D.new()
		moon.name = "Moonlight"
		moon.rotation_degrees = Vector3(-42, -28, 0)
		moon.light_color = Color("#8194a6")
		moon.light_energy = .19
		moon.shadow_enabled = true
		add_child(moon)
	_build_ground()
	for level in range(LEVELS):
		_build_level(level)
	_build_rooftop()
	if standalone_player_enabled:
		_build_player()

func _build_materials() -> void:
	mats = {
		"wall": _textured_mat("Aged Cream Plaster", Color("#b9b4a4"), "res://assets/materials/school/old_plaster.png", .97, .42),
		"band": _textured_mat("Damp Blue Green Paint", Color("#34494d"), "res://assets/materials/school/damp_base.png", .98, .55),
		"wall_base_band": _textured_mat("Worn Blue Green Dado", Color("#65716e"), "res://assets/materials/school/damp_base.png", .98, .55),
		"tile": _textured_mat("Worn Brown School Tile", Color("#716052"), "res://assets/materials/school/floor_ceramic.png", .96, .7),
		"concrete": _textured_mat("Weathered Ceiling Concrete", Color("#77766d"), "res://assets/materials/school/ceiling_concrete.png", .98, .48),
		"wood": _textured_mat("Near Black Worn Wood", Color("#45372f"), "res://assets/materials/school/worn_wood.png", .96, .58),
		"metal": _textured_mat("Aged Painted Iron", Color("#344148"), "res://assets/materials/school/painted_metal.png", .9, .7),
		"glass": _mat("Near Black Night Glass", Color("#0d171c"), .38),
		"rail": _mat("Near Black School Rail", Color("#202b30"), .72),
		"chalk": _textured_mat("Chalkboard", Color("#18352e"), "res://assets/materials/school/notice_felt.png"),
		"paper": _mat("Aged Paper", Color("#aaa18b")),
		"sign": _mat("Dark Enamel Wayfinding Sign", Color("#12222d"), .74),
		"emergency_case": _textured_mat("Dark Red Fire Cabinet", Color("#51282a"), "res://assets/materials/school/painted_metal.png", .94, .7),
		"leaf": _mat("Dark Foliage", Color("#273c31")),
		"leaf_variation": _mat("Muted Foliage Variation", Color("#354b39")),
		"grass": _mat("Courtyard Low Grass", Color("#48664c")),
		"soil": _mat("Courtyard Dark Soil", Color("#413b32")),
		"flower": _mat("Muted Flower", Color("#713b3a")),
		"porcelain": _mat("Worn Porcelain", Color("#aeb8b1"), .38),
		"warm": _mat("Warm Light Housing", Color("#8b754e")),
		"stage_fabric": _mat("Faded Stage Fabric", Color("#59414a")),
		"stage_fabric_fold": _mat("Stage Fabric Fold", Color("#382e39")),
		"banner": _mat("Student Union Red", Color("#8a3030")),
		"book": _mat("Old School Books", Color("#4d6270")),
		"ink": _mat("Black Lettering", Color("#172832")),
		"emergency_lens": _mat("Muted Red Emergency Lens", Color("#a81519"), .28),
	}
	var night_glass := mats.glass as StandardMaterial3D
	night_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	night_glass.albedo_color.a = .72
	var emergency_lens := mats.emergency_lens as StandardMaterial3D
	emergency_lens.emission_enabled = true
	emergency_lens.emission = Color("#8e1014")
	emergency_lens.emission_energy_multiplier = 1.35

func _mat(label: String, color: Color, roughness := .86) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "M_" + label.replace(" ", "")
	material.albedo_color = color
	material.roughness = roughness
	return material

func _textured_mat(label: String, color: Color, path: String, roughness := .86, tiles_per_metre := .5) -> StandardMaterial3D:
	var material := _mat(label,color,roughness)
	var texture := load(path) as Texture2D
	if texture != null:
		material.albedo_texture = texture
		# The supplied school textures are intentionally small. Nearest sampling
		# keeps their restrained PS2-era surface breakup instead of smoothing it
		# into a modern high-frequency PBR finish.
		var is_psx_school_texture := path.begins_with("res://assets/props/school/psx_school_kit_free/") or path.begins_with("res://assets/materials/school/")
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if is_psx_school_texture else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		# World-space tiling keeps the same plaster/tile scale across different
		# room widths and adjacent modular wall/floor pieces.
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		var texture_scale: float = 2.0 if path.ends_with("floor_ceramic.png") else tiles_per_metre
		material.uv1_scale = Vector3.ONE * texture_scale
	return material

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material, collision := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = label + "Body"
		body.position = at
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)
	return instance

func _floor_with_openings(parent: Node3D, label: String, center: Vector3, size: Vector2, y: float, holes: Array[Rect2], floor_material: Material) -> void:
	var xb: Array[float]=[center.x-size.x*.5,center.x+size.x*.5]
	var zb: Array[float]=[center.z-size.y*.5,center.z+size.y*.5]
	for hole in holes:
		xb.append(clampf(hole.position.x,center.x-size.x*.5,center.x+size.x*.5))
		xb.append(clampf(hole.end.x,center.x-size.x*.5,center.x+size.x*.5))
		zb.append(clampf(hole.position.y,center.z-size.y*.5,center.z+size.y*.5))
		zb.append(clampf(hole.end.y,center.z-size.y*.5,center.z+size.y*.5))
	xb.sort(); zb.sort()
	for xi in range(xb.size()-1):
		for zi in range(zb.size()-1):
			var x0:=xb[xi]; var x1:=xb[xi+1]; var z0:=zb[zi]; var z1:=zb[zi+1]
			if x1-x0 < .01 or z1-z0 < .01: continue
			var midpoint:=Vector2((x0+x1)*.5,(z0+z1)*.5)
			var cut:=false
			for hole in holes:
				if hole.has_point(midpoint):
					cut=true; break
			if not cut:
				_box(parent,label+" tile",Vector3((x0+x1)*.5,y,(z0+z1)*.5),Vector3(x1-x0,.24,z1-z0),floor_material,true)

func _centered_window_centers(center: float, span: float, count: int) -> Array[float]:
	var centers: Array[float] = []
	if count <= 1:
		centers.append(center)
		return centers
	# Preserve a clear plaster pier at each end, then distribute every bay evenly.
	# Single windows stay on the room axis instead of inheriting an edge offset.
	var usable_span := maxf(span - 3.0, 0.0)
	for i in range(count):
		centers.append(center - usable_span * .5 + usable_span * float(i) / float(count - 1))
	return centers

func _wall_window_apertures(parent: Node3D, label: String, center: Vector3, horizontal_span: float, y: float, along_x: bool, preferred_centers: Array[float] = []) -> void:
	# Build a real opening around each glazed window; leave collision only in the
	# sill, lintel and piers instead of hiding glass behind a solid wall.
	var count := maxi(1, int(horizontal_span / 2.6))
	var centers := _centered_window_centers(center.x if along_x else center.z, horizontal_span, count)
	if not preferred_centers.is_empty():
		centers = preferred_centers
	var wall_depth := .2
	var bottom_y := y+.06
	var top_y := y+3.18
	if along_x:
		var z := center.z
		_box(parent,label+" wall below windows",Vector3(center.x,y+.59,z),Vector3(horizontal_span,1.06,wall_depth),mats.wall,true)
		_box(parent,label+" wall above windows",Vector3(center.x,y+2.94,z),Vector3(horizontal_span,.48,wall_depth),mats.wall,true)
		var left_edge := center.x-horizontal_span*.5
		for window_x in centers:
			var pier_width := maxf(window_x-.56-left_edge,0.0)
			if pier_width>.02:
				_box(parent,label+" wall pier",Vector3(left_edge+pier_width*.5,(bottom_y+top_y)*.5,z),Vector3(pier_width,top_y-bottom_y,wall_depth),mats.wall,true)
			left_edge=window_x+.56
		var right_edge := center.x+horizontal_span*.5
		if right_edge-left_edge>.02:
			_box(parent,label+" wall pier",Vector3((left_edge+right_edge)*.5,(bottom_y+top_y)*.5,z),Vector3(right_edge-left_edge,top_y-bottom_y,wall_depth),mats.wall,true)
	else:
		var x := center.x
		_box(parent,label+" wall below windows",Vector3(x,y+.59,center.z),Vector3(wall_depth,1.06,horizontal_span),mats.wall,true)
		_box(parent,label+" wall above windows",Vector3(x,y+2.94,center.z),Vector3(wall_depth,.48,horizontal_span),mats.wall,true)
		var low_edge := center.z-horizontal_span*.5
		for window_z in centers:
			var pier_depth := maxf(window_z-.56-low_edge,0.0)
			if pier_depth>.02:
				_box(parent,label+" wall pier",Vector3(x,(bottom_y+top_y)*.5,low_edge+pier_depth*.5),Vector3(wall_depth,top_y-bottom_y,pier_depth),mats.wall,true)
			low_edge=window_z+.56
		var high_edge := center.z+horizontal_span*.5
		if high_edge-low_edge>.02:
			_box(parent,label+" wall pier",Vector3(x,(bottom_y+top_y)*.5,(low_edge+high_edge)*.5),Vector3(wall_depth,top_y-bottom_y,high_edge-low_edge),mats.wall,true)

func _room_trim_x(parent: Node3D, label: String, center_x: float, y: float, center_z: float, span: float, height: float, thickness: float, material: Material) -> void:
	if span > .02:
		_box(parent,label,Vector3(center_x,y,center_z),Vector3(span,height,thickness),material)

func _room_trim_z(parent: Node3D, label: String, center_x: float, y: float, center_z: float, span: float, height: float, thickness: float, material: Material) -> void:
	if span > .02:
		_box(parent,label,Vector3(center_x,y,center_z),Vector3(thickness,height,span),material)

func _room_shell_edge_details(parent: Node3D, label: String, center: Vector3, width: float, depth: float, floor_y: float, corridor_wall_along_x: bool, corridor_wall_sign: float, door_center: float, door_width: float, suppress_north_end_trim := false, suppress_south_end_trim := false) -> void:
	# A shallow concrete ceiling reveal and blue-gray base datum unify each
	# shell. Skirting segments stop at the doorway; all pieces are visual-only.
	var cornice_y: float = floor_y + 2.96
	var skirt_y: float = floor_y + .17
	var half_width: float = width * .5
	var half_depth: float = depth * .5
	var north_z: float = center.z - half_depth
	var south_z: float = center.z + half_depth
	var west_x: float = center.x - half_width
	var east_x: float = center.x + half_width
	var door_start: float = door_center - door_width * .5
	var door_end: float = door_center + door_width * .5
	if not suppress_north_end_trim:
		_room_trim_x(parent,label+" north cornice",center.x,cornice_y,north_z+.15,width,.12,.08,mats.concrete)
	if not suppress_south_end_trim:
		_room_trim_x(parent,label+" south cornice",center.x,cornice_y,south_z-.15,width,.12,.08,mats.concrete)
	_room_trim_z(parent,label+" west cornice",west_x+.15,cornice_y,center.z,depth,.12,.08,mats.concrete)
	_room_trim_z(parent,label+" east cornice",east_x-.15,cornice_y,center.z,depth,.12,.08,mats.concrete)
	var north_is_corridor: bool = corridor_wall_along_x and corridor_wall_sign < 0.0
	var south_is_corridor: bool = corridor_wall_along_x and corridor_wall_sign > 0.0
	var west_is_corridor: bool = not corridor_wall_along_x and corridor_wall_sign < 0.0
	var east_is_corridor: bool = not corridor_wall_along_x and corridor_wall_sign > 0.0
	if north_is_corridor:
		_room_trim_x(parent,label+" north skirting west",west_x+(door_start-west_x)*.5,skirt_y,north_z+.15,door_start-west_x,.10,.08,mats.band)
		_room_trim_x(parent,label+" north skirting east",door_end+(east_x-door_end)*.5,skirt_y,north_z+.15,east_x-door_end,.10,.08,mats.band)
	elif not suppress_north_end_trim:
		_room_trim_x(parent,label+" north skirting",center.x,skirt_y,north_z+.15,width,.10,.08,mats.band)
	if south_is_corridor:
		_room_trim_x(parent,label+" south skirting west",west_x+(door_start-west_x)*.5,skirt_y,south_z-.15,door_start-west_x,.10,.08,mats.band)
		_room_trim_x(parent,label+" south skirting east",door_end+(east_x-door_end)*.5,skirt_y,south_z-.15,east_x-door_end,.10,.08,mats.band)
	elif not suppress_south_end_trim:
		_room_trim_x(parent,label+" south skirting",center.x,skirt_y,south_z-.15,width,.10,.08,mats.band)
	if west_is_corridor:
		_room_trim_z(parent,label+" west skirting north",west_x+.15,skirt_y,north_z+(door_start-north_z)*.5,door_start-north_z,.10,.08,mats.band)
		_room_trim_z(parent,label+" west skirting south",west_x+.15,skirt_y,door_end+(south_z-door_end)*.5,south_z-door_end,.10,.08,mats.band)
	else:
		_room_trim_z(parent,label+" west skirting",west_x+.15,skirt_y,center.z,depth,.10,.08,mats.band)
	if east_is_corridor:
		_room_trim_z(parent,label+" east skirting north",east_x-.15,skirt_y,north_z+(door_start-north_z)*.5,door_start-north_z,.10,.08,mats.band)
		_room_trim_z(parent,label+" east skirting south",east_x-.15,skirt_y,door_end+(south_z-door_end)*.5,south_z-door_end,.10,.08,mats.band)
	else:
		_room_trim_z(parent,label+" east skirting",east_x-.15,skirt_y,center.z,depth,.10,.08,mats.band)

func _label(parent: Node3D, text: String, at: Vector3, facing := 0.0, size := 26) -> void:
	# The Principal's Office was visually indistinguishable from an ordinary
	# room plaque at gameplay distance. Give that existing mapped office a
	# purpose-sized entrance sign without changing any other room's signage.
	var plaque_size := Vector3(2.45,.56,.06) if text == "PHÒNG HIỆU TRƯỞNG" else Vector3(1.5,.42,.06)
	var plaque := _box(parent, "SignPlaque", at, plaque_size, mats.sign)
	var sign := Label3D.new()
	sign.text = text
	sign.font_size = 24 if text == "PHÒNG HIỆU TRƯỞNG" else size
	sign.pixel_size = .008 if text == "PHÒNG HIỆU TRƯỞNG" else .009
	sign.modulate = Color("#d0c8b1")
	sign.outline_size = 3
	sign.outline_modulate = Color("#090f13")
	sign.position = at + Vector3(0,0,.04).rotated(Vector3.UP, facing)
	sign.rotation.y = facing
	parent.add_child(sign)
	plaque.rotation.y = facing

func _school_desk(parent: Node3D, label: String, floor_center: Vector3, width := .82, depth := .62, top_height := .78) -> void:
	# Complete, deliberately sparse school furniture: a readable timber top,
	# four metal legs and a front apron. Every part uses metre-scale dimensions.
	_box(parent,label+" timber top",floor_center+Vector3(0,top_height,0),Vector3(width,.08,depth),mats.wood,true)
	for x_sign in [-1.0,1.0]:
		for z_sign in [-1.0,1.0]:
			_box(parent,label+" iron leg",floor_center+Vector3(x_sign*(width*.5-.065),top_height*.5,z_sign*(depth*.5-.065)),Vector3(.055,top_height,.055),mats.metal)
	_box(parent,label+" front apron",floor_center+Vector3(0,top_height-.18,-depth*.5+.045),Vector3(width-.14,.30,.045),mats.wood)

func _school_bench(parent: Node3D, label: String, floor_center: Vector3, back_direction: Vector3) -> void:
	var across_x := absf(back_direction.z) > .5
	var seat_size := Vector3(.66,.08,.40) if across_x else Vector3(.40,.08,.66)
	var back_size := Vector3(.66,.48,.06) if across_x else Vector3(.06,.48,.66)
	_box(parent,label+" seat",floor_center+Vector3(0,.46,0),seat_size,mats.wood,true)
	_box(parent,label+" back",floor_center+Vector3(0,.70,0)+back_direction*.18,back_size,mats.wood)
	for side in [-1.0,1.0]:
		var support_offset := Vector3(side*.26,0,0) if across_x else Vector3(0,0,side*.26)
		_box(parent,label+" iron support",floor_center+Vector3(0,.23,0)+support_offset,Vector3(.05,.46,.05),mats.metal)

func _supported_worktop(parent: Node3D, title: String, fixture_kind: String, support_kind: String, station: int, floor_center: Vector3, size: Vector2, height: float, material: Material) -> void:
	# Repeated furniture uses stable numbered names so each physical surface and
	# each support can be audited independently in the assembled floor scene.
	var fixture_name := "%s %s@%02d" % [title,fixture_kind,station]
	_box(parent,fixture_name,floor_center+Vector3(0,height,0),Vector3(size.x,.10,size.y),material,true)
	var leg_height := height-.05
	var support_index := (station-1)*4
	for x_sign in [-1.0,1.0]:
		for z_sign in [-1.0,1.0]:
			support_index += 1
			var leg_name := "%s %s@%02d" % [title,support_kind,support_index]
			var leg_x: float = x_sign*(size.x*.5-.07)
			var leg_z: float = z_sign*(size.y*.5-.07)
			_box(parent,leg_name,floor_center+Vector3(leg_x,leg_height*.5,leg_z),Vector3(.055,leg_height,.055),mats.metal,true)

func _supported_seat(parent: Node3D, title: String, seat_kind: String, station: int, floor_center: Vector3, size := .42, back_direction := Vector3.ZERO) -> void:
	var seat_name := "%s %s@%02d" % [title,seat_kind,station]
	_box(parent,seat_name,floor_center+Vector3(0,.47,0),Vector3(size,.10,size),mats.wood,true)
	for corner in range(4):
		var x_sign := -1.0 if corner%2 == 0 else 1.0
		var z_sign := -1.0 if corner < 2 else 1.0
		var support_name := "%s %s leg@%02d" % [title,seat_kind,station*4+corner+1]
		_box(parent,support_name,floor_center+Vector3(x_sign*(size*.5-.055),.22,z_sign*(size*.5-.055)),Vector3(.045,.44,.045),mats.metal,true)
	if back_direction.length_squared() > .5:
		var back_size := Vector3(size,.44,.055) if absf(back_direction.z) > .5 else Vector3(.055,.44,size)
		_box(parent,seat_name+" back",floor_center+Vector3(0,.77,0)+back_direction*.20,back_size,mats.wood,true)

func _computer_station(parent: Node3D, title: String, station: int, floor_center: Vector3, cpu_direction: float) -> void:
	_supported_worktop(parent,title,"computer desk top","computer desk leg",station,floor_center,Vector2(1.05,.72),.82,mats.wood)
	# A CRT silhouette with a lit phosphor face, pedestal, keyboard and a
	# grounded tower reads as a workstation rather than a cluster of black boxes.
	var bezel_z := floor_center.z-.11
	_box(parent,"%s monitor bezel@%02d" % [title,station],floor_center+Vector3(0,1.075,bezel_z),Vector3(.48,.36,.08),mats.metal,true)
	var screen_material := _mat("CRT Phosphor %02d" % station,Color("#83afb0"),.34)
	_box(parent,"%s monitor screen@%02d" % [title,station],floor_center+Vector3(0,1.08,bezel_z+.046),Vector3(.38,.26,.018),screen_material)
	_box(parent,"%s monitor stand@%02d" % [title,station],floor_center+Vector3(0,.93,bezel_z),Vector3(.09,.18,.10),mats.metal,true)
	_box(parent,"%s keyboard@%02d" % [title,station],floor_center+Vector3(0,.895,floor_center.z+.19),Vector3(.43,.035,.17),mats.metal,true)
	for key_row in range(2):
		_box(parent,"%s keyboard key row@%02d-%d" % [title,station,key_row+1],floor_center+Vector3(0,.918,floor_center.z+.15+float(key_row)*.065),Vector3(.35,.012,.012),mats.paper)
	var tower_x := floor_center.x+cpu_direction*.68
	_box(parent,"%s computer tower@%02d" % [title,station],Vector3(tower_x,floor_center.y+.25,floor_center.z-.02),Vector3(.22,.50,.40),mats.metal,true)
	_box(parent,"%s tower drive@%02d" % [title,station],Vector3(tower_x+cpu_direction*.114,floor_center.y+.34,floor_center.z-.10),Vector3(.012,.07,.15),mats.paper)
	_supported_seat(parent,title,"computer chair",station,floor_center+Vector3(0,0,.92),.46,Vector3(0,0,1))

func _room_ceiling_fixture(parent: Node3D, label: String, center: Vector3, floor_y: float) -> void:
	var fixture_scene := load("res://assets/props/school/psx_school_kit_free/glb/ceiling_light.glb") as PackedScene
	if fixture_scene != null:
		var fixture := fixture_scene.instantiate() as Node3D
		if fixture != null:
			fixture.name = label + " PSX fluorescent fixture"
			# The source uses a floor-level pivot; its mesh spans local Y=2.92..3.00 m.
			fixture.position = Vector3(center.x,floor_y,center.z)
			parent.add_child(fixture)

func _room_ceiling_light(parent: Node3D, label: String, center: Vector3, floor_y: float, is_classroom: bool) -> void:
	_room_ceiling_fixture(parent,label,center,floor_y)
	# Sparse, low cool pools preserve strong falloff while leaving clues readable.
	_light(parent,Vector3(center.x,floor_y+2.71,center.z),Color("#a9c4cf"),1.35 if is_classroom else .95,4.4)

func _school_ceiling_fan(parent: Node3D, label: String, center: Vector3, floor_y: float) -> void:
	# Three simple wood blades and a dark iron motor match the existing school fan.
	var fan := Node3D.new()
	fan.name = label+" ceiling fan"
	fan.position = Vector3(center.x-.75,floor_y+2.73,center.z-.4)
	parent.add_child(fan)
	var hub := MeshInstance3D.new()
	hub.name = label+" fan motor housing"
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = .09
	hub_mesh.bottom_radius = .13
	hub_mesh.height = .18
	hub.mesh = hub_mesh
	hub.material_override = mats.metal
	fan.add_child(hub)
	_box(fan,label+" fan downrod",Vector3(0,.12,0),Vector3(.035,.22,.035),mats.metal)
	for blade_index in range(3):
		var blade := _box(fan,label+" fan blade %d" % blade_index,Vector3(0,0,-.53),Vector3(.17,.035,.92),mats.wood)
		blade.rotation.y = TAU*float(blade_index)/3.0
		var blade_trim := _box(fan,label+" fan blade trim %d" % blade_index,Vector3(0,.022,-.53),Vector3(.045,.012,.76),mats.band)
		blade_trim.rotation.y = blade.rotation.y

func _visual_cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, material: Material, sides := 8) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = sides
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = cylinder
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _chess_piece_visual(parent: Node3D, label: String, at: Vector3, is_light: bool, role: String) -> void:
	var piece_material: Material = mats.paper if is_light else mats.wood
	_visual_cylinder(parent,label+" base",at+Vector3(0,.025,0),.052,.05,piece_material,6)
	_visual_cylinder(parent,label+" stem",at+Vector3(0,.105,0),.027,.13,piece_material,6)
	match role:
		"pawn":
			_visual_cylinder(parent,label+" head",at+Vector3(0,.19,0),.047,.055,piece_material,6)
		"rook":
			_box(parent,label+" crenellated crown",at+Vector3(0,.185,0),Vector3(.105,.065,.105),piece_material)
		"knight":
			var head := _box(parent,label+" knight head",at+Vector3(0,.19,-.018),Vector3(.075,.12,.10),piece_material)
			head.rotation.x = deg_to_rad(-12.0)
		"bishop":
			_visual_cylinder(parent,label+" bishop mitre",at+Vector3(0,.19,0),.036,.07,piece_material,5)
			_box(parent,label+" bishop cut",at+Vector3(0,.195,.034),Vector3(.014,.045,.014),mats.band)
		"queen":
			_visual_cylinder(parent,label+" queen crown",at+Vector3(0,.19,0),.052,.045,piece_material,8)
			_visual_cylinder(parent,label+" queen crown point",at+Vector3(0,.235,0),.022,.04,piece_material,6)
		"king":
			_visual_cylinder(parent,label+" king crown",at+Vector3(0,.19,0),.052,.045,piece_material,8)
			_box(parent,label+" king cross upright",at+Vector3(0,.26,0),Vector3(.025,.09,.025),piece_material)
			_box(parent,label+" king crossbar",at+Vector3(0,.275,0),Vector3(.075,.02,.025),piece_material)

func _chemistry_lab_finish(parent: Node3D, title: String, center: Vector3, y: float) -> void:
	# Three compact, repeatable experiment sets make the chemistry room read as
	# an active school lab while keeping every new piece decorative and non-colliding.
	var solution_green := _mat("Muted Green Chemistry Solution",Color("#728f83"),.42)
	var solution_amber := _mat("Muted Amber Chemistry Solution",Color("#9a8058"),.42)
	for station in range(3):
		var station_x := center.x-1.35+float(station)*1.35
		var bench_z := center.z+.55
		var rack_z := bench_z-.80
		_box(parent,title+" test-tube rack base@%02d" % (station+1),Vector3(station_x,y+1.005,rack_z),Vector3(.62,.07,.24),mats.wood)
		_box(parent,title+" test-tube rack upper rail@%02d" % (station+1),Vector3(station_x,y+1.13,rack_z),Vector3(.62,.045,.20),mats.metal)
		for tube in range(4):
			var tube_x := station_x-.21+float(tube)*.14
			_visual_cylinder(parent,title+" test tube@%02d-%02d" % [station+1,tube+1],Vector3(tube_x,y+1.22,rack_z),.027,.22,mats.glass,6)
			_box(parent,title+" test-tube sample@%02d-%02d" % [station+1,tube+1],Vector3(tube_x,y+1.16,rack_z),Vector3(.032,.055,.032),solution_green if (tube+station)%2==0 else solution_amber)
		var burner_z := bench_z+.42
		_visual_cylinder(parent,title+" Bunsen burner base@%02d" % (station+1),Vector3(station_x-.23,y+1.01,burner_z),.075,.08,mats.metal,8)
		_visual_cylinder(parent,title+" Bunsen burner barrel@%02d" % (station+1),Vector3(station_x-.23,y+1.13,burner_z),.027,.18,mats.metal,8)
		_box(parent,title+" burner collar@%02d" % (station+1),Vector3(station_x-.23,y+1.225,burner_z),Vector3(.085,.035,.085),mats.warm)
		var flask_x := station_x+.19
		_visual_cylinder(parent,title+" flask body@%02d" % (station+1),Vector3(flask_x,y+1.10,burner_z),.075,.17,mats.glass,7)
		_visual_cylinder(parent,title+" flask neck@%02d" % (station+1),Vector3(flask_x,y+1.22,burner_z),.031,.12,mats.glass,7)
		_box(parent,title+" flask solution@%02d" % (station+1),Vector3(flask_x,y+1.07,burner_z),Vector3(.10,.045,.10),solution_amber if station==1 else solution_green)
	# A mounted instruction panel sits on the east solid wall, clear of the entry and windows.
	var board_x := center.x+3.38
	var board_z := center.z+1.45
	_box(parent,title+" chemical safety panel",Vector3(board_x,y+1.82,board_z),Vector3(.08,1.02,2.05),mats.band)
	_box(parent,title+" safety panel frame top",Vector3(board_x-.05,y+2.36,board_z),Vector3(.06,.07,2.17),mats.wood)
	_classroom_text(parent,"KÍNH BẢO HỘ  •  RỬA TAY",Vector3(board_x-.055,y+2.09,board_z),-PI/2.0,15,Color("#e0d8c3"),.006)
	for symbol in range(3):
		_box(parent,title+" safety pictogram %02d" % (symbol+1),Vector3(board_x-.055,y+1.55,board_z-.58+float(symbol)*.58),Vector3(.025,.22,.22),mats.emergency_case if symbol==0 else mats.paper)

func _room(parent: Node3D, title: String, center: Vector3, width: float, depth: float, level: int, interior := "class") -> void:
	var y := float(level) * FLOOR_HEIGHT
	# Shells are open on the courtyard/corridor side. The corridor lies inside the U.
	_box(parent, title + " floor", Vector3(center.x, y + .06, center.z), Vector3(width, .12, depth), mats.tile, true)
	_wall_window_apertures(parent,title+" outer wall",Vector3(center.x,y,center.z-depth*.5),width,y,true)
	_box(parent, title + " west wall", Vector3(center.x-width*.5, y + 1.62, center.z), Vector3(.2, 3.12, depth), mats.wall, true)
	_box(parent, title + " east wall", Vector3(center.x+width*.5, y + 1.62, center.z), Vector3(.2, 3.12, depth), mats.wall, true)
	_box(parent, title + " ceiling", Vector3(center.x,y+3.08,center.z),Vector3(width, .12, depth),mats.concrete,true)
	_room_ceiling_light(parent,title,center,y,interior == "class")
	_box(parent, title + " lower band north", Vector3(center.x, y + .48, center.z-depth*.5+.12), Vector3(width-.2, .82, .08), mats.wall_base_band)
	_box(parent, title + " exterior base band", Vector3(center.x, y + .48, center.z-depth*.5-.12), Vector3(width-.2, .82, .07), mats.wall_base_band)
	# Tall divided windows, darkened for the night palette. Keep the glazing
	# centers identical to the wall apertures so no pier hides a pane.
	var window_centers := _centered_window_centers(center.x, width, maxi(1, int(width / 2.6)))
	for wx in window_centers:
		_box(parent, title + " window glass", Vector3(wx, y+1.92, center.z-depth*.5+.13), Vector3(.95,1.38,.08), mats.glass,true)
		_box(parent, title + " window mullion", Vector3(wx, y+1.92, center.z-depth*.5+.20), Vector3(.045,1.38,.035), mats.wood)
		_box(parent,title+" window head",Vector3(wx,y+2.65,center.z-depth*.5+.13),Vector3(1.12,.08,.16),mats.wood)
		_box(parent,title+" window sill",Vector3(wx,y+1.19,center.z-depth*.5+.13),Vector3(1.12,.08,.16),mats.wood)
		_box(parent,title+" window left stile",Vector3(wx-.54,y+1.92,center.z-depth*.5+.13),Vector3(.08,1.46,.16),mats.wood)
		_box(parent,title+" window right stile",Vector3(wx+.54,y+1.92,center.z-depth*.5+.13),Vector3(.08,1.46,.16),mats.wood)
	# Room-specific furniture silhouettes, kept low-poly and practical.
	match interior:
		"class":
			var board_z := center.z-depth*.5+.18
			var board_width := minf(width*.52,3.2)
			_box(parent,title+" chalkboard",Vector3(center.x,y+1.75,board_z),Vector3(board_width,1.05,.12),mats.chalk)
			_box(parent,title+" chalkboard top frame",Vector3(center.x,y+2.32,board_z+.04),Vector3(board_width+.12,.08,.12),mats.wood)
			_box(parent,title+" chalk tray",Vector3(center.x,y+1.18,board_z+.12),Vector3(board_width+.16,.08,.23),mats.wood)
			_classroom_text(parent,"CHĂM NGOAN  •  HỌC TỐT",Vector3(center.x,y+2.05,board_z+.075),0,16,Color("#c8d0bd"),.007)
			_school_desk(parent,title+" teacher desk",Vector3(center.x,y,center.z-depth*.5+1.25),1.3,.70,.82)
			for row in range(2):
				for col in range(3):
					var p := Vector3(center.x-1.8+float(col)*1.7,y,center.z-depth*.5+2.7+float(row)*1.55)
					_school_desk(parent,title+" student desk",p)
					_school_bench(parent,title+" student bench",p+Vector3(0,0,.70),Vector3(0,0,1))
			# A compact class-duty panel adds a lived-in Vietnamese classroom cue
			# without taking floor area or touching the room shell.
			var class_panel_x := center.x+width*.5-.13
			_box(parent,title+" class duty board",Vector3(class_panel_x,y+1.76,center.z+1.55),Vector3(.06,.92,1.12),mats.band)
			_box(parent,title+" class duty board paper",Vector3(class_panel_x-.04,y+1.76,center.z+1.55),Vector3(.025,.68,.88),mats.paper)
			_classroom_text(parent,"LỊCH TRỰC\nNỀ NẾP LỚP",Vector3(class_panel_x-.06,y+1.76,center.z+1.55),-PI/2.0,14,Color("#34444a"),.006)
			_school_ceiling_fan(parent,title,center,y)
		"library":
			for x in [-1.4, 0.0, 1.4]:
				_box(parent, title + " bookshelf", Vector3(center.x+x,y+1.05,center.z), Vector3(.9,2.0,.35), mats.wood,true)
			for x in [-1.2, 0.0, 1.2]:
				_box(parent, title + " reading table", Vector3(center.x+x,y+.85,center.z+2), Vector3(1.0,.12,.9), mats.wood,true)
		"office":
			_box(parent, title + " work desk", Vector3(center.x,y+.8,center.z), Vector3(1.8,.15,.85), mats.wood,true)
			_box(parent, title + " filing cabinet", Vector3(center.x+width*.32,y+1.0,center.z+1), Vector3(.65,2,.55), mats.metal,true)
			for leg_x in [-.74,.74]:
				for leg_z in [-.30,.30]:
					_box(parent,title+" desk leg",Vector3(center.x+leg_x,y+.40,center.z+leg_z),Vector3(.07,.73,.07),mats.metal)
			if title.begins_with("BẢNG TIN"):
				var notice_z := center.z-depth*.5+.25
				_box(parent,title+" framed bulletin board",Vector3(center.x,y+1.75,notice_z),Vector3(width-.85,1.32,.12),mats.wood)
				_box(parent,title+" felt notice surface",Vector3(center.x,y+1.75,notice_z+.09),Vector3(width-1.02,1.16,.04),mats.chalk)
				_classroom_text(parent,"THÔNG BÁO",Vector3(center.x,y+2.12,notice_z+.13),0,23,Color("#eee0c2"),.007)
				if title == "BẢNG TIN TẦNG 3":
					_scene05_bulletin_board_details(parent, center, y, notice_z)
					_scene06_locker_row(parent, y)
				else:
					for note_index in range(4):
						var note_x := center.x-1.35+float(note_index)*.90
						_box(parent,title+" pinned notice sheet",Vector3(note_x,y+1.58,notice_z+.13),Vector3(.60,.58,.012),mats.paper)
						for line_index in range(3):
							_box(parent,title+" printed notice line",Vector3(note_x,y+1.67-float(line_index)*.12,notice_z+.14),Vector3(.43,.015,.008),mats.band)
				var visitor_bench_x := center.x-width*.31 if title == "BẢNG TIN TẦNG 3" else center.x
				# Keep the Level-3 bench against the west edge, not across the single
				# straight approach from the corridor to the mounted noticeboard.
				_box(parent,title+" visitor bench",Vector3(visitor_bench_x,y+.46,center.z+1.45),Vector3(1.7,.12,.45),mats.wood,true)
			elif title == "PHÒNG GIÁO VIÊN":
				for table_x in [-1.35,1.35]:
					_box(parent,title+" teacher worktable",Vector3(center.x+table_x,y+.80,center.z+1.10),Vector3(1.15,.12,.72),mats.wood,true)
					_box(parent,title+" teacher chair",Vector3(center.x+table_x,y+.46,center.z+2.0),Vector3(.47,.12,.44),mats.wood,true)
					_box(parent,title+" grading folder",Vector3(center.x+table_x-.22,y+.8725,center.z+1.10),Vector3(.42,.025,.32),mats.band)
					_box(parent,title+" marked papers",Vector3(center.x+table_x-.22,y+.891,center.z+1.10),Vector3(.36,.012,.27),mats.paper)
					_visual_cylinder(parent,title+" tea cup",Vector3(center.x+table_x+.31,y+.93,center.z+1.18),.065,.14,mats.porcelain,8)
				for shelf_x in [-1.55,1.55]:
					_box(parent,title+" wall cabinet",Vector3(center.x+shelf_x,y+1.42,center.z-depth*.5+.42),Vector3(.75,1.6,.45),mats.wood,true)
				_box(parent,title+" staff noticeboard",Vector3(center.x,y+1.85,center.z-depth*.5+.14),Vector3(1.65,.90,.08),mats.chalk)
				_classroom_text(parent,"LỊCH HỌP  •  PHÂN CÔNG",Vector3(center.x,y+2.13,center.z-depth*.5+.19),0,13,Color("#d2c8ac"),.006)
				for notice_index in range(3):
					var notice_x := center.x-.48+float(notice_index)*.48
					_box(parent,title+" staff schedule sheet",Vector3(notice_x,y+1.69,center.z-depth*.5+.19),Vector3(.34,.32,.012),mats.paper)
					_box(parent,title+" staff schedule line",Vector3(notice_x,y+1.68,center.z-depth*.5+.20),Vector3(.23,.018,.008),mats.band)
		"lab":
			if title == "THỰC HÀNH HÓA":
				var bench_z := center.z+.55
				for station in range(3):
					var x_offset := -1.35+float(station)*1.35
					var bench_center := Vector3(center.x+x_offset,y,bench_z)
					_supported_worktop(parent,title,"lab bench top","lab bench leg",station+1,bench_center,Vector2(.82,2.15),.90,mats.concrete)
					# Each chemistry station gets its own modest apparatus cluster;
					# the bench tops stay visually separate and the floor remains clear.
					_box(parent,"%s reagent tray@%02d" % [title,station+1],bench_center+Vector3(0,1.00,-.48),Vector3(.55,.045,.34),mats.metal)
					_box(parent,"%s burner base@%02d" % [title,station+1],bench_center+Vector3(0,1.08,.32),Vector3(.16,.07,.16),mats.metal)
					_box(parent,"%s burner stem@%02d" % [title,station+1],bench_center+Vector3(0,1.19,.32),Vector3(.045,.20,.045),mats.metal)
					_box(parent,"%s beaker@%02d" % [title,station+1],bench_center+Vector3(-.20,1.20,.72),Vector3(.14,.38,.14),mats.glass)
					_supported_seat(parent,title,"lab stool",station+1,bench_center+Vector3(.72,0,.05),.40)
				_chemistry_lab_finish(parent,title,center,y)
			else:
				for x in [-1.35,0.0,1.35]:
					_box(parent,title+" lab bench",Vector3(center.x+x,y+.9,center.z+1),Vector3(.8,.18,2.2),mats.concrete,true)
					_box(parent,title+" lab bench support",Vector3(center.x+x,y+.44,center.z+1),Vector3(.10,.76,1.82),mats.metal)
					for vessel_z in [.3,1.4]:
						_box(parent,title+" lab glass vessel",Vector3(center.x+x,y+1.16,center.z+vessel_z),Vector3(.15,.36,.15),mats.glass)
			_box(parent,title+" sink",Vector3(center.x+width*.33,y+.82,center.z-1),Vector3(.7,.12,.7),mats.porcelain)
			_box(parent,title+" sink stand",Vector3(center.x+width*.33,y+.42,center.z-1),Vector3(.62,.72,.62),mats.concrete,true)
			_box(parent,title+" faucet stem",Vector3(center.x+width*.33,y+1.06,center.z-1.24),Vector3(.05,.42,.05),mats.metal)
			_box(parent,title+" chemical cabinet",Vector3(center.x-width*.35,y+1.07,center.z-depth*.5+.48),Vector3(.92,2.0,.60),mats.wood,true)
			_box(parent,title+" reagent wall chart",Vector3(center.x,y+1.86,center.z-depth*.5+.20),Vector3(2.0,1.10,.06),mats.paper)
			for chart_row in range(4):
				_box(parent,title+" chart rule",Vector3(center.x,y+2.13-float(chart_row)*.18,center.z-depth*.5+.24),Vector3(1.6,.035,.01),mats.band)
			if title != "THỰC HÀNH HÓA":
				for stool_x in [-1.35,0.0,1.35]:
					_box(parent,title+" lab stool",Vector3(center.x+stool_x,y+.48,center.z+2.5),Vector3(.38,.10,.38),mats.wood,true)
		"computer":
			for x in [-1.5,0.0,1.5]:
				for z in [-1.0,1.0]:
					_box(parent,title+" computer desk",Vector3(center.x+x,y+.82,center.z+z),Vector3(1.1,.12,.65),mats.wood,true)
					_box(parent,title+" CRT monitor",Vector3(center.x+x,y+1.25,center.z+z-.1),Vector3(.52,.55,.28),mats.metal,true)
		"chess":
			# One centered story table replaces the old pair of empty side boards.
			_box(parent,title+" central chess table",Vector3(center.x,y+.82,center.z),Vector3(1.65,.14,1.65),mats.wood,true)
			# Four visual-only timber legs meet the tabletop underside at y + .75;
			# the existing tabletop collider remains the sole table collision shape.
			for leg_x in [-.68,.68]:
				for leg_z in [-.68,.68]:
					_box(parent,title+" central chess table leg",Vector3(center.x+leg_x,y+.435,center.z+leg_z),Vector3(.14,.63,.14),mats.wood)
			var chess_square_size := .132
			var chess_board_start := -chess_square_size*3.5
			_box(parent,title+" chessboard dark border",Vector3(center.x,y+.906,center.z),Vector3(1.18,.035,1.18),mats.rail)
			for row in range(8):
				for col in range(8):
					var light_tile := ((row+col)%2)==0
					var square_center := Vector3(center.x+chess_board_start+float(col)*chess_square_size,y+.93,center.z+chess_board_start+float(row)*chess_square_size)
					_box(parent,title+" chess square",square_center,Vector3(chess_square_size-.003,.018,chess_square_size-.003),mats.paper if light_tile else mats.wood)
			var back_rank: Array[String] = ["rook","knight","bishop","queen","king","bishop","knight","rook"]
			for side in range(2):
				var is_light := side == 0
				var row_index := 0 if is_light else 7
				var pawn_row := 1 if is_light else 6
				for file in range(8):
					var piece_x := center.x+chess_board_start+float(file)*chess_square_size
					var piece_z := center.z+chess_board_start+float(row_index)*chess_square_size
					_chess_piece_visual(parent,title+" %s %s" % ["ivory" if is_light else "dark",back_rank[file]],Vector3(piece_x,y+.94,piece_z),is_light,back_rank[file])
					var pawn_z := center.z+chess_board_start+float(pawn_row)*chess_square_size
					_chess_piece_visual(parent,title+" %s pawn %02d" % ["ivory" if is_light else "dark",file+1],Vector3(piece_x,y+.94,pawn_z),is_light,"pawn")
			for chair_z in [-1.12,1.12]:
				_box(parent,title+" central chess chair seat",Vector3(center.x,y+.52,center.z+chair_z),Vector3(.54,.12,.48),mats.wood)
				_box(parent,title+" central chess chair back",Vector3(center.x,y+.82,center.z+chair_z+(.22 if chair_z>0 else -.22)),Vector3(.54,.52,.06),mats.wood)
				for leg_x in [-.20,.20]:
					_box(parent,title+" central chess chair leg",Vector3(center.x+leg_x,y+.26,center.z+chair_z),Vector3(.045,.52,.045),mats.metal)
			# Trophy shelf and understated cups turn the west wall into a focal
			# memory wall while leaving the room's approach and table sightline clear.
			var trophy_gold := _mat("Dulled Chess Trophy Brass",Color("#8c7650"),.72)
			var trophy_wall_x := center.x-width*.5+.13
			_box(parent,title+" trophy display backing",Vector3(trophy_wall_x,y+1.92,center.z),Vector3(.06,1.42,2.35),mats.band)
			_box(parent,title+" trophy display title strip",Vector3(trophy_wall_x+.07,y+2.40,center.z),Vector3(.08,.28,2.15),mats.wood)
			_classroom_text(parent,"GIẢI CỜ VUA",Vector3(trophy_wall_x+.14,y+2.40,center.z),PI/2.0,16,Color("#e0d1ae"),.006)
			_box(parent,title+" trophy shelf",Vector3(trophy_wall_x+.25,y+1.22,center.z),Vector3(.48,.09,1.92),mats.wood)
			for trophy in range(3):
				var trophy_z := center.z-.60+float(trophy)*.60
				_box(parent,title+" trophy base %02d" % (trophy+1),Vector3(trophy_wall_x+.20,y+1.30,trophy_z),Vector3(.18,.07,.18),trophy_gold)
				_visual_cylinder(parent,title+" trophy stem %02d" % (trophy+1),Vector3(trophy_wall_x+.20,y+1.45,trophy_z),.035,.24,trophy_gold,6)
				_visual_cylinder(parent,title+" trophy cup %02d" % (trophy+1),Vector3(trophy_wall_x+.20,y+1.61,trophy_z),.095,.12,trophy_gold,6)
		"club":
			var club_board_z := center.z-depth*.5+.18
			_box(parent,title+" activity noticeboard",Vector3(center.x,y+1.78,club_board_z),Vector3(width-1.0,1.22,.10),mats.chalk)
			_box(parent,title+" activity noticeboard frame",Vector3(center.x,y+1.78,club_board_z-.07),Vector3(width-.82,1.38,.08),mats.wood)
			_classroom_text(parent,"SINH HOẠT CÂU LẠC BỘ",Vector3(center.x,y+2.10,club_board_z+.07),0,17,Color("#d2c8ac"),.007)
			for paper_index in range(3):
				var paper_x := center.x-.85+float(paper_index)*.85
				_box(parent,title+" pinned activity notice",Vector3(paper_x,y+1.55,club_board_z+.07),Vector3(.52,.38,.012),mats.paper)
				for club_line_index in range(2):
					_box(parent,title+" activity notice print line",Vector3(paper_x,y+1.58-float(club_line_index)*.12,club_board_z+.081),Vector3(.36,.014,.008),mats.band)
			_box(parent,title+" shared activity table",Vector3(center.x,y+.81,center.z+1.10),Vector3(1.65,.12,.82),mats.wood,true)
			# A modest register, paper stack, and pencil cup make the shared club
			# table feel used without filling the room's approach aisle.
			_box(parent,title+" activity register",Vector3(center.x-.34,y+.8825,center.z+1.08),Vector3(.48,.025,.34),mats.paper)
			_box(parent,title+" club folder",Vector3(center.x+.30,y+.8925,center.z+1.12),Vector3(.38,.045,.28),mats.band)
			_box(parent,title+" loose activity sheet",Vector3(center.x-.34,y+.901,center.z+1.08),Vector3(.38,.012,.27),mats.paper)
			_visual_cylinder(parent,title+" pencil cup",Vector3(center.x+.60,y+.95,center.z+1.22),.075,.16,mats.metal,8)
			for seat_side in [-1.0,1.0]:
				_box(parent,title+" shared activity chair",Vector3(center.x+seat_side*1.18,y+.46,center.z+1.10),Vector3(.43,.12,.43),mats.wood,true)
				_box(parent,title+" shared activity chair back",Vector3(center.x+seat_side*1.42,y+.74,center.z+1.10),Vector3(.06,.54,.43),mats.wood)
		"music":
			_box(parent,title+" piano",Vector3(center.x,y+.75,center.z),Vector3(1.8,1.3,.8),mats.wood,true)
			_box(parent,title+" practice bench",Vector3(center.x,y+.55,center.z+1.2),Vector3(1.5,.12,.4),mats.wood,true)
		"storage":
			for x in [-width*.32,0.0,width*.32]:
				_box(parent,title+" steel storage shelf",Vector3(center.x+x,y+1.25,center.z),Vector3(.45,2.4,2.2),mats.metal,true)
				for shelf in range(3):
					_box(parent,title+" storage shelf",Vector3(center.x+x,y+.55+float(shelf)*.65,center.z),Vector3(.55,.08,2.35),mats.wood)
		"restroom":
			_box(parent,title+" mirror",Vector3(center.x-width*.25,y+1.7,center.z-depth*.5+.48),Vector3(2.0,1.0,.06),mats.glass)
			for i in range(3):
				var cx := center.x-width*.28+float(i)*width*.28
				_box(parent,title+" sink",Vector3(cx,y+.85,center.z-depth*.5+1.2),Vector3(.65,.16,.42),mats.porcelain)
				# Dividers belong between stalls in the north half; a centerline
				# partition extending to the south doorway trapped the capsule.
				if i < 2:
					var divider_x := cx+width*.14
					_box(parent,title+" cubicle divider",Vector3(divider_x,y+1.2,center.z-depth*.16),Vector3(.08,2.2,depth*.44),mats.band,true)
				_box(parent,title+" toilet",Vector3(cx,y+.45,center.z+depth*.32),Vector3(.45,.55,.55),mats.porcelain,true)
	# Corridor-facing wall segments meet the side walls exactly. The old
	# centre/length arithmetic overshot narrow rooms and left a 3.75 m gap
	# around a 1.5 m doorway.
	var inner_z := center.z+depth*.5
	var door_half_width := .75
	var west_edge := center.x-width*.5
	var east_edge := center.x+width*.5
	var west_span := center.x-door_half_width-west_edge
	var east_span := east_edge-(center.x+door_half_width)
	_box(parent,title+" inner wall west",Vector3(west_edge+west_span*.5,y+1.55,inner_z),Vector3(west_span,3.0,.2),mats.wall,true)
	_box(parent,title+" inner wall east",Vector3(center.x+door_half_width+east_span*.5,y+1.55,inner_z),Vector3(east_span,3.0,.2),mats.wall,true)
	_box(parent,title+" doorway lintel",Vector3(center.x,y+2.55,inner_z),Vector3(1.45,.3,.18),mats.wood)
	_box(parent,title+" door west jamb",Vector3(center.x-.76,y+1.15,inner_z),Vector3(.12,2.3,.18),mats.wood)
	_box(parent,title+" door east jamb",Vector3(center.x+.76,y+1.15,inner_z),Vector3(.12,2.3,.18),mats.wood)
	# Swing the decorative leaf north into the room from its west jamb. Keep the
	# existing opening, jambs, lintel, and collision-free route unchanged.
	var door_hinge := Node3D.new()
	door_hinge.name = title + " door hinge pivot"
	door_hinge.position = Vector3(center.x-door_half_width+.06,y+1.15,inner_z-.12)
	door_hinge.rotation.y = PI / 2.0
	parent.add_child(door_hinge)
	_box(door_hinge,title+" wooden door leaf",Vector3(.41,0,0),Vector3(.82,2.25,.12),mats.wood)
	_box(door_hinge,title+" frosted door glass",Vector3(.41,.67,.05),Vector3(.56,.7,.025),mats.glass)
	_box(door_hinge,title+" door glass center mullion",Vector3(.41,.67,.068),Vector3(.035,.7,.025),mats.wood)
	for pane_y in [.32,.67,1.02]:
		_box(door_hinge,title+" door glass crossbar",Vector3(.41,pane_y,.068),Vector3(.56,.035,.025),mats.wood)
	_label(parent,title,Vector3(center.x,y+2.85,inner_z+.06),0.0,22)
	_room_shell_edge_details(parent,title,center,width,depth,y,true,1.0,center.x,door_half_width*2.0)

func _classroom_one_detail(parent: Node3D, center: Vector3, y: float) -> void:
	# Ground-floor room 1 is the small, four-metre east-wing classroom from the
	# plan. Give this single room a complete Vietnamese classroom read while
	# keeping its existing doorway, shell, and player route unchanged.
	_room_ceiling_fixture(parent,"LỚP HỌC 1",center,y)
	var board_x := center.x + 1.78
	_box(parent,"LỚP HỌC 1 chalkboard",Vector3(board_x,y+1.82,center.z),Vector3(.08,1.2,2.75),mats.chalk)
	_box(parent,"LỚP HỌC 1 chalkboard top frame",Vector3(board_x-.06,y+2.45,center.z),Vector3(.12,.09,2.9),mats.wood)
	_box(parent,"LỚP HỌC 1 chalkboard bottom frame",Vector3(board_x-.06,y+1.18,center.z),Vector3(.12,.09,2.9),mats.wood)
	_box(parent,"LỚP HỌC 1 chalk tray",Vector3(board_x-.12,y+1.11,center.z),Vector3(.22,.08,2.9),mats.wood)
	_classroom_text(parent,"DẠY TỐT - HỌC TỐT",Vector3(board_x-.11,y+2.58,center.z),-PI/2.0,17,Color("#d6c7a4"),.01)
	# Authored Blender furniture replaces the earlier procedural visual blockout.
	# Keep broad, deliberate body colliders in the Godot scene rather than
	# generating a separate physics body for every decorative mesh part.
	var furniture_scene := load("res://assets/props/school/classroom1_furniture.glb") as PackedScene
	if furniture_scene != null:
		var furniture := furniture_scene.instantiate() as Node3D
		furniture.name = "Classroom 1 authored furniture"
		furniture.position = Vector3(center.x,y+.06,center.z)
		# This Blender-authored GLB was built with Godot Y-up coordinates even
		# though Blender's scene is Z-up. Rotate the imported root so desk tops
		# lie flat and the fan/legs stand along world Y instead of going below floor.
		furniture.rotation.x = PI * .5
		parent.add_child(furniture)
		for row in range(3):
			var row_z := center.z - 1.75 + float(row) * 1.72
			_classroom_prop_collision(parent,"Student desk %d" % (row+1),Vector3(center.x-.36,y+.45,row_z),Vector3(.88,.9,1.08))
			_classroom_prop_collision(parent,"Student bench %d" % (row+1),Vector3(center.x-1.12,y+.45,row_z),Vector3(.72,.9,.98))
		# The existing authored set has three rows. Add matching low-poly pairs
		# at the two ends of this deeper, still-recessed classroom so the added
		# floor area reads as usable seating rather than an empty extension.
		for end_row in range(2):
			var extension_z := center.z+(-3.35 if end_row == 0 else 3.35)
			var extension_desk := Vector3(center.x-.36,y,extension_z)
			_school_desk(parent,"LỚP HỌC 1 extension student desk %d" % (end_row+1),extension_desk)
			_school_bench(parent,"LỚP HỌC 1 extension shared bench %d" % (end_row+1),extension_desk+Vector3(-.76,0,0),Vector3(-1,0,0))
		_classroom_prop_collision(parent,"Teacher desk",Vector3(center.x+1.08,y+.43,center.z),Vector3(.98,.86,1.18))
		_classroom_prop_collision(parent,"Class cabinet",Vector3(center.x+1.35,y+.88,center.z-2.48),Vector3(.84,1.8,.62))
		_light(parent,Vector3(center.x,y+2.72,center.z),Color("#b9d7e5"),3.0,6.0)
		var clock := MeshInstance3D.new()
		clock.name = "LỚP HỌC 1 wall clock"
		var clock_face := CylinderMesh.new()
		clock_face.top_radius = .22
		clock_face.bottom_radius = .22
		clock_face.height = .035
		clock.mesh = clock_face
		clock.material_override = mats.paper
		clock.position = Vector3(center.x-.02,y+2.52,center.z-2.78)
		clock.rotation.x = PI/2.0
		parent.add_child(clock)
		return
	# One teacher station and five compact two-seat rows face the side-wall board.
	var teacher_x := center.x + 1.08
	_box(parent,"LỚP HỌC 1 teacher desk top",Vector3(teacher_x,y+.82,center.z),Vector3(.85,.12,1.05),mats.wood,true)
	_box(parent,"LỚP HỌC 1 teacher desk modesty panel",Vector3(teacher_x,y+.47,center.z),Vector3(.72,.58,.08),mats.wood,true)
	_box(parent,"LỚP HỌC 1 teacher desk front edge",Vector3(teacher_x,y+.88,center.z+.49),Vector3(.81,.035,.045),mats.band)
	for leg_x in [-.34,.34]:
		for leg_z in [-.43,.43]:
			_box(parent,"LỚP HỌC 1 teacher desk leg",Vector3(teacher_x+leg_x,y+.40,center.z+leg_z),Vector3(.055,.76,.055),mats.metal,true)
	_box(parent,"LỚP HỌC 1 teacher drawer",Vector3(teacher_x,y+.65,center.z-.31),Vector3(.56,.22,.42),mats.wood,true)
	_box(parent,"LỚP HỌC 1 teacher drawer pull",Vector3(teacher_x,y+.66,center.z-.09),Vector3(.16,.035,.025),mats.metal)
	for row in range(5):
		var z := center.z - 3.35 + float(row) * 1.675
		var desk_x := center.x - .36
		_box(parent,"LỚP HỌC 1 student desk %d top" % row,Vector3(desk_x,y+.78,z),Vector3(.78,.11,1.0),mats.wood,true)
		_box(parent,"LỚP HỌC 1 student desk %d front lip" % row,Vector3(desk_x,y+.84,z+.48),Vector3(.76,.045,.045),mats.band)
		for leg_z in [-.39,.39]:
			_box(parent,"LỚP HỌC 1 student desk %d steel leg" % row,Vector3(desk_x,y+.39,z+leg_z),Vector3(.06,.72,.06),mats.metal,true)
			_box(parent,"LỚP HỌC 1 desk %d crossbar" % row,Vector3(desk_x,y+.24,z+leg_z),Vector3(.72,.045,.045),mats.metal,true)
		var bench_x := center.x - 1.12
		_box(parent,"LỚP HỌC 1 shared bench %d seat" % row,Vector3(bench_x,y+.48,z),Vector3(.46,.09,.88),mats.wood,true)
		_box(parent,"LỚP HỌC 1 shared bench %d back" % row,Vector3(bench_x,y+.83,z),Vector3(.08,.58,.88),mats.wood,true)
		for bench_z in [-.34,.34]:
			_box(parent,"LỚP HỌC 1 bench %d metal leg" % row,Vector3(bench_x,y+.24,z+bench_z),Vector3(.055,.48,.055),mats.metal,true)
		_box(parent,"LỚP HỌC 1 bench %d lower brace" % row,Vector3(bench_x,y+.20,z),Vector3(.045,.04,.68),mats.metal,true)
	# A compact steel-and-wood class cabinet fits the north corner without narrowing
	# the door approach or the intended aisle between the student rows.
	var cabinet_x := center.x + 1.35
	var cabinet_z := center.z - 2.48
	_box(parent,"LỚP HỌC 1 class cabinet body",Vector3(cabinet_x,y+.88,cabinet_z),Vector3(.76,1.76,.52),mats.wood,true)
	_box(parent,"LỚP HỌC 1 class cabinet left stile",Vector3(cabinet_x-.34,y+.88,cabinet_z+.275),Vector3(.06,1.66,.035),mats.metal)
	_box(parent,"LỚP HỌC 1 class cabinet right stile",Vector3(cabinet_x+.34,y+.88,cabinet_z+.275),Vector3(.06,1.66,.035),mats.metal)
	_box(parent,"LỚP HỌC 1 class cabinet shelf",Vector3(cabinet_x,y+.90,cabinet_z),Vector3(.70,.05,.48),mats.metal)
	_box(parent,"LỚP HỌC 1 class cabinet handle",Vector3(cabinet_x+.22,y+.90,cabinet_z+.31),Vector3(.035,.20,.035),mats.metal)
	# Period-appropriate chalk notes and a wall clock add scale without noisy props.
	_classroom_text(parent,"BÀI HỌC\nGHI NHỚ\nLUYỆN TẬP",Vector3(board_x-.11,y+1.96,center.z-.72),-PI/2.0,17,Color("#c7cebd"),.009)
	var clock := MeshInstance3D.new()
	clock.name = "LỚP HỌC 1 wall clock"
	var face := CylinderMesh.new()
	face.top_radius = .22
	face.bottom_radius = .22
	face.height = .035
	clock.mesh = face
	clock.material_override = mats.paper
	clock.position = Vector3(center.x-.02,y+2.52,center.z-2.78)
	clock.rotation.x = PI/2.0
	parent.add_child(clock)
	var clock_rim := MeshInstance3D.new()
	var rim := TorusMesh.new()
	rim.inner_radius = .205
	rim.outer_radius = .235
	clock_rim.mesh = rim
	clock_rim.material_override = mats.wood
	clock_rim.position = clock.position + Vector3(0,0,.025)
	clock_rim.rotation.x = PI/2.0
	parent.add_child(clock_rim)
	var minute_hand := _box(parent,"LỚP HỌC 1 clock minute hand",Vector3(center.x-.02,y+2.56,center.z-2.745),Vector3(.018,.15,.018),mats.metal)
	minute_hand.rotation.z = deg_to_rad(8.0)
	var hour_hand := _box(parent,"LỚP HỌC 1 clock hour hand",Vector3(center.x+.015,y+2.49,center.z-2.744),Vector3(.018,.105,.018),mats.metal)
	hour_hand.rotation.z = deg_to_rad(-52.0)
	_light(parent,Vector3(center.x,y+2.72,center.z),Color("#b9d7e5"),3.0,6.0)
	# Period-appropriate three-blade ceiling fan; the motor and blades stay above
	# the player capsule while remaining part of the real room geometry.
	var fan := Node3D.new()
	fan.name = "LỚP HỌC 1 ceiling fan"
	fan.position = Vector3(center.x-.75,y+2.73,center.z-.4)
	parent.add_child(fan)
	var hub := MeshInstance3D.new()
	hub.name = "Fan motor housing"
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = .09
	hub_mesh.bottom_radius = .13
	hub_mesh.height = .18
	hub.mesh = hub_mesh
	hub.material_override = mats.metal
	fan.add_child(hub)
	_box(fan,"Fan downrod",Vector3(0,.12,0),Vector3(.035,.22,.035),mats.metal)
	for blade_index in range(3):
		var blade := _box(fan,"Fan blade %d" % blade_index,Vector3(0,0,-.53),Vector3(.17,.035,.92),mats.wood)
		blade.rotation.y = TAU * float(blade_index) / 3.0
		var blade_trim := _box(fan,"Fan blade trim %d" % blade_index,Vector3(0,.022,-.53),Vector3(.045,.012,.76),mats.band)
		blade_trim.rotation.y = blade.rotation.y

func _classroom_prop_collision(parent: Node3D, label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "LỚP HỌC 1 " + label + " collision"
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)

func _classroom_text(parent: Node3D, text: String, at: Vector3, facing: float, size: int, color: Color, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 1
	label.outline_modulate = Color("#17201d")
	label.position = at
	label.rotation.y = facing
	parent.add_child(label)

func _scene05_bulletin_board_details(parent: Node3D, center: Vector3, y: float, board_z: float) -> void:
	# These are tangible, mounted notice-board pieces in the mapped bay. They
	# supplement the existing timber frame and felt panel rather than acting as
	# a trigger-only substitute for the board.
	var face_z := board_z + .145
	var paper_tone: Material = mats.paper
	var ink: Material = mats.band
	var cards := [
		{"name": "Certificate", "x": center.x - 1.42, "w": .76, "h": .72, "title": "GIẤY KHEN\nHỌC TỐT"},
		{"name": "School activity photo", "x": center.x - .48, "w": .78, "h": .72, "title": "ẢNH HOẠT ĐỘNG\nTRƯỜNG"},
		{"name": "Blackened An chess photo", "x": center.x + .48, "w": .82, "h": .78, "title": "GIẢI CỜ VUA\n18/04"},
		{"name": "Club notice", "x": center.x + 1.42, "w": .76, "h": .72, "title": "CÂU LẠC BỘ\nCỜ VUA"},
	]
	for card in cards:
		var card_name: String = card["name"]
		var card_x: float = card["x"]
		var card_width: float = card["w"]
		var card_height: float = card["h"]
		var card_y := y + 1.65
		_box(parent, "Scene05 " + card_name + " aged paper", Vector3(card_x, card_y, face_z), Vector3(card_width, card_height, .025), paper_tone)
		var text_color := Color("#253239")
		_classroom_text(parent, str(card["title"]), Vector3(card_x, card_y + .12, face_z + .016), 0, 8, text_color, .0048)
		for line_index in range(2):
			_box(parent, "Scene05 " + card_name + " printed line", Vector3(card_x, card_y - .16 - float(line_index) * .13, face_z + .018), Vector3(card_width * .66, .012, .006), ink)
		var pin := SphereMesh.new()
		pin.radius = .035
		pin.height = .07
		var pin_node := MeshInstance3D.new()
		pin_node.name = "Scene05 " + card_name + " brass thumbtack"
		pin_node.mesh = pin
		pin_node.material_override = _mat("Old brass thumbtack", Color("#8b6e43"), .5)
		pin_node.position = Vector3(card_x - card_width * .36, card_y + card_height * .38, face_z + .045)
		parent.add_child(pin_node)
	# Ink has been aggressively dragged across the face in the championship
	# photograph; the cover-up is visible at a distance but the close inspection
	# owns the canon identity reveal.
	_box(parent, "Scene05 black marker over girl's face", Vector3(center.x + .48, y + 1.78, face_z + .035), Vector3(.36, .17, .012), _mat("Blackened photo ink", Color("#111315"), .94))
	_box(parent, "Scene05 achievement list strip", Vector3(center.x, y + 1.35, face_z), Vector3(3.45, .16, .018), paper_tone)
	_classroom_text(parent, "THÀNH TÍCH HỌC SINH  •  THÔNG BÁO ĐOÀN TRƯỜNG", Vector3(center.x, y + 1.35, face_z + .012), 0, 7, Color("#313c3d"), .0045)
	# Slightly lifted, curled-looking corners make the pinned sheets read as old
	# paper rather than a uniform set of floating rectangles.
	for corner in [Vector2(-1.78, 1.30), Vector2(1.78, 1.30), Vector2(-1.78, 1.98), Vector2(1.78, 1.98)]:
		_box(parent, "Scene05 lifted paper edge", Vector3(center.x + corner.x, y + corner.y, face_z + .025), Vector3(.10, .035, .02), _mat("Aged paper edge", Color("#81765e")))

func _scene06_locker_row(parent: Node3D, y: float) -> void:
	# Provisional position inside the already-mapped notice-board bay. The row
	# sits at the east wall edge with its fronts toward the clear west-side aisle;
	# the room shell and route stay untouched.
	var locker_centers: Array[Vector3] = [Vector3(-15.10, y, -28.10), Vector3(-15.10, y, -27.05), Vector3(-15.10, y, -26.00)]
	var codes: Array[String] = ["A-16", "A-17", "A-18"]
	for index in range(locker_centers.size()):
		var center: Vector3 = locker_centers[index]
		var code: String = codes[index]
		var z: float = center.z
		# Build an actual hollow cabinet carcass so the open door exposes its
		# shelf and diary rather than hiding them behind a solid box.
		_box(parent, "Scene06 locker %s back" % code, Vector3(-14.83, y + 1.08, z), Vector3(.06, 2.16, .90), mats.metal, true)
		_box(parent, "Scene06 locker %s west stile" % code, Vector3(-15.10, y + 1.08, z - .43), Vector3(.54, 2.16, .06), mats.metal, true)
		_box(parent, "Scene06 locker %s east stile" % code, Vector3(-15.10, y + 1.08, z + .43), Vector3(.54, 2.16, .06), mats.metal, true)
		_box(parent, "Scene06 locker %s top" % code, Vector3(-15.10, y + 2.13, z), Vector3(.54, .07, .90), mats.metal, true)
		_box(parent, "Scene06 locker %s base" % code, Vector3(-15.10, y + .06, z), Vector3(.54, .07, .90), mats.metal, true)
		if code != "A-17":
			_box(parent, "Scene06 locker %s recessed door panel" % code, Vector3(-15.405, y + 1.10, z), Vector3(.025, 1.98, .80), mats.wood)
			_box(parent, "Scene06 locker %s door scratch 01" % code, Vector3(-15.423, y + 1.34, z - .22), Vector3(.012, .38, .018), mats.metal)
			_box(parent, "Scene06 locker %s door scratch 02" % code, Vector3(-15.423, y + 1.52, z - .18), Vector3(.012, .23, .014), mats.metal)
			_box(parent, "Scene06 locker %s code plate" % code, Vector3(-15.435, y + 1.91, z), Vector3(.018, .19, .38), mats.paper)
			_classroom_text(parent, code, Vector3(-15.449, y + 1.91, z), -PI * .5, 11, Color("#18242b"), .0048)
			_box(parent, "Scene06 locker %s handle" % code, Vector3(-15.446, y + 1.08, z + .27), Vector3(.035, .20, .045), mats.warm)
		for hinge_y in [y + .28, y + 1.91]:
			_box(parent, "Scene06 locker %s hinge" % code, Vector3(-15.44, hinge_y, z - .35), Vector3(.045, .16, .07), mats.warm)
		_box(parent, "Scene06 locker %s inner shelf" % code, Vector3(-14.99, y + .72, z), Vector3(.40, .045, .76), mats.metal)
		_box(parent, "Scene06 locker %s books" % code, Vector3(-15.05, y + .93, z - .10), Vector3(.20, .36, .42), mats.book)
		if code != "A-17":
			continue
		var door_pivot := Node3D.new()
		door_pivot.name = "A17LockerDoorPivot"
		door_pivot.position = Vector3(-15.42, y + 1.10, z)
		parent.add_child(door_pivot)
		var door_mesh := MeshInstance3D.new()
		door_mesh.name = "A17LockerOpenableDoor"
		var door_box := BoxMesh.new()
		door_box.size = Vector3(.035, 1.98, .80)
		door_mesh.mesh = door_box
		door_mesh.material_override = mats.metal
		door_mesh.position = Vector3(0, 0, 0)
		door_pivot.add_child(door_mesh)
		_box(door_pivot, "A17 door scratch 01", Vector3(-.022, .23, -.22), Vector3(.009, .40, .018), _mat("A-17 exposed metal scratch", Color("#b5ada0"), .78))
		_box(door_pivot, "A17 door scratch 02", Vector3(-.024, .41, -.18), Vector3(.009, .24, .014), _mat("A-17 second exposed metal scratch", Color("#c4b9a5"), .74))
		_box(door_pivot, "A17 handle", Vector3(-.03,-.02,.27), Vector3(.06,.20,.045), mats.warm)
		_box(door_pivot, "A17 code plate", Vector3(-.022,.81,0), Vector3(.02,.19,.38), mats.paper)
		var a17_label := Label3D.new()
		a17_label.name = "A17 visible code"
		a17_label.text = "A-17"
		a17_label.font_size = 11
		a17_label.pixel_size = .0048
		a17_label.modulate = Color("#18242b")
		a17_label.position = Vector3(-.035,.81,0)
		a17_label.rotation.y = -PI * .5
		door_pivot.add_child(a17_label)
		var door_body := StaticBody3D.new()
		door_body.name = "DoorCollision"
		var door_shape := CollisionShape3D.new()
		var door_collision := BoxShape3D.new()
		door_collision.size = door_box.size
		door_shape.shape = door_collision
		door_body.add_child(door_shape)
		door_pivot.add_child(door_body)
		var contents := Node3D.new()
		contents.name = "A17DiaryContents"
		contents.position = Vector3(-15.17, y + .38, z)
		contents.visible = false
		parent.add_child(contents)
		_box(contents, "A17 school notebooks", Vector3(-.05,.45,0), Vector3(.20,.48,.52), mats.book)
		_box(contents, "A17 pencil case", Vector3(-.03,.30,.24), Vector3(.23,.08,.26), mats.banner)
		_box(contents, "A17 torn diary", Vector3(-.05,1.10,-.02), Vector3(.24,.36,.48), mats.wood)
		for fragment_index in range(6):
			var fragment := _box(contents, "A17 diary paper fragment %02d" % (fragment_index + 1), Vector3(-.015,1.34,float(fragment_index - 2) * .105), Vector3(.20,.012,.085), mats.paper)
			fragment.rotation.x = .025 * float(fragment_index - 2)
		var test_paper := _box(contents, "A17 100 over 100 math test reward", Vector3(-.01,1.64,.03), Vector3(.23,.012,.31), mats.paper)
		test_paper.visible = false
		var test_grade := Label3D.new()
		test_grade.name = "A17 Math test 100 over 100 marking"
		test_grade.text = "100/100"
		test_grade.font_size = 13
		test_grade.pixel_size = .004
		test_grade.modulate = Color("#573f2d")
		test_grade.position = Vector3(-.025,1.65,.03)
		test_grade.rotation.y = -PI * .5
		test_grade.visible = false
		contents.add_child(test_grade)

func _mens_restroom_finish(parent: Node3D, title: String, center: Vector3, width: float, depth: float, floor_y: float, outer_sign: float) -> void:
	var south_wall_z := center.z+depth*.5
	var sink_z := south_wall_z-.32
	var sink_xs: Array[float] = [center.x-width*.28,center.x-width*.08]
	var basin_scene := load("res://assets/props/school/restroom_wall_basin_faucet.glb") as PackedScene
	for sink_index in range(sink_xs.size()):
		var sink_x := sink_xs[sink_index]
		if basin_scene != null:
			var basin := basin_scene.instantiate() as Node3D
			basin.name = title+" authored wall basin and faucet %02d" % (sink_index+1)
			basin.position = Vector3(sink_x,floor_y,sink_z)
			# The asset's faucet points toward local +Z; the south wall is behind it.
			basin.rotation.y = PI
			parent.add_child(basin)
		var mirror_x := sink_x
		var mirror_z := south_wall_z-.11
		_box(parent,title+" mirror %02d" % (sink_index+1),Vector3(mirror_x,floor_y+1.56,mirror_z),Vector3(1.28,.78,.05),mats.glass)
		_box(parent,title+" mirror top frame %02d" % (sink_index+1),Vector3(mirror_x,floor_y+1.97,south_wall_z-.15),Vector3(1.36,.06,.045),mats.wood)
		_box(parent,title+" mirror bottom frame %02d" % (sink_index+1),Vector3(mirror_x,floor_y+1.15,south_wall_z-.15),Vector3(1.36,.06,.045),mats.wood)
	# One continuous, counter-mounted twin vanity replaces the standalone basin
	# pedestals. The top is a single mesh surface with fitted rectangular cutouts;
	# the authored oval bowls sit 3 cm proud of it at their 0.87 m rim height.
	var sink_center_z := sink_z
	var counter_left := sink_xs[0]-.56
	var counter_right := sink_xs[1]+.56
	var counter_front := sink_center_z-.40
	var counter_back := south_wall_z-.12
	var top_y := floor_y+.84
	var hole_half_x := .42
	var hole_front := sink_center_z-.29
	var hole_back := minf(sink_center_z+.29,counter_back)
	var x_bounds: Array[float] = [counter_left,sink_xs[0]-hole_half_x,sink_xs[0]+hole_half_x,sink_xs[1]-hole_half_x,sink_xs[1]+hole_half_x,counter_right]
	var z_bounds: Array[float] = [counter_front,hole_front,hole_back,counter_back]
	var top_vertices := PackedVector3Array()
	var top_normals := PackedVector3Array()
	for x_index in range(x_bounds.size()-1):
		for z_index in range(z_bounds.size()-1):
			var over_basin_cutout := z_index == 1 and x_index in [1,3]
			if over_basin_cutout:
				continue
			var x0: float = x_bounds[x_index]
			var x1: float = x_bounds[x_index+1]
			var z0: float = z_bounds[z_index]
			var z1: float = z_bounds[z_index+1]
			var a := Vector3(x0,top_y,z0)
			var b := Vector3(x0,top_y,z1)
			var c := Vector3(x1,top_y,z1)
			var d := Vector3(x1,top_y,z0)
			for point in [a,b,c,a,c,d]:
				top_vertices.append(point)
				top_normals.append(Vector3.UP)
	var top_arrays: Array = []
	top_arrays.resize(Mesh.ARRAY_MAX)
	top_arrays[Mesh.ARRAY_VERTEX] = top_vertices
	top_arrays[Mesh.ARRAY_NORMAL] = top_normals
	var top_mesh := ArrayMesh.new()
	top_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,top_arrays)
	var vanity_stone := _textured_mat("Worn WC vanity stone",Color("#59615f"),"res://assets/materials/school/old_plaster.png",.9,.8)
	top_mesh.surface_set_material(0,vanity_stone)
	var vanity_top := MeshInstance3D.new()
	vanity_top.name = title+" continuous twin basin vanity top"
	vanity_top.mesh = top_mesh
	parent.add_child(vanity_top)
	var vanity_width := counter_right-counter_left
	_box(parent,title+" continuous vanity apron",Vector3((counter_left+counter_right)*.5,floor_y+.53,counter_front+.035),Vector3(vanity_width,.58,.10),mats.band)
	for basin_index in range(sink_xs.size()):
		var door_x := sink_xs[basin_index]
		_box(parent,title+" vanity cabinet door %02d" % (basin_index+1),Vector3(door_x,floor_y+.52,counter_front-.025),Vector3(1.12,.43,.035),mats.wood)
		_box(parent,title+" vanity cabinet pull %02d" % (basin_index+1),Vector3(door_x,floor_y+.52,counter_front-.055),Vector3(.14,.025,.025),mats.metal)
	# Keep both collidable cubicles in the north-west corner, with dividers running
	# along z. From the west doorway the panels read edge-on, leaving the east-wall
	# urinals and the central entry aisle unobstructed.
	var stall_west_x := center.x-width*.5+.10
	var stall_east_x := center.x-width*.5+2.40
	var stall_span_x := stall_east_x-stall_west_x
	var stall_mid_x := (stall_east_x+stall_west_x)*.5
	var shared_partition_z := center.z-depth*.5+1.0
	# One continuous, collidable divider separates the two cubicles and joins the
	# inner face of the west room wall to the east-side door jamb line.
	_box(parent,title+" shared cubicle partition",Vector3(stall_mid_x,floor_y+.95,shared_partition_z),Vector3(stall_span_x,1.90,.10),mats.band,true)
	_box(parent,title+" shared cubicle partition cap",Vector3(stall_mid_x,floor_y+1.92,shared_partition_z),Vector3(stall_span_x+.04,.06,.13),mats.wood)
	# The second cubicle previously read as open at its south end. Close only its
	# z=0 boundary: this segment meets the west wall and the second door jamb,
	# while keeping the east-facing entrance itself clear.
	var second_stall_south_z := center.z-depth*.5+2.0
	_box(parent,title+" second cubicle south end partition",Vector3(stall_mid_x,floor_y+.95,second_stall_south_z),Vector3(stall_span_x,1.90,.10),mats.band,true)
	_box(parent,title+" second cubicle south end partition cap",Vector3(stall_mid_x,floor_y+1.92,second_stall_south_z),Vector3(stall_span_x+.04,.06,.13),mats.wood)
	var stall_z_centers: Array[float] = [center.z-depth*.5+.50,center.z-depth*.5+1.50]
	var toilet_scene := load("res://assets/props/school/restroom_toilet_cistern.glb") as PackedScene
	for stall in range(stall_z_centers.size()):
		var stall_z := stall_z_centers[stall]
		var toilet_x := stall_west_x+.70
		if toilet_scene != null:
			var toilet := toilet_scene.instantiate() as Node3D
			toilet.name = title+" authored toilet cistern %02d" % (stall+1)
			toilet.position = Vector3(toilet_x,floor_y,stall_z)
			# The model's bowl faces +Z. Turn it toward the east-facing stall door.
			toilet.rotation.y = PI*.5
			parent.add_child(toilet)
		var toilet_body := StaticBody3D.new()
		toilet_body.name = title+" toilet %02dBody" % (stall+1)
		toilet_body.position = Vector3(toilet_x,floor_y,stall_z)
		toilet_body.rotation.y = PI*.5
		var toilet_shape := CollisionShape3D.new()
		var toilet_box := BoxShape3D.new()
		toilet_box.size = Vector3(.62,.54,.72)
		toilet_shape.position.y = .34
		toilet_shape.shape = toilet_box
		toilet_body.add_child(toilet_shape)
		parent.add_child(toilet_body)
		# The one-metre entrance leaf seals the complete stall opening when shut,
		# then swings into the shared aisle around its jamb when opened.
		var door_pivot := Node3D.new()
		door_pivot.name = title+" stall door pivot %02d" % (stall+1)
		door_pivot.position = Vector3(stall_east_x,floor_y+.08,stall_z-.50)
		parent.add_child(door_pivot)
		_box(door_pivot,title+" enclosed stall door %02d" % (stall+1),Vector3(0,.68,.50),Vector3(.055,1.32,1.04),mats.band)
		_box(door_pivot,title+" stall door pull %02d" % (stall+1),Vector3(.035,.70,.84),Vector3(.045,.16,.035),mats.metal)
		var door_body := StaticBody3D.new()
		door_body.name = title+" stall door pivot %02dBody" % (stall+1)
		var door_shape := CollisionShape3D.new()
		door_shape.name = "Door leaf blocker"
		var door_box := BoxShape3D.new()
		door_box.size = Vector3(.055,1.32,1.04)
		door_shape.position = Vector3(0,.68,.50)
		door_shape.shape = door_box
		door_body.add_child(door_shape)
		door_pivot.add_child(door_body)
	# The east exterior wall has one north-end window bay and two solid fixture
	# spans opposite the entry. Their bowls project west into the room.
	var urinal_wall_x := center.x+outer_sign*width*.5
	var urinal_x := urinal_wall_x-outer_sign*.31
	var restroom_gold := _mat("Aged Restroom Brass",Color("#81765b"),.74)
	var urinal_scene := load("res://assets/props/school/restroom_wall_urinal.glb") as PackedScene
	for urinal in range(2):
		var urinal_z := center.z-.65 if urinal == 0 else center.z+.65
		if urinal_scene != null:
			var fixture := urinal_scene.instantiate() as Node3D
			fixture.name = title+" authored wall urinal %02d" % (urinal+1)
			fixture.position = Vector3(urinal_x,floor_y,urinal_z)
			fixture.rotation.y = -PI*.5
			parent.add_child(fixture)
	# The far-wall plaque identifies the fixture group; the south wall notice sits
	# above the mirrors, across the clear central entry aisle from the stalls.
	_box(parent,title+" men's room identity plaque",Vector3(urinal_wall_x-outer_sign*.12,floor_y+2.55,center.z+1.70),Vector3(.06,.54,1.4),mats.band)
	_classroom_text(parent,"WC NAM",Vector3(urinal_wall_x-outer_sign*.17,floor_y+2.55,center.z+1.70),-PI/2.0,18,Color("#e0d8c3"),.007)
	var notice_x := center.x
	var notice_z := south_wall_z-.12
	_box(parent,title+" handwashing notice",Vector3(notice_x,floor_y+2.60,notice_z),Vector3(3.0,.52,.06),mats.band)
	_classroom_text(parent,"RỬA TAY SAU KHI SỬ DỤNG",Vector3(notice_x,floor_y+2.60,south_wall_z-.19),PI,13,Color("#e0d8c3"),.006)

func _side_room(parent: Node3D, title: String, center: Vector3, width: float, depth: float, level: int, east_wing: bool, interior := "class", suppress_north_end_wall := false, suppress_south_end_wall := false) -> void:
	var y := float(level)*FLOOR_HEIGHT
	var outer_sign := 1.0 if east_wing else -1.0
	var inner_sign := -outer_sign
	_box(parent,title+" floor",Vector3(center.x,y+.06,center.z),Vector3(width,.12,depth),mats.tile,true)
	# The narrow rooms beside stair A/C are deliberately recessed. Keep their
	# glazed bays south of the stair landing, not looking into a blind shell.
	var recessed_bay := width <= 4.01 and center.z < -12.0
	var window_centers: Array[float] = []
	if title == "WC NAM":
		# Keep only the north-end bay; the broad east wall remains solid for the
		# two visible urinals opposite the entrance.
		window_centers = [center.z-1.8]
	elif east_wing and width <= 4.01 and level <= 1 and center.z < -12.0 and depth >= 8.0:
		# Ground Class 1 and the Level-2 practice bay deepen southward, but their
		# east return at z≈-14 remains a clear structural route. Keep panes away
		# from that perpendicular return wall rather than glazing through it.
		window_centers = [center.z-2.7,center.z+2.7]
	elif recessed_bay:
		window_centers = [center.z-.85, center.z+.85]
	else:
		var window_spread := 2.7 if depth >= 8.0 else 1.8
		window_centers = [center.z-window_spread, center.z, center.z+window_spread]
	_wall_window_apertures(parent,title+" outer wall",Vector3(center.x+outer_sign*width*.5,y,center.z),depth,y,false,window_centers)
	# At room-to-room seams, the southern bay owns the complete common end wall.
	# Its neighbor suppresses its duplicate so the shared partition has one body.
	if not suppress_north_end_wall:
		_box(parent,title+" end wall north",Vector3(center.x,y+1.62,center.z-depth*.5),Vector3(width,3.12,.2),mats.wall,true)
	if not suppress_south_end_wall:
		_box(parent,title+" end wall south",Vector3(center.x,y+1.62,center.z+depth*.5),Vector3(width,3.12,.2),mats.wall,true)
	_box(parent,title+" ceiling",Vector3(center.x,y+3.08,center.z),Vector3(width,.12,depth),mats.concrete,true)
	if not (title == "LỚP HỌC 1" and level == 0):
		_room_ceiling_light(parent,title,center,y,interior == "class")
	_box(parent,title+" lower outer band",Vector3(center.x+outer_sign*(width*.5-.12),y+.48,center.z),Vector3(.08,.82,depth-.2),mats.wall_base_band)
	_box(parent,title+" exterior base band",Vector3(center.x+outer_sign*(width*.5+.12),y+.48,center.z),Vector3(.07,.82,depth-.2),mats.wall_base_band)
	var exterior_pier_edges: Array[float] = []
	if not suppress_north_end_wall:
		exterior_pier_edges.append(center.z-depth*.5)
	if not suppress_south_end_wall:
		exterior_pier_edges.append(center.z+depth*.5)
	for edge_z in exterior_pier_edges:
		_box(parent,title+" exterior corner pier",Vector3(center.x+outer_sign*(width*.5+.13),y+1.67,edge_z),Vector3(.20,3.1,.26),mats.concrete)
	var window_count := 1 if title == "LỚP HỌC 1" and level == 0 else window_centers.size()
	for i in range(window_count):
		var wz: float = window_centers[i]
		_box(parent,title+" exterior window",Vector3(center.x+outer_sign*(width*.5-.13),y+1.92,wz),Vector3(.08,1.38,1.0),mats.glass,true)
		_box(parent,title+" window head",Vector3(center.x+outer_sign*(width*.5-.13),y+2.65,wz),Vector3(.14,.08,1.12),mats.wood)
		_box(parent,title+" window sill",Vector3(center.x+outer_sign*(width*.5-.13),y+1.19,wz),Vector3(.14,.08,1.12),mats.wood)
		_box(parent,title+" window north stile",Vector3(center.x+outer_sign*(width*.5-.13),y+1.92,wz-.54),Vector3(.14,1.46,.08),mats.wood)
		_box(parent,title+" window south stile",Vector3(center.x+outer_sign*(width*.5-.13),y+1.92,wz+.54),Vector3(.14,1.46,.08),mats.wood)
	if title == "LỚP HỌC 1" and level == 0:
		# Ensure the small four-metre classroom keeps a second real, divided
		# window bay rather than collapsing to a single pane at this scale.
		var second_window_z := window_centers[1]
		var outer_window_x := center.x+outer_sign*(width*.5-.13)
		_box(parent,title+" exterior window second",Vector3(outer_window_x,y+1.92,second_window_z),Vector3(.08,1.38,1.0),mats.glass,true)
		_box(parent,title+" window head second",Vector3(outer_window_x,y+2.65,second_window_z),Vector3(.14,.08,1.12),mats.wood)
		_box(parent,title+" window sill second",Vector3(outer_window_x,y+1.19,second_window_z),Vector3(.14,.08,1.12),mats.wood)
		_box(parent,title+" window north stile second",Vector3(outer_window_x,y+1.92,second_window_z-.54),Vector3(.14,1.46,.08),mats.wood)
		_box(parent,title+" window south stile second",Vector3(outer_window_x,y+1.92,second_window_z+.54),Vector3(.14,1.46,.08),mats.wood)
	# Corridor-side wall has a single 1.5 m clear entrance; neighboring rooms remain separated.
	var inner_x:=center.x+inner_sign*width*.5
	var door_center_z := center.z + .85 if title == "LỚP HỌC 1" and level == 0 else center.z
	var north_wall_edge := center.z-depth*.5
	var south_wall_edge := center.z+depth*.5
	var door_opening := 1.55
	var north_wall_length := door_center_z-door_opening*.5-north_wall_edge
	var south_wall_length := south_wall_edge-(door_center_z+door_opening*.5)
	_box(parent,title+" corridor wall north",Vector3(inner_x,y+1.55,north_wall_edge+north_wall_length*.5),Vector3(.2,3.0,north_wall_length),mats.wall,true)
	_box(parent,title+" corridor wall south",Vector3(inner_x,y+1.55,door_center_z+door_opening*.5+south_wall_length*.5),Vector3(.2,3.0,south_wall_length),mats.wall,true)
	_box(parent,title+" door lintel",Vector3(inner_x,y+2.55,door_center_z),Vector3(.2,.3,door_opening),mats.wood)
	_box(parent,title+" door jamb north",Vector3(inner_x,y+1.15,door_center_z-door_opening*.5),Vector3(.2,2.3,.12),mats.wood)
	_box(parent,title+" door jamb south",Vector3(inner_x,y+1.15,door_center_z+door_opening*.5),Vector3(.2,2.3,.12),mats.wood)
	# Put the leaf and frosted pane under a real hinge pivot. The panel is already
	# held open into the room, but now its pose is measured from the jamb instead
	# of rotating around its center and cutting diagonally across the doorway.
	var door_hinge := Node3D.new()
	door_hinge.name = title + " door hinge pivot"
	door_hinge.position = Vector3(inner_x-inner_sign*.08, y+1.15, door_center_z-door_opening*.5+.06)
	door_hinge.rotation.y = outer_sign * PI / 2.0
	parent.add_child(door_hinge)
	_box(door_hinge,title+" wooden door leaf",Vector3(0,0,.41),Vector3(.12,2.25,.82),mats.wood)
	_box(door_hinge,title+" door glass center mullion",Vector3(-outer_sign*.07,.67,.41),Vector3(.025,.7,.035),mats.wood)
	for pane_y in [.32,.67,1.02]:
		_box(door_hinge,title+" door glass crossbar",Vector3(-outer_sign*.07,pane_y,.41),Vector3(.025,.035,.56),mats.wood)
	if title == "LỚP HỌC 1" and level == 0:
		# Preserve the existing door collider on the same open leaf pose.
		var door_body := StaticBody3D.new()
		door_body.name = "LỚP HỌC 1 wooden door leaf body"
		door_body.position = Vector3(0,0,.41)
		var door_shape := CollisionShape3D.new()
		var door_box := BoxShape3D.new()
		door_box.size = Vector3(.12,2.25,.82)
		door_shape.shape = door_box
		door_body.add_child(door_shape)
		door_hinge.add_child(door_body)
	_box(door_hinge,title+" frosted door glass",Vector3(-outer_sign*.045,.67,.41),Vector3(.025,.7,.56),mats.glass)
	# The side-room corridor runs along X: east-wing doors face -X, west-wing
	# doors face +X. _label rotates both the plaque and the Label3D offset.
	var face := -PI / 2.0 if east_wing else PI / 2.0
	_label(parent,title,Vector3(inner_x+inner_sign*.08,y+2.85,door_center_z),face,20)
	if title == "PHÒNG HIỆU TRƯỞNG":
		# Reinforce room identity inside as well as at the corridor door; the
		# south-wall board remains clear of the desks and principal access aisle.
		var principal_board_z := center.z+depth*.5-.16
		_box(parent,title+" interior identity board",Vector3(center.x,y+2.18,principal_board_z),Vector3(minf(width-1.0,2.7),.68,.08),mats.sign)
		_classroom_text(parent,"PHÒNG HIỆU TRƯỞNG",Vector3(center.x,y+2.25,principal_board_z-.055),PI,21,Color("#e5ddc7"),.007)
		_classroom_text(parent,"BAN GIÁM HIỆU",Vector3(center.x,y+1.96,principal_board_z-.055),PI,13,Color("#d1c4a7"),.007)
	_room_shell_edge_details(parent,title,center,width,depth,y,false,inner_sign,door_center_z,door_opening,suppress_north_end_wall,suppress_south_end_wall)
	match interior:
		"class":
			if title == "LỚP HỌC 1" and level == 0:
				_classroom_one_detail(parent,center,y)
			else:
				var board_x := center.x+outer_sign*(width*.5-.18)
				var board_depth := minf(depth*.52,3.0)
				_box(parent,title+" chalkboard",Vector3(board_x,y+1.75,center.z),Vector3(.12,1.05,board_depth),mats.chalk)
				_box(parent,title+" chalkboard top frame",Vector3(board_x-inner_sign*.04,y+2.32,center.z),Vector3(.12,.08,board_depth+.12),mats.wood)
				_box(parent,title+" chalk tray",Vector3(board_x+inner_sign*.10,y+1.18,center.z),Vector3(.23,.08,board_depth+.16),mats.wood)
				var class_face := -PI/2.0 if east_wing else PI/2.0
				_classroom_text(parent,"CHĂM NGOAN  •  HỌC TỐT",Vector3(board_x+inner_sign*.13,y+2.05,center.z),class_face,16,Color("#c8d0bd"),.007)
				var duty_board_z := center.z+depth*.5-.135
				_box(parent,title+" class duty board",Vector3(center.x,y+1.78,duty_board_z),Vector3(1.6,.92,.07),mats.band)
				_box(parent,title+" class duty board paper",Vector3(center.x,y+1.78,duty_board_z-.05),Vector3(1.34,.66,.025),mats.paper)
				_classroom_text(parent,"LỊCH TRỰC\nNỀ NẾP LỚP",Vector3(center.x,y+1.78,duty_board_z-.07),PI,14,Color("#34444a"),.006)
				_school_desk(parent,title+" teacher desk",Vector3(center.x+outer_sign*(width*.5-1.0),y,center.z),.85,1.05,.82)
				var columns := 1 if width < 5.0 else (3 if width >= 9.0 else 2)
				var rows := 4 if depth >= 8.0 else (3 if columns == 1 else 2)
				var expanded_row_offsets: Array[float] = [-3.1,-1.35,1.35,3.1]
				for row in range(rows):
					for col in range(columns):
						var offset := .55 if columns == 1 else (.9+float(col)*1.4 if columns == 3 else .8+float(col)*minf(1.4,width*.18))
						var row_spacing := minf(1.8,(depth-1.8)/maxf(float(rows-1),1.0))
						var row_z := center.z+expanded_row_offsets[row] if depth >= 8.0 else center.z+(float(row)-float(rows-1)*.5)*row_spacing
						var p := Vector3(center.x+inner_sign*offset,y,row_z)
						_school_desk(parent,title+" student desk",p)
						_school_bench(parent,title+" student bench",p+Vector3(inner_sign*.65,0,0),Vector3(inner_sign,0,0))
				_school_ceiling_fan(parent,title,center,y)
		"office", "club":
			# Desks and cabinets occupy the player volume; trim, glass and small
			# props stay visual-only. Keep the two ground-floor office desks at
			# their mapped gameplay positions even where the facade steps out.
			var desk_x := center.x+.75 if title == "PHÒNG ĐOÀN" else center.x
			var desk_width := 2.8 if title == "PHÒNG ĐOÀN" else (2.0 if title == "PHÒNG HIỆU TRƯỞNG" else 1.6)
			var desk_depth := 1.02 if title == "PHÒNG ĐOÀN" else .86
			_box(parent,title+" work table",Vector3(desk_x,y+.82,center.z),Vector3(desk_width,.15,desk_depth),mats.wood,true)
			for side in [-1.0,1.0]:
				_box(parent,title+" work table leg",Vector3(desk_x+side*(desk_width*.5-.16),y+.42,center.z-desk_depth*.38),Vector3(.07,.77,.07),mats.metal)
				_box(parent,title+" work table leg",Vector3(desk_x+side*(desk_width*.5-.16),y+.42,center.z+desk_depth*.38),Vector3(.07,.77,.07),mats.metal)
			if interior == "office":
				_box(parent,title+" filing cabinet",Vector3(center.x+outer_sign*(width*.5-.44),y+.70,center.z+1.65),Vector3(.55,1.35,.7),mats.metal,true)
				if title != "PHÒNG ĐOÀN":
					_box(parent,title+" visitor chair",Vector3(desk_x+inner_sign*1.15,y+.42,center.z+1.25),Vector3(.52,.16,.52),mats.wood,true)
				if title == "PHÒNG HIỆU TRƯỞNG":
					# A compact administrator's room: bookcase, clock, framed
					# certificates and a readable desk without blocking its door.
					_box(parent,title+" bookcase",Vector3(center.x-.9,y+1.05,center.z-depth*.5+.43),Vector3(1.15,2.02,.52),mats.wood,true)
					for shelf in range(3):
						_box(parent,title+" bookcase shelf",Vector3(center.x-.9,y+.40+float(shelf)*.55,center.z-depth*.5+.75),Vector3(1.0,.07,.45),mats.wood)
						for book in range(5):
							_box(parent,title+" bound volume",Vector3(center.x-1.29+float(book)*.19,y+.57+float(shelf)*.55,center.z-depth*.5+.76),Vector3(.12,.28,.29),mats.book)
					_box(parent,title+" wall clock",Vector3(center.x+.9,y+2.12,center.z-depth*.5+.16),Vector3(.50,.50,.06),mats.paper)
					_box(parent,title+" clock hands",Vector3(center.x+.9,y+2.12,center.z-depth*.5+.20),Vector3(.025,.32,.01),mats.ink)
					_box(parent,title+" framed certificate",Vector3(center.x+.9,y+1.65,center.z-depth*.5+.16),Vector3(.62,.37,.07),mats.wood)
					_box(parent,title+" certificate paper",Vector3(center.x+.9,y+1.65,center.z-depth*.5+.21),Vector3(.51,.27,.01),mats.paper)
					_box(parent,title+" desk blotter",Vector3(desk_x-.08,y+.9075,center.z),Vector3(.92,.025,.56),mats.band)
					_box(parent,title+" ledger stack",Vector3(desk_x-.43,y+.965,center.z-.13),Vector3(.34,.09,.38),mats.paper)
					_box(parent,title+" open appointment book",Vector3(desk_x+.20,y+.9325,center.z+.11),Vector3(.48,.025,.36),mats.paper)
					_box(parent,title+" desk lamp base",Vector3(desk_x+.62,y+.915,center.z-.20),Vector3(.18,.04,.18),mats.metal)
					_visual_cylinder(parent,title+" desk lamp stem",Vector3(desk_x+.62,y+1.05,center.z-.20),.025,.23,mats.metal,8)
					_visual_cylinder(parent,title+" desk lamp shade",Vector3(desk_x+.62,y+1.19,center.z-.20),.10,.09,mats.rail,8)
					# A small consultation set makes the enlarged principal's office
					# functional rather than an oversized empty shell. It sits south of
					# the working desk and leaves the entrance/door swing unobstructed.
					var conference_center := Vector3(center.x,y,center.z+2.55)
					_box(parent,title+" visitor meeting table",conference_center+Vector3(0,.78,0),Vector3(1.35,.12,.84),mats.wood,true)
					for side in [-1.0,1.0]:
						for end in [-1.0,1.0]:
							_box(parent,title+" visitor meeting chair seat",conference_center+Vector3(side*.98,.45,end*.72),Vector3(.46,.10,.46),mats.wood,true)
							_box(parent,title+" visitor meeting chair back",conference_center+Vector3(side*1.20,.75,end*.72),Vector3(.06,.52,.43),mats.wood)
				elif title == "PHÒNG ĐOÀN":
					# Longer meeting table and chairs, a red student-union board,
					# low storage and a flag give this room its own identity.
					for chair_x in [-1.05,0.0,1.05]:
						for chair_z in [-1.15,1.15]:
							_box(parent,title+" meeting chair seat",Vector3(desk_x+chair_x,y+.46,center.z+chair_z),Vector3(.43,.10,.43),mats.wood,true)
							_box(parent,title+" meeting chair back",Vector3(desk_x+chair_x,y+.76,center.z+chair_z+(.21 if chair_z>0 else -.21)),Vector3(.43,.54,.06),mats.wood)
					var board_z := center.z-depth*.5+.20
					_box(parent,title+" red union board",Vector3(center.x,y+1.78,board_z),Vector3(3.3,1.32,.10),mats.banner)
					_classroom_text(parent,"ĐOÀN TNCS HỒ CHÍ MINH",Vector3(center.x,y+2.19,board_z+.07),0,20,Color("#e9d4a4"),.007)
					for pinned_index in range(4):
						_box(parent,title+" pinned activity sheet",Vector3(center.x-1.08+float(pinned_index)*.72,y+1.58,board_z+.07),Vector3(.46,.54,.012),mats.paper)
					_box(parent,title+" union storage cabinet",Vector3(center.x+outer_sign*(width*.5-.45),y+.85,center.z-1.65),Vector3(.65,1.6,1.1),mats.wood,true)
					_box(parent,title+" red flag cloth",Vector3(center.x+outer_sign*(width*.5-1.1),y+1.95,center.z+2.15),Vector3(.72,1.12,.04),mats.banner)
					_box(parent,title+" flagstaff",Vector3(center.x+outer_sign*(width*.5-.72),y+1.45,center.z+2.15),Vector3(.045,2.5,.045),mats.metal)
			else:
				# The two upper-level clubs have meeting furniture and wall
				# displays instead of a single anonymous slab in an empty room.
				if title == "PHÒNG CLB 1" and level == 1:
					var table_x := center.x-1.8
					var table_offsets: Array[float] = [-2.7,-.9,.9,2.7]
					for station in range(4):
						var table_z := center.z+table_offsets[station]
						var table_center := Vector3(table_x,y,table_z)
						_supported_worktop(parent,title,"club activity table top","club activity table leg",station+1,table_center,Vector2(1.35,.76),.79,mats.wood)
						_supported_seat(parent,title,"club stool",station*2+1,table_center+Vector3(-.88,0,0),.43)
						_supported_seat(parent,title,"club stool",station*2+2,table_center+Vector3(.88,0,0),.43)
				else:
					for table_z in [-2.7,-.9,.9,2.7]:
						_box(parent,title+" club activity table",Vector3(center.x-1.8,y+.79,center.z+table_z),Vector3(1.35,.13,.76),mats.wood,true)
						_box(parent,title+" club stool",Vector3(center.x-.35,y+.46,center.z+table_z),Vector3(.43,.12,.43),mats.wood,true)
				_box(parent,title+" club noticeboard",Vector3(center.x,y+1.8,center.z-depth*.5+.20),Vector3(3.0,1.16,.10),mats.chalk)
				_classroom_text(parent,"SINH HOẠT CÂU LẠC BỘ",Vector3(center.x,y+2.16,center.z-depth*.5+.28),0,18,Color("#eee2c3"),.007)
				for sheet in range(3):
					_box(parent,title+" club notice",Vector3(center.x-.8+float(sheet)*.8,y+1.62,center.z-depth*.5+.28),Vector3(.56,.48,.012),mats.paper)
				_box(parent,title+" club storage cupboard",Vector3(center.x+outer_sign*(width*.5-.50),y+1.0,center.z+1.5),Vector3(.72,1.9,1.0),mats.wood,true)
		"vocational":
			var bench_x := center.x+inner_sign*.65
			for x_offset in [-1.6,0.0,1.6]:
				_box(parent,title+" vocational workbench",Vector3(bench_x,y+.88,center.z+x_offset),Vector3(1.1,.16,1.05),mats.wood,true)
				_box(parent,title+" bench vise",Vector3(bench_x,y+1.08,center.z+x_offset-.30),Vector3(.24,.25,.18),mats.metal)
				_box(parent,title+" machine housing",Vector3(bench_x,y+1.10,center.z+x_offset+.22),Vector3(.42,.28,.32),mats.metal)
				_box(parent,title+" timber sample",Vector3(bench_x+outer_sign*.35,y+.985,center.z+x_offset+.29),Vector3(.16,.05,.42),mats.wood)
				_box(parent,title+" metal workpiece",Vector3(bench_x+inner_sign*.35,y+.985,center.z+x_offset-.30),Vector3(.16,.05,.32),mats.metal)
				_box(parent,title+" workbench trestle",Vector3(bench_x,y+.46,center.z+x_offset),Vector3(.12,.76,.72),mats.metal)
			# Keep tool storage below the windows on the solid south end wall, not
			# across the glazed outer wall or the corridor-side entrance.
			var cabinet_row_z := center.z+depth*.5-.375
			for cabinet_offset in [-width*.28,0.0,width*.28]:
				_box(parent,title+" tool cabinet",Vector3(center.x+cabinet_offset,y+1.12,cabinet_row_z),Vector3(.65,2.0,.55),mats.metal,true)
			var tool_wall_z := center.z+depth*.5-.14
			_box(parent,title+" wall tool board",Vector3(center.x,y+2.55,tool_wall_z),Vector3(2.2,.72,.08),mats.band)
			_classroom_text(parent,"DỤNG CỤ THỰC HÀNH",Vector3(center.x,y+2.80,tool_wall_z-.08),PI,13,Color("#d7ceb8"),.006)
			for tool in range(5):
				_box(parent,title+" hanging tool silhouette",Vector3(center.x-.82+float(tool)*.41,y+2.42,tool_wall_z-.05),Vector3(.07,.30,.025),mats.metal)
			_box(parent,title+" safety instruction board",Vector3(center.x,y+1.80,center.z-depth*.5+.135),Vector3(1.8,1.0,.07),mats.paper)
			_classroom_text(parent,"AN TOÀN THỰC HÀNH",Vector3(center.x,y+2.08,center.z-depth*.5+.185),0,16,Color("#304049"),.006)
		"lab":
			if title == "PHÒNG THỰC HÀNH" and level == 1:
				var station_offsets: Array[float] = [-2.4,-.8,.8,2.4]
				for station in range(4):
					var station_z := center.z+station_offsets[station]
					var work_center := Vector3(center.x+outer_sign*1.20,y,station_z)
					_supported_worktop(parent,title,"practice workstation top","practice workstation leg",station+1,work_center,Vector2(.72,.96),.80,mats.wood)
					_box(parent,"%s tool tray@%02d" % [title,station+1],work_center+Vector3(0,.89,-.20),Vector3(.42,.05,.26),mats.metal)
					_box(parent,"%s bench vice base@%02d" % [title,station+1],work_center+Vector3(0,.96,.23),Vector3(.18,.08,.16),mats.metal)
					_box(parent,"%s bench vice jaw@%02d" % [title,station+1],work_center+Vector3(0,1.05,.23),Vector3(.18,.12,.045),mats.rail)
					_supported_seat(parent,title,"practice stool",station+1,Vector3(work_center.x-outer_sign*1.12,y,station_z),.40)
				_box(parent,title+" wall tool cabinet",Vector3(center.x+outer_sign*(width*.5-.35),y+1.0,center.z+depth*.5-.48),Vector3(.52,1.7,.64),mats.wood,true)
			else:
				_box(parent,title+" work bench",Vector3(center.x,y+.9,center.z),Vector3(1.6,.18,2.2),mats.concrete,true)
				for bench_z in [-.72,.72]:
					_box(parent,title+" concrete bench pier",Vector3(center.x,y+.44,center.z+bench_z),Vector3(1.28,.8,.16),mats.concrete)
				for station_z in [-.72,.04,.80]:
					_box(parent,title+" practical stool",Vector3(center.x+outer_sign*1.20,y+.48,center.z+station_z),Vector3(.38,.10,.38),mats.wood,true)
				_box(parent,title+" equipment cabinet",Vector3(center.x+outer_sign*(width*.5-.43),y+1.0,center.z+depth*.5-.80),Vector3(.62,1.85,.82),mats.wood,true)
			if not (title == "PHÒNG THỰC HÀNH" and level == 1):
				_box(parent,title+" porcelain wash sink",Vector3(center.x,y+1.0,center.z+.55),Vector3(.62,.10,.48),mats.porcelain)
				_box(parent,title+" lab tap",Vector3(center.x,y+1.16,center.z+.28),Vector3(.045,.28,.045),mats.metal)
			_box(parent,title+" safety chart",Vector3(center.x,y+1.82,center.z-depth*.5+.18),Vector3(1.80,1.02,.06),mats.paper)
			_classroom_text(parent,"NỘI QUY THỰC HÀNH",Vector3(center.x,y+2.12,center.z-depth*.5+.23),0,15,Color("#304049"),.006)
		"computer":
			if title == "PHÒNG TIN HỌC" and level == 1:
				var station_index := 0
				for row in range(2):
					var station_x := center.x+inner_sign*2.8 if row == 0 else center.x-inner_sign*2.8
					var cpu_direction := 1.0 if row == 0 else -1.0
					for z_offset in [-2.4,-.8,.8,2.4]:
						station_index += 1
						_computer_station(parent,title,station_index,Vector3(station_x,y,center.z+z_offset),cpu_direction)
			else:
				for z_offset in [-1.1,0.0,1.1]:
					_box(parent,title+" computer desk",Vector3(center.x+inner_sign,y+.82,center.z+z_offset),Vector3(1.1,.12,.7),mats.wood,true)
					_box(parent,title+" CRT",Vector3(center.x+inner_sign,y+1.25,center.z+z_offset),Vector3(.45,.48,.28),mats.metal,true)
		"restroom":
			if title == "WC NAM":
				_mens_restroom_finish(parent,title,center,width,depth,y,outer_sign)
			else:
				for i in range(3):
					var wz:=center.z-depth*.27+float(i)*depth*.27
					_box(parent,title+" cubicle divider",Vector3(center.x+outer_sign*.1,y+1.15,wz),Vector3(width*.55,2.1,.08),mats.band,true)
					_box(parent,title+" toilet",Vector3(center.x+outer_sign*width*.28,y+.43,wz),Vector3(.45,.5,.5),mats.porcelain,true)
					_box(parent,title+" sink",Vector3(center.x+inner_sign*width*.3,y+.82,wz),Vector3(.5,.14,.42),mats.porcelain)

func _build_outer_facade(parent: Node3D, level: int, y: float) -> void:
	# Exterior wall spans are the complements of the actual room window bays.
	# A/C's northmost ground-floor rooms step inward so the z≈−14/−15 return
	# passages remain outside their shells. The short infill joins the enlarged
	# southern bays without replacing either return with a room wall.
	var west_spans: Array[Vector2] = [Vector2(-30.5,-21.0),Vector2(-15.0,-9.5),Vector2(-1.1,6.0)]
	var east_spans: Array[Vector2] = [Vector2(-30.5,-20.0),Vector2(-14.0,-9.5),Vector2(-1.1,6.0)]
	if level == 1:
		west_spans = [Vector2(-30.5,-17.9),Vector2(-1.1,6.0)]
		east_spans = [Vector2(-30.5,-20.0),Vector2(-14.0,-9.9),Vector2(-1.9,6.0)]
	else:
		# Level 3 has a final WC window bay after the last classroom.
		if level == 2:
			east_spans = [Vector2(-30.5,-20.0),Vector2(-14.0,-10.0),Vector2(-4.0,-2.0),Vector2(4.0,6.0)]
	for west_span in west_spans:
		_box(parent,"West outer facade infill",Vector3(-24,y+1.62,(west_span.x+west_span.y)*.5),Vector3(.20,3.12,west_span.y-west_span.x),mats.wall,true)
		_box(parent,"West facade infill base band",Vector3(-24.14,y+.48,(west_span.x+west_span.y)*.5),Vector3(.08,.82,west_span.y-west_span.x),mats.wall_base_band)
	for east_span in east_spans:
		_box(parent,"East outer facade infill",Vector3(24,y+1.62,(east_span.x+east_span.y)*.5),Vector3(.20,3.12,east_span.y-east_span.x),mats.wall,true)
		_box(parent,"East facade infill base band",Vector3(24.14,y+.48,(east_span.x+east_span.y)*.5),Vector3(.08,.82,east_span.y-east_span.x),mats.wall_base_band)
	# Thin concrete string courses make the three real storeys read as one
	# building rather than three exposed slabs. They are visual trim only.
	_box(parent,"West exterior storey course",Vector3(-24.18,y+3.06,-12.25),Vector3(.22,.20,36.5),mats.concrete)
	_box(parent,"East exterior storey course",Vector3(24.18,y+3.06,-12.25),Vector3(.22,.20,36.5),mats.concrete)
	if level != 1:
		_box(parent,"West recessed facade return",Vector3(-21,y+1.62,-15),Vector3(6,3.12,.20),mats.wall,true)
	# This return is a covered east-side passage from stair C around the
	# recessed room, not a blind wall across the route to the WC end wing.
	_box(parent,"East recessed return inner pier",Vector3(19.3,y+1.62,-14),Vector3(2.6,3.12,.20),mats.wall,true)
	_box(parent,"East recessed return outer pier",Vector3(23.7,y+1.62,-14),Vector3(.6,3.12,.20),mats.wall,true)
	_box(parent,"East recessed return doorway lintel",Vector3(22,y+2.78,-14),Vector3(2.8,.8,.20),mats.wall,true)
	# South wing ends have real 3 m portals aligned to courtyard approach ramps.
	# The open inner gallery edge at x≈±11 remains the everyday corridor route.
	for wing_sign in [-1.0,1.0]:
		_box(parent,"South wing outer entrance wall",Vector3(wing_sign*21.75,y+1.62,6),Vector3(4.5,3.12,.20),mats.wall,true)
		_box(parent,"South wing inner entrance wall",Vector3(wing_sign*14.9,y+1.62,6),Vector3(3.2,3.12,.20),mats.wall,true)
		_box(parent,"South wing doorway lintel",Vector3(wing_sign*18,y+2.73,6),Vector3(3.0,.72,.22),mats.wall,true)
		for jamb_offset in [-1.5,1.5]:
			_box(parent,"South wing doorway jamb",Vector3(wing_sign*18+jamb_offset,y+1.14,6),Vector3(.10,2.28,.22),mats.wood)

func _build_level(level: int) -> void:
	var y := float(level)*FLOOR_HEIGHT
	var root := Node3D.new()
	root.name = ["Ground", "Level2", "Level3"][level]
	add_child(root)
	# U-shaped floor: back/north bar and two wings. The courtyard remains open above level 1.
	var stair_holes: Array[Rect2]=[]
	if level > 0:
		for core_x in [-21.0,0.0,21.0]:
			# Keep the stairwell opening clear through the complete switchback flight
			# and its south landing. The previous 6.2 m cutout ended at z=-20.8,
			# exactly at the north-gallery floor edge, which blocked the player
			# before reaching the landing centered at z=-19.5.
			stair_holes.append(Rect2(core_x-2.5,-27.0,5.0,9.0))
	_floor_with_openings(root,"North block floor",Vector3(0,y,-25.75),Vector2(48,9.5),y,stair_holes,mats.tile)
	_floor_with_openings(root,"West wing floor",Vector3(-18,y,-8),Vector2(12,28),y,stair_holes,mats.tile)
	_floor_with_openings(root,"East wing floor",Vector3(18,y,-8),Vector2(12,28),y,stair_holes,mats.tile)
	# Inner galleries/corridors and continuous guardrails around void.
	var gallery_holes: Array[Rect2]=[]
	if level > 0:
		gallery_holes = stair_holes.duplicate()
	_floor_with_openings(root,"North gallery",Vector3(0,y,-22.0),Vector2(44,2.4),y,gallery_holes,mats.tile)
	# Match gallery and wing-floor top surfaces (y + .12) to avoid a collision lip.
	_box(root,"West gallery",Vector3(-11.3,y+.04,-8),Vector3(2.4,.16,27),mats.tile,true)
	_box(root,"East gallery",Vector3(11.3,y+.04,-8),Vector3(2.4,.16,27),mats.tile,true)
	if level > 0:
		# Terminate the transverse guardrail at the atrium side rails on every
		# upper floor; the east/west galleries lie beyond x=±10 and must remain
		# reachable from the north gallery.
		var north_rail_span := 20.0
		_rail(root,Vector3(0,y+.72,-17.9),Vector3(north_rail_span,1.35,.12),"North Atrium Rail")
		_rail(root,Vector3(-10.0,y+.72,-7),Vector3(.12,1.35,24),"West Atrium Rail")
		_rail(root,Vector3(10.0,y+.72,-7),Vector3(.12,1.35,24),"East Atrium Rail")
	# The room back walls themselves form the glazed north facade at z=-30.5.
	# Fill only the spaces between them: a second full solid wall at z=-33
	# made a disconnected blind shell behind every classroom window.
	for facade_bay in [Vector2(-21.75,4.5),Vector2(.25,5.5),Vector2(10.5,1.0),Vector2(20.5,7.0)]:
		_box(root,"North facade infill",Vector3(facade_bay.x,y+1.55,-30.5),Vector3(facade_bay.y,3.1,.2),mats.wall,true)
	_box(root,"North facade exterior base band",Vector3(0,y+.48,-30.64),Vector3(48,.82,.08),mats.wall_base_band)
	_box(root,"North exterior storey course",Vector3(0,y+3.06,-30.68),Vector3(48,.20,.22),mats.concrete)
	for pier_x in [-24.0,-19.5,-14.5,-7.5,-2.5,3.0,10.0,11.0,17.0,24.0]:
		_box(root,"North facade vertical pier",Vector3(pier_x,y+1.63,-30.65),Vector3(.22,3.08,.20),mats.concrete)
	_build_outer_facade(root,level,y)
	# Room shells using the exact room program per floor.
	if level == 0:
		# Keep the first room of each wing recessed beside the A/C return; enlarge
		# its depth instead, then continue south into a broad contiguous second bay.
		# The southern room owns the sole full-width common wall at each seam.
		_side_room(root,"PHÒNG HIỆU TRƯỞNG",Vector3(-16,y,-13.7),4,8.4,level,false,"office",false,true)
		_side_room(root,"PHÒNG ĐOÀN",Vector3(-19,y,-5.3),10,8.4,level,false,"office")
		_room(root,"BẢNG TIN",Vector3(-17,y,-27),5,7,level,"office")
		_room(root,"LỚP HỌC 3",Vector3(-11,y,-27),7,7,level)
		_room(root,"PHÒNG GIÁO VIÊN",Vector3(-5,y,-27),5,7,level,"office")
		_room(root,"LỚP HỌC 4",Vector3(6.5,y,-27),7,7,level)
		_room(root,"WC TẦNG 1",Vector3(14,y,-27),6,7,level,"restroom")
		_side_room(root,"LỚP HỌC 1",Vector3(16,y,-13.7),4,8.4,level,true,"class",false,true)
		_side_room(root,"LỚP HỌC 2",Vector3(19,y,-5.3),10,8.4,level,true)
	elif level == 1:
		_side_room(root,"PHÒNG CLB 1",Vector3(-18.75,y,-13.7),10.5,8.4,level,false,"club",false,true)
		_side_room(root,"PHÒNG CLB 2",Vector3(-18.75,y,-5.3),10.5,8.4,level,false,"club")
		_room(root,"WC GIÁO VIÊN",Vector3(-17,y,-27),5,7,level,"restroom")
		_room(root,"THƯ VIỆN",Vector3(-10,y,-27),8,7,level,"library")
		# Story scenes place the chess club on level 3. Keep this level-2 room as
		# an ordinary shared club room, matching the existing floorplan footprint.
		_room(root,"PHÒNG CLB",Vector3(-4,y,-27),4,7,level,"club")
		_room(root,"THỰC HÀNH HÓA",Vector3(6,y,-27),7,7,level,"lab")
		_room(root,"NHÀ KHO",Vector3(14,y,-27),6,7,level,"storage")
		# Stair C's upper landing occupies x≈18.5..23.5 near z=-19.5.
		# Recess this practice room like Classroom 1 below so its ceiling and
		# north partition never cap the playable stair transfer.
		_side_room(root,"PHÒNG THỰC HÀNH",Vector3(16,y,-13.9),4,8,level,true,"lab",false,true)
		_side_room(root,"PHÒNG TIN HỌC",Vector3(19,y,-5.9),10,8,level,true,"computer")
	else:
		_side_room(root,"PHÒNG HỌC NGHỀ 1",Vector3(-16,y,-18),4,6,level,false,"vocational")
		_side_room(root,"PHÒNG HỌC NGHỀ 2",Vector3(-18.75,y,-8),10.5,6,level,false,"vocational")
		_room(root,"BẢNG TIN TẦNG 3",Vector3(-17,y,-27),5,7,level,"office")
		_room(root,"LỚP HỌC 3",Vector3(-11,y,-27),7,7,level)
		# Keep this room's west boundary fixed while clearing B's final flight.
		_room(root,"PHÒNG HỌC",Vector3(-5,y,-27),5,7,level)
		_room(root,"LỚP HỌC 4",Vector3(6.5,y,-27),7,7,level)
		_room(root,"CLB CỜ VUA",Vector3(14,y,-27),6,7,level,"chess")
		_side_room(root,"LỚP HỌC 1",Vector3(16,y,-17),4,6,level,true)
		_side_room(root,"LỚP HỌC 2",Vector3(19,y,-7),10,6,level,true)
		_side_room(root,"WC NAM",Vector3(19,y,1),10,6,level,true,"restroom")
	# Repeated windows and corridor light pools.
	for x in range(-20,21,5):
		var lamp := _light(root,Vector3(float(x),y+2.85,-19.0),Color("#9cbdc8"),.48,4.2)
		lamp.name = "Cool Fluorescent"
	for z in [-17.0,-8.0,1.0]:
		_light(root,Vector3(-11,y+2.85,z),Color("#9cbdc8"),.43,3.5)
		_light(root,Vector3(11,y+2.85,z),Color("#9cbdc8"),.43,3.5)
	for z in [-16.0,-5.0,5.0]:
		_box(root,"Gallery concrete column",Vector3(-10.0,y+1.55,z),Vector3(.48,3.1,.48),mats.concrete,true)
		_box(root,"Gallery concrete column",Vector3(10.0,y+1.55,z),Vector3(.48,3.1,.48),mats.concrete,true)
		# Visual-only transverse headers form the repeated concrete portals seen
		# in the PS2 corridor reference; openings and navigation stay untouched.
		_box(root,"West covered gallery portal header",Vector3(-11.1,y+2.98,z),Vector3(2.05,.24,.30),mats.concrete)
		_box(root,"East covered gallery portal header",Vector3(11.1,y+2.98,z),Vector3(2.05,.24,.30),mats.concrete)
		if level == LEVELS-1:
			# Keep Level-3 seating out of the walking line and the three east-wing
			# door approaches. These centers sit on the corridor wall segments between
			# the 1.55 m openings at z=-17, -7, and 1. The benches run along Z and stay
			# within the wall-side strip (x=13.395..13.845, wall face x=13.9).
			var bench_z := -12.0 if is_equal_approx(z,-16.0) else (-3.5 if is_equal_approx(z,-5.0) else 2.9)
			_box(root,"Corridor bench seat",Vector3(13.62,y+.58,bench_z),Vector3(.45,.14,1.8),mats.wood)
			_box(root,"Corridor bench legs",Vector3(13.62,y+.32,bench_z),Vector3(.08,.48,1.55),mats.metal)
		else:
			_box(root,"Corridor bench seat",Vector3(12.2,y+.58,z),Vector3(1.8,.14,.45),mats.wood)
			_box(root,"Corridor bench legs",Vector3(12.2,y+.32,z),Vector3(1.55,.48,.08),mats.metal)
		_box(root,"PCCC cabinet",Vector3(-12.05,y+1.05,z),Vector3(.22,1.8,.65),mats.emergency_case)
		_box(root,"PCCC cabinet front panel",Vector3(-11.92,y+1.06,z),Vector3(.035,1.50,.50),mats.banner)
		_box(root,"PCCC red indicator lens",Vector3(-11.895,y+1.60,z),Vector3(.025,.14,.14),mats.emergency_lens)
		_label(root,"PCCC",Vector3(-11.9,y+1.15,z),PI,15)
	_build_stair_core(root,"A",Vector3(-21,y,-22.5),level)
	_build_stair_core(root,"B",Vector3(0,y,-22.5),level)
	_build_stair_core(root,"C",Vector3(21,y,-22.5),level)
	if level == 0:
		# Gentle, collidable transitions from the courtyard paving (top y=0) to
		# the ground-floor wing slabs (top y=.12); mirrored at both wing entries.
		_add_entry_ramp(root,"West wing courtyard ramp",Vector3(-18,0,7),12.0,2.0,.12)
		_add_entry_ramp(root,"East wing courtyard ramp",Vector3(18,0,7),12.0,2.0,.12)
		# The north approach sits on the lower foundation (-.4), while the ground
		# floor and Stair B landing are at +.12. Keep the central stair approach,
		# and add a separate gentle ramp at the open east edge so the raised floor
		# behind the stage is reachable without a knee-height step.
		_add_entry_ramp(root,"Stair B south approach",Vector3(0,-.46,-17.2),4.8,2.0,.52)
		_add_entry_ramp(root,"Ground floor behind-stage east approach",Vector3(7.2,-.46,-18.6),4.8,4.8,.52)
		_add_stair_b_side_ramp(root,"Stair B east approach",3.5,-19.5,1.0)
		_add_stair_b_side_ramp(root,"Stair B west approach",-3.5,-19.5,-1.0)
		_build_stage_and_yard()

func _add_stair_b_side_ramp(parent: Node3D, label: String, center_x: float, center_z: float, side: float) -> void:
	# Side-on access from the gallery gap; high edge overlaps the landing.
	var ramp := Node3D.new()
	ramp.name = label
	parent.add_child(ramp)
	var slope := -side * atan(.52 / 2.2)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.2,.12,2.4)
	var visual := MeshInstance3D.new()
	visual.name = "Slope"
	visual.mesh = mesh
	visual.material_override = mats.concrete
	visual.position = Vector3(center_x,-.2,center_z)
	visual.rotation.z = slope
	ramp.add_child(visual)
	var body := StaticBody3D.new()
	body.name = "WalkableBody"
	body.position = visual.position
	body.rotation = visual.rotation
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = mesh.size
	shape.shape = box
	body.add_child(shape)
	ramp.add_child(body)

func _add_entry_ramp(parent: Node3D, label: String, center: Vector3, width: float, run: float, rise: float) -> void:
	var slope := atan(rise/run)
	var ramp_mesh := MeshInstance3D.new()
	ramp_mesh.name = label
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width,.12,run)
	ramp_mesh.mesh = mesh
	ramp_mesh.material_override = mats.concrete
	ramp_mesh.position = center+Vector3(0,rise*.5,0)
	ramp_mesh.rotation.x = slope
	parent.add_child(ramp_mesh)
	var body := StaticBody3D.new()
	body.name = label+"Body"
	body.position = ramp_mesh.position
	body.rotation.x = slope
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _rail(parent: Node3D, at: Vector3, size: Vector3, label_text: String) -> void:
	_box(parent,label_text+" top",at+Vector3(0,.62,0),Vector3(size.x,.08,size.z),mats.rail,true)
	var count := maxi(2,int(maxf(size.x,size.z)/1.4))
	for i in range(count):
		var t := float(i)/float(count-1)-.5
		var offset := Vector3(t*size.x,0,t*size.z)
		_box(parent,label_text+" baluster",at+offset,Vector3(.045,1.25,.045),mats.rail,true)

func _build_stair_core(parent: Node3D, core: String, base: Vector3, level: int) -> void:
	var stair := Node3D.new()
	stair.name = "StairCore"+core
	parent.add_child(stair)
	# Core identity and aligned landing at each storey; visible treads plus smooth ramp collision.
	var rise := FLOOR_HEIGHT
	var run := 6.0
	var direction: float = -1.0 if level%2==1 else 1.0
	# Each switchback flight uses a separate lateral lane. Keeping a 0.7 m
	# clear gap between the 1.8 m collision ramps prevents the upper flight's
	# underside from striking the player while they climb the lower flight.
	var lane_offset: float = -1.2 if level%2==0 else 1.2
	var lane_x: float = base.x+lane_offset
	# Explicit platforms at both ends of each flight. On the next level, the
	# following flight's lower platform coincides with this upper platform.
	if level == 0:
		_box(stair,"Stair "+core+" lower landing L0",base+Vector3(0,.06,direction*run*.5),Vector3(5.0,.12,2.8),mats.concrete,true)
	var landing_center := base+Vector3(0,rise+.06,-direction*run*.5)
	# Keep the platform walkable between switchback lanes, but leave clear slots
	# above both ramp collision strips. A full slab here presents a vertical face
	# across the rising ramp before its top reaches the landing.
	var far_half := landing_center+Vector3(0,0,-direction*.7)
	_box(stair,"Stair "+core+" upper landing L%d" % level,landing_center,Vector3(.6,.12,2.8),mats.concrete,true)
	_box(stair,"Stair "+core+" upper landing L%d west edge" % level,landing_center+Vector3(-2.3,0,0),Vector3(.4,.12,2.8),mats.concrete,true)
	_box(stair,"Stair "+core+" upper landing L%d east edge" % level,landing_center+Vector3(2.3,0,0),Vector3(.4,.12,2.8),mats.concrete,true)
	# Thin, visual-only fascia makes the split landing slabs read as one finished
	# platform from the stairwell without filling their transfer channels.
	for side in [-1.0,1.0]:
		_box(stair,"Stair "+core+" landing L%d outer fascia" % level,landing_center+Vector3(side*2.49,-.025,0),Vector3(.035,.17,2.72),mats.band)
	# The channels stop at the landing midpoint. The far half stays continuous,
	# giving the player a level pad to transfer laterally onto the next flight.
	# The transfer lane centers are 2.4 m apart. Make the walkable pads meet
	# across that full interval; the previous 1.8 m pads left a 0.6 m hole that
	# the player capsule could not cross to reach the next switchback flight.
	_box(stair,"Stair "+core+" upper landing L%d west lane pad" % level,far_half+Vector3(-1.2,0,0),Vector3(2.4,.12,1.4),mats.concrete,true)
	_box(stair,"Stair "+core+" upper landing L%d east lane pad" % level,far_half+Vector3(1.2,0,0),Vector3(2.4,.12,1.4),mats.concrete,true)
	if level == LEVELS-1:
		# At the final roof landing there is no following switchback. Fill the
		# unused opposite near-half lane; keep this flight's incoming lane clear
		# until its ramp reaches the landing midpoint.
		var near_half := landing_center+Vector3(0,0,direction*.7)
		_box(stair,"Stair "+core+" upper landing L%d unused lane pad" % level,near_half+Vector3(1.2,0,0),Vector3(1.8,.12,1.4),mats.concrete,true)
	for i in range(18):
		var t := float(i+1)/18.0
		_box(stair,"Stair "+core+" tread L%d %02d" % [level,i+1],base+Vector3(lane_offset,rise*t-.08,direction*(run*.5-run*t)),Vector3(1.8,.16,.42),mats.concrete)
	var ramp := StaticBody3D.new()
	ramp.name = "ContinuousWalkRamp "+core+" L%d" % level
	ramp.position = base+Vector3(lane_offset,rise*.5,0)
	ramp.rotation.x = atan((rise/run)*direction)
	var soffit := _box(stair,"Stair "+core+" structural soffit L%d" % level,base+Vector3(lane_offset,rise*.5-.27,0),Vector3(1.95,.24,sqrt(rise*rise+run*run)+.10),mats.concrete)
	soffit.rotation.x = ramp.rotation.x
	for side in [-1.0,1.0]:
		var stringer := _box(stair,"Stair "+core+" stringer L%d" % level,base+Vector3(lane_offset+side*.95,rise*.5-.23,0),Vector3(.08,.16,sqrt(rise*rise+run*run)),mats.band)
		stringer.rotation.x = ramp.rotation.x
	var shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(1.8,.2,sqrt(rise*rise+run*run))
	shape.shape = ramp_box
	ramp.add_child(shape)
	stair.add_child(ramp)
	_label(stair,"CẦU THANG "+core,base+Vector3(0,2.7,2.25),0,19)
	var low_landing_z := base.z+direction*run*.5
	_add_stair_side_rail(stair,core,level,lane_x-1.05,base,rise,run,direction,low_landing_z,"west")
	_add_stair_side_rail(stair,core,level,lane_x+1.05,base,rise,run,direction,low_landing_z,"east")
	if core == "B" and level == LEVELS-2:
		_add_stair_b_level3_east_edge_connector(parent,base,landing_center)

func _add_stair_b_level3_east_edge_connector(parent: Node3D, base: Vector3, landing_center: Vector3) -> void:
	# A narrow east-rim bypass routes around B's upper east handrail endpoint
	# and meets the existing north-gallery floor. It stays beside the stair
	# shaft; it does not bridge the open courtyard or change storey height.
	var landing_y := base.y+FLOOR_HEIGHT
	# End at the south edge of the landing (z=-18.1), keeping the connector
	# continuously supported while extending its exposed section to a guarded rim.
	var connector_south_z := landing_center.z+1.4
	var connector_north_z := -20.9
	var connector_center_z := (connector_south_z+connector_north_z)*.5
	var connector_depth := connector_south_z-connector_north_z
	_box(parent,"Stair B L3 east-edge gallery connector floor",Vector3(2.95,landing_y+.06,connector_center_z),Vector3(1.7,.12,connector_depth),mats.concrete,true)
	# Guard the open courtyard edge along the full bypass. The shaft-side rail
	# starts north of the landing-backed transfer opening; Hoang can move south
	# past the sloped handrail tip, step east, then follow the guarded rim north.
	_rail(parent,Vector3(3.8,landing_y+.72,connector_center_z),Vector3(.12,1.35,connector_depth),"Stair B L3 east-edge connector courtyard guardrail")
	var shaft_guard_south_z := landing_center.z-.05
	var shaft_guard_length := shaft_guard_south_z-connector_north_z
	var shaft_guard_center_z := (shaft_guard_south_z+connector_north_z)*.5
	_rail(parent,Vector3(2.5,landing_y+.72,shaft_guard_center_z),Vector3(.12,1.35,shaft_guard_length),"Stair B L3 east-edge connector shaft guardrail")
	# The south edge is exposed only east of x=2.5. The 0.4 m west portal
	# remains backed by Stair B's landing edge slab; guard only the unsupported
	# connector edge and meet the east-side guardrail at its corner.
	var south_guard_start_x := 2.5
	var south_guard_end_x := 3.8
	var south_guard_center_x := (south_guard_start_x+south_guard_end_x)*.5
	var south_guard_length := south_guard_end_x-south_guard_start_x
	_rail(parent,Vector3(south_guard_center_x,landing_y+.72,connector_south_z),Vector3(south_guard_length,1.35,.12),"Stair B L3 east-edge connector south guardrail")

func _add_stair_side_rail(parent: Node3D, core: String, level: int, x: float, base: Vector3, rise: float, run: float, direction: float, landing_z: float, side: String) -> void:
	# Keep a clear portal at the lower landing, then guard the exposed flight up
	# to (but not across or beyond) the upper landing transfer edge.
	var portal_depth := 1.8
	var flight_start_z := landing_z-direction*portal_depth
	var upper_z := base.z-direction*run*.5
	var start_z := minf(flight_start_z,upper_z)
	var end_z := maxf(flight_start_z,upper_z)
	var ramp_z_span := -direction*run
	var start_t := clampf((start_z-landing_z)/ramp_z_span,0.0,1.0)
	var end_t := clampf((end_z-landing_z)/ramp_z_span,0.0,1.0)
	var slope_angle := atan((rise/run)*direction)
	var ramp_surface_offset := .1*cos(slope_angle)
	var start_surface_y := base.y+ramp_surface_offset+rise*start_t
	var end_surface_y := base.y+ramp_surface_offset+rise*end_t
	var segment_length := sqrt(pow(end_z-start_z,2)+pow(end_surface_y-start_surface_y,2))
	var rail := Node3D.new()
	rail.name = "Handrail "+core+" L%d %s sloped segment" % [level,side]
	rail.position = Vector3(x,(start_surface_y+end_surface_y)*.5+1.0,(start_z+end_z)*.5)
	rail.rotation.x = slope_angle
	parent.add_child(rail)
	_box(rail,"Top bar",Vector3.ZERO,Vector3(.08,.08,segment_length),mats.rail,true)
	# Posts stay vertical, begin just above the walk surface, and meet the sloped
	# bar at regular intervals instead of using a level handrail that floats low.
	var post_count := maxi(2,int(ceilf((end_z-start_z)/1.2))+1)
	for i in range(post_count):
		var t := float(i)/float(post_count-1)
		var z := lerpf(start_z,end_z,t)
		var ramp_t := clampf((z-landing_z)/ramp_z_span,0.0,1.0)
		var surface_y := base.y+ramp_surface_offset+rise*ramp_t
		_box(parent,"Handrail "+core+" L%d %s vertical post" % [level,side],Vector3(x,surface_y+.5,z),Vector3(.045,1.0,.045),mats.rail,true)

func _build_stage_and_yard() -> void:
	var yard := Node3D.new()
	yard.name = "SharedGroundOnlyCourtyard"
	add_child(yard)
	_box(yard,"Schoolyard paving",Vector3(0,-.16,12),Vector3(52,.32,45),mats.concrete,true)
	_add_schoolyard_grass(yard)
	# Stage centered on the north side facing the gate/south.
	_box(yard,"Stage platform",Vector3(0,.65,-11),Vector3(15,1.3,6),mats.wood,true)
	_box(yard,"Stage fascia",Vector3(0,1.05,-7.8),Vector3(14,.55,.2),mats.band)
	for i in range(6):
		_box(yard,"Stage step",Vector3(0,.12+float(i)*.12,-6.2-float(i)*.55),Vector3(5,.24,.52),mats.concrete,true)
	_box(yard,"Stage roof",Vector3(0,5.1,-12),Vector3(17,.28,7),mats.concrete)
	# Four posts bring the canopy down to the platform; the former isolated slab
	# read as a floating box from the courtyard.
	for post_x in [-7.8,7.8]:
		for post_z in [-15.1,-8.7]:
			_box(yard,"Stage canopy post",Vector3(post_x,2.55,post_z),Vector3(.32,5.1,.32),mats.concrete,true)
	# Keep this weathered diffuse local to the stage; tiling follows the broad
	# backdrop dimensions instead of stretching the 1K source across the wall.
	var stage_backdrop := _textured_mat(
		"Courtyard Stage Weathered Concrete",
		Color("#747875"),
		"res://assets/test_neh_school/polyhaven_horror/concrete_wall_003_diff_1k.jpg",
		.94
	)
	stage_backdrop.uv1_triplanar = false
	stage_backdrop.uv1_world_triplanar = false
	stage_backdrop.uv1_scale = Vector3(6.5,2.0,1.0)
	_box(yard,"Stage backdrop",Vector3(0,2.8,-14),Vector3(13,4,.25),stage_backdrop)
	_box(yard,"Stage aged curtain",Vector3(0,2.84,-13.81),Vector3(8.8,3.52,.08),mats.stage_fabric)
	for fold_x in [-3.5,-1.8,1.8,3.5]:
		_box(yard,"Stage curtain fold",Vector3(fold_x,2.84,-13.74),Vector3(.10,3.50,.07),mats.stage_fabric_fold)
	var stage_motto := Label3D.new()
	stage_motto.name = "Stage motto"
	stage_motto.text = "TIÊN HỌC LỄ · HẬU HỌC VĂN"
	stage_motto.font_size = 32
	stage_motto.pixel_size = .011
	stage_motto.modulate = Color("#d8b88d")
	stage_motto.position = Vector3(0,3.72,-13.69)
	yard.add_child(stage_motto)
	# A faint cool pool keeps the backdrop legible beneath the deep stage roof.
	_light(yard,Vector3(0,4.35,-10.3),Color("#9bb4c6"),1.0,8.0)
	for curtain_x in [-6.15,6.15]:
		_box(yard,"Stage faded side curtain",Vector3(curtain_x,2.68,-13.81),Vector3(.56,3.65,.09),mats.stage_fabric)
	# Circular low-poly fountain and the single Vietnamese flagpole.
	var fountain := CylinderMesh.new()
	fountain.top_radius=3.0; fountain.bottom_radius=3.2; fountain.height=.5; fountain.radial_segments=16
	var basin := MeshInstance3D.new(); basin.name="FountainBasin"; basin.mesh=fountain; basin.material_override=mats.concrete; basin.position=Vector3(0,.25,10); yard.add_child(basin)
	var basin_body := StaticBody3D.new()
	basin_body.name = "FountainBasinBody"
	basin_body.position = basin.position
	var basin_shape := CollisionShape3D.new()
	var basin_cylinder := CylinderShape3D.new()
	basin_cylinder.radius = 3.0
	basin_cylinder.height = .5
	basin_shape.shape = basin_cylinder
	basin_body.add_child(basin_shape)
	yard.add_child(basin_body)
	var water := CylinderMesh.new(); water.top_radius=2.65; water.bottom_radius=2.65; water.height=.12; water.radial_segments=16
	var water_mat := _mat("Dark Fountain Water",Color("#244456"),.35)
	var pool := MeshInstance3D.new(); pool.name="FountainWater"; pool.mesh=water; pool.material_override=water_mat; pool.position=Vector3(0,.54,10); yard.add_child(pool)
	_box(yard,"Flag pole",Vector3(0,5.6,10),Vector3(.12,10,.12),mats.metal,true)
	_box(yard,"Vietnam flag",Vector3(1.1,8.6,10),Vector3(2.0,1.25,.06),_mat("Vietnam Flag Red",Color("#8c1c21")))
	var flag_star := Label3D.new()
	flag_star.name = "Flag yellow star"
	flag_star.text = "★"
	flag_star.font_size = 48
	flag_star.pixel_size = .012
	flag_star.modulate = Color("#f2cf68")
	# Courtyard approach is from +Z: keep the star just in front of the flag face.
	flag_star.position = Vector3(1.1,8.6,10.04)
	yard.add_child(flag_star)
	# A continuous three-sided perimeter has physical rails/plinths; slim
	# pickets are intentionally visual-only to avoid hundreds of physics bodies.
	_build_perimeter_fence(yard)
	_box(yard,"Gate pillar west",Vector3(-2.7,1.7,34),Vector3(.75,3.4,.75),mats.concrete,true)
	_box(yard,"Gate pillar east",Vector3(2.7,1.7,34),Vector3(.75,3.4,.75),mats.concrete,true)
	_box(yard,"Main gate crossbeam",Vector3(0,3.42,34),Vector3(5.55,.3,.5),mats.concrete)
	_box(yard,"Main gate sign backing",Vector3(0,2.55,34.30),Vector3(4.7,.72,.12),mats.band)
	var gate_sign := Label3D.new()
	gate_sign.name = "Main gate outward-facing school name"
	gate_sign.text = "TRƯỜNG TRUNG HỌC PHỔ THÔNG"
	gate_sign.font_size = 23
	gate_sign.pixel_size = .009
	gate_sign.modulate = Color("#e9d5a2")
	gate_sign.position = Vector3(0,2.55,34.38)
	yard.add_child(gate_sign)
	for lantern_x in [-2.7,2.7]:
		_box(yard,"Gate lantern housing",Vector3(lantern_x,3.08,34.48),Vector3(.28,.22,.20),mats.warm)
		_light(yard,Vector3(lantern_x,2.95,34.68),Color("#f0c589"),.85,4.8)
	_add_gate_leaf(yard,"West iron gate leaf",-2.325,1.0)
	_add_gate_leaf(yard,"East iron gate leaf",2.325,-1.0)
	# Sparse planting and benches along the yard edge; no copies on upper levels.
	var tree_index := 0
	for x in [-21.0,-15.0,15.0,21.0]:
		var tree_scale: float = [1.0,.92,1.12,1.04][tree_index]
		_box(yard,"Planter",Vector3(x,.4,12),Vector3(1.8,.8,1.8),mats.concrete,true)
		_box(yard,"Planter soil",Vector3(x,.81,12),Vector3(1.58,.04,1.58),mats.wood)
		var trunk := CylinderMesh.new()
		trunk.top_radius = .12
		trunk.bottom_radius = .22
		trunk.height = 2.2*tree_scale
		trunk.radial_segments = 8
		var tree_trunk := MeshInstance3D.new()
		tree_trunk.name = "Courtyard tree trunk"
		tree_trunk.mesh = trunk
		tree_trunk.material_override = mats.wood
		tree_trunk.position = Vector3(x,.75+trunk.height*.5,12)
		yard.add_child(tree_trunk)
		var trunk_body := StaticBody3D.new()
		trunk_body.name = "Courtyard tree trunk body"
		trunk_body.position = tree_trunk.position
		var trunk_shape := CollisionShape3D.new()
		var trunk_cylinder := CylinderShape3D.new()
		trunk_cylinder.radius = .20
		trunk_cylinder.height = trunk.height
		trunk_shape.shape = trunk_cylinder
		trunk_body.add_child(trunk_shape)
		yard.add_child(trunk_body)
		for branch_side in [-1.0,1.0]:
			var branch_mesh := CylinderMesh.new()
			branch_mesh.top_radius = .055
			branch_mesh.bottom_radius = .095
			branch_mesh.height = 1.05
			branch_mesh.radial_segments = 6
			var branch := MeshInstance3D.new()
			branch.name = "Courtyard tree branch"
			branch.mesh = branch_mesh
			branch.material_override = mats.wood
			branch.position = Vector3(x+branch_side*.27,2.25*tree_scale,12)
			branch.rotation.z = -branch_side*.48
			yard.add_child(branch)
		for crown_data in [Vector3(0,3.35,0),Vector3(-.62,3.24,-.12),Vector3(.59,3.44,.16),Vector3(.13,3.02,.64)]:
			var crown := SphereMesh.new()
			crown.radius = (.94 if crown_data.x == 0.0 else .72)*tree_scale
			crown.height = (1.72 if crown_data.x == 0.0 else 1.38)*tree_scale
			crown.radial_segments = 8
			crown.rings = 5
			var foliage := MeshInstance3D.new()
			foliage.name = "LowPoly Tree Crown Cluster"
			foliage.mesh = crown
			foliage.material_override = mats.leaf_variation if (tree_index+int(crown_data.x*10.0))%3 == 0 else mats.leaf
			foliage.position = Vector3(x+crown_data.x*tree_scale,crown_data.y*tree_scale,12+crown_data.z*tree_scale)
			yard.add_child(foliage)
		tree_index += 1
	for bench_x in [-8.0,8.0]:
		_box(yard,"Courtyard bench seat",Vector3(bench_x,.52,6),Vector3(2.2,.14,.45),mats.wood,true)
		_box(yard,"Courtyard bench back",Vector3(bench_x,.88,6.18),Vector3(2.2,.65,.10),mats.wood)
		for leg_x in [-.90,.90]:
			_box(yard,"Courtyard bench support",Vector3(bench_x+leg_x,.23,6),Vector3(.10,.46,.28),mats.metal)
	for x in [-9.0,9.0]:
		_light(yard,Vector3(x,3,18),Color("#d3b584"),.8,6)

func _build_perimeter_fence(parent: Node3D) -> void:
	var iron := mats.metal as Material
	for side in [-1.0,1.0]:
		# Stop flush with the outside faces of the gate pillars; no invisible
		# barrier crosses the 4.65 m central entrance.
		var front_x: float = side * 15.05
		_box(parent,"Front fence masonry plinth",Vector3(front_x,.23,34),Vector3(23.90,.46,.28),mats.concrete,true)
		for rail_y in [.72,1.10,1.82]:
			_box(parent,"Front fence horizontal rail",Vector3(front_x,rail_y,34),Vector3(23.90,.09,.10),iron,true)
		for post_index in range(13):
			var x: float = side*(3.35+float(post_index)*1.93)
			_box(parent,"Front fence picket",Vector3(x,1.34,34),Vector3(.06,1.55,.07),iron)
		# The side fences run from each wing's south corner to the front line.
		# Their short north returns meet the building without sealing a gallery.
		var side_x: float = side*27.0
		_box(parent,"Side fence masonry plinth",Vector3(side_x,.23,20),Vector3(.28,.46,28.0),mats.concrete,true)
		for rail_y in [.72,1.10,1.82]:
			_box(parent,"Side fence horizontal rail",Vector3(side_x,rail_y,20),Vector3(.10,.09,28.0),iron,true)
		for post_index in range(15):
			_box(parent,"Side fence picket",Vector3(side_x,1.34,6.25+float(post_index)*1.96),Vector3(.07,1.55,.06),iron)
		_box(parent,"Fence to wing return plinth",Vector3(side*25.5,.23,6),Vector3(3.0,.46,.28),mats.concrete,true)
		for rail_y in [.72,1.10,1.82]:
			_box(parent,"Fence to wing return rail",Vector3(side*25.5,rail_y,6),Vector3(3.0,.09,.10),iron,true)

func _add_schoolyard_grass(parent: Node3D) -> void:
	# Two narrow planting verges stay outside the gate-to-stage axis. One
	# MultiMesh keeps the small grass tufts from becoming hundreds of draw nodes.
	for side in [-1.0,1.0]:
		_box(parent,"Courtyard planted verge",Vector3(side*24.1,.025,12),Vector3(1.3,.05,31),mats.soil)
	var blade_mesh := ArrayMesh.new()
	var vertices := PackedVector3Array([
		Vector3(-.055,0,0),Vector3(0,.31,0),Vector3(.055,0,0),
		Vector3(-.03,0,-.05),Vector3(0,.25,0),Vector3(.03,0,.05),
		Vector3(-.03,0,.05),Vector3(0,.36,0),Vector3(.03,0,-.05),
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	blade_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var grass_material := (mats.grass as StandardMaterial3D).duplicate() as StandardMaterial3D
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade_mesh.surface_set_material(0,grass_material)
	var placements: Array[Transform3D] = []
	for side in [-1.0,1.0]:
		for row in range(3):
			for i in range(70):
				var z := -3.0+float(i)*.43+float((i*7+row*3)%7)*.025
				var size := .58+float((i*11+row*5)%9)*.07
				var basis := Basis(Vector3.UP,float(i*13+row*17)*.37).scaled(Vector3(size,size,size))
				var x: float = float(side)*(23.57+float(row)*.38+float((i*19+row*7)%5)*.025)
				placements.append(Transform3D(basis,Vector3(x,.05,z)))
	for tree_x in [-21.0,-15.0,15.0,21.0]:
		for tuft in range(8):
			var angle := TAU*float(tuft)/8.0
			var basis := Basis(Vector3.UP,angle).scaled(Vector3(.75,.75,.75))
			placements.append(Transform3D(basis,Vector3(tree_x+cos(angle)*.58,.84,12+sin(angle)*.58)))
	var grass_instances := MultiMesh.new()
	grass_instances.transform_format = MultiMesh.TRANSFORM_3D
	grass_instances.mesh = blade_mesh
	grass_instances.instance_count = placements.size()
	for index in range(placements.size()):
		grass_instances.set_instance_transform(index,placements[index])
	var grass_cluster := MultiMeshInstance3D.new()
	grass_cluster.name = "Courtyard verge and planter grass"
	grass_cluster.multimesh = grass_instances
	parent.add_child(grass_cluster)

func _add_gate_leaf(parent: Node3D, label: String, hinge_x: float, inward_sign: float) -> void:
	var leaf := Node3D.new()
	leaf.name = label
	leaf.position = Vector3(hinge_x,0,34)
	leaf.rotation.y = inward_sign * PI / 3.0
	parent.add_child(leaf)
	var width := 2.2
	var iron := mats.metal as Material
	for rail_y in [.12,1.1,2.08]:
		_box(leaf,label+" horizontal rail",Vector3(inward_sign*width*.5,rail_y,0),Vector3(width,.08,.07),iron)
	for edge in [0.0,width]:
		_box(leaf,label+" side stile",Vector3(inward_sign*edge,1.1,0),Vector3(.08,2.1,.07),iron)
	for index in range(1,10):
		var x := inward_sign*width*float(index)/10.0
		_box(leaf,label+" vertical bar",Vector3(x,1.1,0),Vector3(.035,1.82,.035),iron)

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name="WorldFoundation"
	var plane := PlaneMesh.new(); plane.size=Vector2(90,100)
	ground.mesh=plane; ground.material_override=mats.concrete; ground.position=Vector3(0,-.38,10); add_child(ground)
	var body := StaticBody3D.new(); body.position=Vector3(0,-.55,10)
	var col:=CollisionShape3D.new(); var shape:=BoxShape3D.new(); shape.size=Vector3(90,.3,100); col.shape=shape; body.add_child(col); add_child(body)

func _build_rooftop() -> void:
	var roof := Node3D.new(); roof.name="Rooftop"; roof.position.y=LEVELS*FLOOR_HEIGHT; add_child(roof)
	var roof_holes: Array[Rect2]=[]
	for core_x in [-21.0,0.0,21.0]:
		# Clear the entire final stair flight through both the north roof bar and
		# the overlapping side-wing slabs; the top landing itself fills this slot.
		roof_holes.append(Rect2(core_x-2.5,-27.0,5.0,9.0))
	_floor_with_openings(roof,"North roof walk",Vector3(0,0,-25.75),Vector2(48,9.5),0.0,roof_holes,mats.concrete)
	_floor_with_openings(roof,"West roof walk",Vector3(-18,0,-8),Vector2(12,28),0.0,roof_holes,mats.concrete)
	_floor_with_openings(roof,"East roof walk",Vector3(18,0,-8),Vector2(12,28),0.0,roof_holes,mats.concrete)
	# Guard the sides and south ends of roof-level cutouts. The north ends remain
	# open so each stair's full-width landing can discharge onto the roof walk.
	for core_x in [-21.0,0.0,21.0]:
		var wing_core := absf(core_x) > 1.0
		var south_edge_z := -18.0 if wing_core else -21.0
		var rail_start_z := -24.1
		var rail_length := south_edge_z-rail_start_z
		_rail(roof,Vector3(core_x-2.55,.85,rail_start_z+rail_length*.5),Vector3(.12,1.5,rail_length),"Roof stairwell guard "+str(core_x)+" west")
		_rail(roof,Vector3(core_x+2.55,.85,rail_start_z+rail_length*.5),Vector3(.12,1.5,rail_length),"Roof stairwell guard "+str(core_x)+" east")
		_rail(roof,Vector3(core_x,.85,south_edge_z),Vector3(5.0,1.5,.12),"Roof stairwell guard "+str(core_x)+" south")
		# A light portal frame identifies each stair exit but stays visual-only and
		# leaves a wide, unobstructed opening aligned to the final stair lane.
		var exit_lane_x: float = float(core_x) - 1.2
		var exit_z: float = -25.5
		for side in [-1.0,1.0]:
			_box(roof,"Stair exit "+str(core_x)+" portal pier",Vector3(exit_lane_x+side*1.2,1.30,exit_z),Vector3(.14,2.60,.16),mats.concrete)
		_box(roof,"Stair exit "+str(core_x)+" portal head",Vector3(exit_lane_x,2.63,exit_z),Vector3(2.54,.16,.16),mats.band)
		var exit_mark := Label3D.new()
		exit_mark.name = "Stair exit marker " + str(core_x)
		exit_mark.text = "A" if core_x < -1.0 else ("C" if core_x > 1.0 else "B")
		exit_mark.font_size = 20
		exit_mark.pixel_size = .01
		exit_mark.modulate = Color("#d0c6ad")
		exit_mark.outline_size = 1
		exit_mark.outline_modulate = Color("#17232a")
		exit_mark.position = Vector3(exit_lane_x,2.63,exit_z+.10)
		exit_mark.rotation.y = 0.0
		roof.add_child(exit_mark)
	# Keep the central roof/lightwell open and add safety parapet rails on exposed edges.
	_rail(roof,Vector3(-18,.85,6),Vector3(12,1.5,.12),"West roof safety rail")
	_rail(roof,Vector3(18,.85,6),Vector3(12,1.5,.12),"East roof safety rail")
	_rail(roof,Vector3(0,.85,-30.5),Vector3(48,1.5,.12),"North roof safety rail")
	_rail(roof,Vector3(-24,.85,-11.75),Vector3(.12,1.5,37.5),"West outer roof safety rail")
	_rail(roof,Vector3(24,.85,-11.75),Vector3(.12,1.5,37.5),"East outer roof safety rail")
	_rail(roof,Vector3(-12,.85,-8),Vector3(.12,1.5,28),"West atrium roof safety rail")
	_rail(roof,Vector3(12,.85,-8),Vector3(.12,1.5,28),"East atrium roof safety rail")
	_rail(roof,Vector3(0,.85,-20.5),Vector3(24,1.5,.12),"North atrium roof safety rail")
	# Level 3's three stair landings already connect to these open roof walks.

func _build_player() -> void:
	player = PLAYER_SCRIPT.new() as HoangController3D
	player.name="HoangPlayer"
	player.position=Vector3(0,0,29)
	player.controls_enabled=true
	player.camera_yaw=0.0
	add_child(player)
	player.call_deferred("_apply_camera_rotation")

func _setup_input() -> void:
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
			var key := InputEventKey.new()
			key.keycode = keycode
			InputMap.action_add_event(action,key)

func _light(parent: Node3D, at: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var lamp:=OmniLight3D.new(); lamp.position=at; lamp.light_color=color; lamp.light_energy=energy; lamp.omni_range=radius; lamp.shadow_enabled=false; parent.add_child(lamp); return lamp
