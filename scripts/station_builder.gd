extends Node3D

# Builds the station props and simple interconnect runs inside the central room only.
const L = preload("res://scripts/station_layout.gd")
const CORNER_TANK_ASSET := "res://assets/oxygen_tanks_pair.glb"

var _counts := {"fixtures": 0, "real_lights": 0, "pipe_segments": 0, "cable_segments": 0}
var _report := []

func _ready() -> void:
	_build_all()
	print("[station_builder] counts=", _counts)
	for entry in _report:
		print("[station_builder] ", entry)

func _build_all() -> void:
	_add_opening_walls()
	_add_tank_assemblies()
	_add_power_screen()
	_add_bed()
	_add_storage_and_cabinet()
	_add_greenhouse()
	_add_operations_wall()
	_add_life_support_details()
	_add_habitation_details()
	_add_system_junctions_and_status()
	_add_caution_markings()
	_add_microgravity_fittings()
	_add_access_hatches_and_floor_plates()
	_add_suit_rack()
	_add_accent_lighting()
	_add_roof()
	_add_station_structure()
	_add_fixtures()
	_add_green_pipes()
	_add_blue_cables()
	var life_support := Node3D.new()
	life_support.name = "LifeSupportEquipment"
	life_support.set_script(preload("res://scripts/life_support_visuals.gd"))
	add_child(life_support)

func _get_group(group_name: String) -> Node3D:
	var group := get_node_or_null(group_name) as Node3D
	if group == null:
		group = Node3D.new()
		group.name = group_name
		add_child(group)
	return group

func _add_greenhouse() -> void:
	var rack := Node3D.new()
	rack.name = "HydroponicGrowRack"
	rack.position = Vector3(-8.55, 0.0, -4.6)
	_make_interactable(rack, "greenhouse", "Lunar hydroponic grow rack")
	_add_box_collision(rack, Vector3(1.0, 2.4, 1.65), Vector3(0, 1.2, 0))
	var visuals := Node3D.new()
	visuals.set_script(preload("res://scripts/greenhouse_visuals.gd"))
	rack.add_child(visuals)
	_get_group("Greenhouse").add_child(rack)

func _load_mesh_from_scene(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		_report.append("MISSING asset: %s" % path)
		return null
	var packed: Resource = load(path)
	if not packed is PackedScene:
		return null
	var instance: Node = (packed as PackedScene).instantiate()
	var mesh_instance := _find_mesh_instance(instance)
	var mesh: Mesh = mesh_instance.mesh if mesh_instance != null else null
	instance.free()
	return mesh

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null

func _instance_asset(path: String, scale_value: Vector3, yaw_degrees: float) -> Node3D:
	if not ResourceLoader.exists(path):
		_report.append("MISSING asset: %s" % path)
		return Node3D.new()
	var packed := load(path) as PackedScene
	if packed == null:
		_report.append("FAILED load: %s" % path)
		return Node3D.new()
	var instance := packed.instantiate() as Node3D
	if instance != null:
		instance.scale = scale_value
		instance.rotation_degrees.y = yaw_degrees
	return instance

func _make_interactable(node: Node3D, kind: String, label: String) -> void:
	var target_script := load("res://scripts/interaction_target.gd")
	if target_script == null:
		_report.append("FAILED load: res://scripts/interaction_target.gd")
		return
	node.set_script(target_script)
	node.set("interaction_type", kind)
	node.set("display_name", label)

func _add_box_collision(parent: Node3D, size: Vector3, local_position: Vector3 = Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = local_position
	body.add_child(shape_node)
	parent.add_child(body)

func _add_opening_walls() -> void:
	var group := _get_group("OpeningBlockers")
	var wall_material := load("res://materials/wall_greige.tres") as Material
	var room_height := L.CEILING_HEIGHT
	var wall_thickness := 0.45
	var opening_width := 4.5
	var wall_line := 9.72
	var barriers := [
		{"name": "NorthOpeningWall", "position": Vector3(0, room_height * 0.5, -wall_line), "size": Vector3(opening_width, room_height, wall_thickness)},
		{"name": "SouthOpeningWall", "position": Vector3(0, room_height * 0.5, wall_line), "size": Vector3(opening_width, room_height, wall_thickness)},
		{"name": "EastOpeningWall", "position": Vector3(wall_line, room_height * 0.5, 0), "size": Vector3(wall_thickness, room_height, opening_width)},
		{"name": "WestOpeningWall", "position": Vector3(-wall_line, room_height * 0.5, 0), "size": Vector3(wall_thickness, room_height, opening_width)},
	]
	for barrier in barriers:
		var body := StaticBody3D.new()
		body.name = barrier.name
		body.position = barrier.position
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = barrier.size
		shape_node.shape = shape
		body.add_child(shape_node)
		var visual := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = barrier.size
		visual.mesh = box
		visual.material_override = wall_material
		body.add_child(visual)
		group.add_child(body)

func _add_tank_assemblies() -> void:
	var group := _get_group("TankAssemblies")
	# The main connected pair is centred on the north wall. Smaller cylinder pairs occupy the four corners.
	var main_scale := Vector3(2.2, 2.2, 2.2)
	var main := _instance_asset(L.ASSET_TANK_ASSEMBLY, main_scale, 0.0)
	main.name = "HydrogenVessel"
	var main_size := Vector3(0.498, 0.998, 0.5605) * main_scale
	var assembly := Node3D.new()
	assembly.name = "MainGasPair"
	assembly.position = Vector3(-3.2, main_size.y * 0.5, -8.80)
	main.position.x = -0.70
	assembly.add_child(main)
	var oxygen := _instance_asset(L.ASSET_TANK_ASSEMBLY, main_scale, 0.0)
	oxygen.name = "OxygenVessel"
	oxygen.position.x = 0.70
	assembly.add_child(oxygen)
	_make_interactable(assembly, "oxygen", "Hydrogen and oxygen supply")
	_add_box_collision(assembly, main_size, Vector3(-0.70, 0, 0))
	_add_box_collision(assembly, main_size, Vector3(0.70, 0, 0))
	group.add_child(assembly)

	var corner_scale := Vector3(0.68, 0.68, 0.68)
	var corner_size := Vector3(0.498, 0.998, 0.5605) * corner_scale
	var corners := [
		{"name": "OxygenCornerNW", "position": Vector3(-8.65, 0.0, -9.30), "yaw": 0.0},
		{"name": "OxygenCornerNE", "position": Vector3(8.65, 0.0, -9.30), "yaw": 0.0},
		{"name": "OxygenCornerSE", "position": Vector3(8.65, 0.0, 9.30), "yaw": 180.0},
		{"name": "OxygenCornerSW", "position": Vector3(-8.65, 0.0, 9.30), "yaw": 180.0},
	]
	for corner in corners:
		var tank := _instance_asset(CORNER_TANK_ASSET, corner_scale, corner.yaw)
		tank.name = corner.name
		tank.position = Vector3(corner.position.x, corner_size.y * 0.5, corner.position.z)
		_make_interactable(tank, "oxygen", "Corner oxygen tanks")
		_add_box_collision(tank, corner_size)
		group.add_child(tank)

func _add_power_screen() -> void:
	var group := _get_group("PowerScreen")
	var screen := _instance_asset(L.ASSET_POWER_SCREEN, L.POWER_SCREEN_SCALE, 90.0)
	screen.name = "StationDataScreen"
	screen.position = Vector3(0.0, 2.25, 9.372)
	_make_interactable(screen, "power_screen", "Station data screen")
	_add_box_collision(screen, Vector3(0.20, 1.05, 2.0))
	group.add_child(screen)

func _add_bed() -> void:
	var group := _get_group("Bed")
	var bed := _instance_asset(L.ASSET_BED, L.BED_SCALE, 270.0)
	bed.name = "SleepingBerth"
	bed.position = Vector3(8.95, 0.35, 2.0)
	_make_interactable(bed, "bed", "Sleeping berth")
	_add_box_collision(bed, Vector3(2.0, 0.7, 1.0))
	group.add_child(bed)

func _add_storage_and_cabinet() -> void:
	var storage_group := _get_group("StorageContainer")
	var cabinet_group := _get_group("Cabinet")
	var storage := _instance_asset(L.ASSET_STORAGE_CONTAINER, L.STORAGE_SCALE, 90.0)
	storage.name = "StationStorageContainer"
	storage.position = Vector3(-9.09, 0.4, -2.0)
	_make_interactable(storage, "container", "Storage container")
	_add_box_collision(storage, Vector3(1.0, 0.85, 0.822))
	storage_group.add_child(storage)

	# This model's doors face +X at zero yaw, into the room from the west wall.
	var cabinet := _instance_asset(L.ASSET_CABINET, L.CABINET_SCALE, 0.0)
	cabinet.name = "StationCabinet"
	cabinet.position = Vector3(-8.60, 2.13, -2.0)
	_make_interactable(cabinet, "food", "Food supplies cabinet")
	_add_box_collision(cabinet, Vector3(1.2, 2.35, 1.8))
	cabinet_group.add_child(cabinet)
	_add_zone_label(cabinet_group, "FOOD SUPPLIES", Vector3(-7.99, 3.55, -2.0), 90.0)

func _add_box_piece(parent: Node3D, piece_name: String, position: Vector3, size: Vector3, material: Material, collidable: bool = false) -> Node3D:
	var piece: Node3D = StaticBody3D.new() if collidable else Node3D.new()
	piece.name = piece_name
	piece.position = position
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	visual.mesh = box
	visual.material_override = material
	piece.add_child(visual)
	if collidable:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		piece.add_child(collision)
	parent.add_child(piece)
	return piece

func _add_zone_label(parent: Node3D, text: String, position: Vector3, yaw: float) -> void:
	var label := Label3D.new()
	label.name = text.replace(" ", "") + "Sign"
	label.text = text
	label.position = position
	label.rotation_degrees.y = yaw
	label.font_size = 64
	label.pixel_size = 0.003
	label.modulate = Color(0.86, 0.81, 0.67)
	label.outline_size = 5
	label.outline_modulate = Color(0.12, 0.15, 0.14)
	parent.add_child(label)

func _add_operations_wall() -> void:
	var group := _get_group("OperationsZone")
	var trim := load("res://materials/trim_panels.tres") as Material
	var beige := load("res://materials/wall_greige.tres") as Material
	var crt := load("res://materials/screen_crt.tres") as Material
	# Backing panel and frame make the existing large display read as a work station.
	_add_box_piece(group, "ConsoleWallPanel", Vector3(0, 2.15, 9.42), Vector3(4.35, 3.25, 0.08), trim)
	_add_box_piece(group, "ConsoleFrameTop", Vector3(0, 3.84, 9.34), Vector3(4.5, 0.09, 0.08), beige)
	_add_box_piece(group, "ConsoleFrameLeft", Vector3(-2.2, 2.15, 9.34), Vector3(0.09, 3.3, 0.08), beige)
	_add_box_piece(group, "ConsoleFrameRight", Vector3(2.2, 2.15, 9.34), Vector3(0.09, 3.3, 0.08), beige)
	# Accessible standing console below the screen.
	_add_box_piece(group, "ConsoleBody", Vector3(0, 0.46, 8.72), Vector3(3.7, 0.92, 0.72), beige, true)
	_add_box_piece(group, "ConsoleTop", Vector3(0, 0.96, 8.72), Vector3(3.9, 0.12, 0.82), trim, true)
	_add_box_piece(group, "ConsoleStatusStrip", Vector3(0, 0.56, 8.345), Vector3(2.8, 0.32, 0.035), crt)
	_add_box_piece(group, "ConsoleKeyboard", Vector3(0, 1.035, 8.51), Vector3(1.15, 0.025, 0.32), crt)
	for side in [-1.0, 1.0]:
		var display := _instance_asset(L.ASSET_POWER_SCREEN, Vector3(0.58, 0.58, 0.58), 90.0)
		display.name = "AuxPowerDisplay_%s" % ("L" if side < 0 else "R")
		display.position = Vector3(side * 1.45, 1.62, 9.355)
		_make_interactable(display, "power_screen", "Auxiliary station display")
		_add_box_collision(display, Vector3(0.08, 0.34, 0.62))
		group.add_child(display)
	# Emissive screen face and simple power bars make the existing blank display read as live equipment.
	var screen_surface := StandardMaterial3D.new()
	screen_surface.albedo_color = Color(0.025, 0.075, 0.10)
	screen_surface.emission_enabled = true
	screen_surface.emission = Color(0.015, 0.08, 0.13)
	screen_surface.emission_energy_multiplier = 0.45
	_add_box_piece(group, "PowerScreenActiveFace", Vector3(0, 2.25, 9.265), Vector3(1.62, 0.76, 0.025), screen_surface)
	var ochre := load("res://materials/accent_ochre.tres") as Material
	_add_box_piece(group, "PowerGraphBaseline", Vector3(0, 1.99, 9.235), Vector3(1.32, 0.025, 0.025), ochre)
	var bar_heights := [0.18, 0.30, 0.23, 0.38, 0.27]
	for index in range(bar_heights.size()):
		var height: float = bar_heights[index]
		_add_box_piece(group, "PowerGraphBar_%d" % index, Vector3(-0.48 + index * 0.24, 2.00 + height * 0.5, 9.23), Vector3(0.10, height, 0.025), ochre)
	_add_zone_label(group, "OPERATIONS  /  POWER", Vector3(-1.35, 3.68, 9.30), 180.0)
	_add_detailed_telemetry_array(group)

func _add_detailed_telemetry_array(group: Node3D) -> void:
	var trim := load("res://materials/trim_panels.tres") as Material
	var beige := load("res://materials/wall_greige.tres") as Material
	var crt := load("res://materials/screen_crt.tres") as Material
	var metal := _brushed_metal_material() as Material
	var teal_glow := _emissive_material(Color("#65c7cc"))
	var gold_glow := _emissive_material(Color("#d8b56c"))
	var green_glow := _emissive_material(Color("#4fd18b"))

	# 1. Deep-Space Network Server Rack (Left of Operations Console, x = -3.35, z = 8.92)
	var rack_x := -3.35
	_add_box_piece(group, "DSNServerRackCabinet", Vector3(rack_x, 1.15, 8.95), Vector3(0.95, 2.30, 0.72), trim, true)
	for blade in range(6):
		var by := 0.35 + blade * 0.32
		_add_box_piece(group, "ServerBlade_%d" % blade, Vector3(rack_x, by, 8.58), Vector3(0.82, 0.22, 0.04), beige)
		_add_status_lamp(group, "BladeLED_A_%d" % blade, Vector3(rack_x - 0.30, by, 8.55), Color("#4fd18b") if blade % 2 == 0 else Color("#65c7cc"))
		_add_status_lamp(group, "BladeLED_B_%d" % blade, Vector3(rack_x - 0.18, by, 8.55), Color("#d8b56c"))
	var rack_label := Label3D.new()
	rack_label.name = "DSNRackLabel"
	rack_label.text = "DSN TELEMETRY RACK\nS/X-BAND CORRELATOR"
	rack_label.position = Vector3(rack_x, 2.52, 8.85)
	rack_label.rotation_degrees.y = 180.0
	rack_label.font_size = 20
	rack_label.pixel_size = 0.005
	rack_label.modulate = Color("#65c7cc")
	group.add_child(rack_label)

	# 2. Oscilloscope & Dish Slew Control Deck (Right of Operations Console, x = 3.35, z = 8.92)
	var desk_x := 3.35
	_add_box_piece(group, "AstrometryDeskBase", Vector3(desk_x, 0.46, 8.85), Vector3(1.45, 0.92, 0.76), beige, true)
	_add_box_piece(group, "AstrometryDeskTop", Vector3(desk_x, 0.95, 8.85), Vector3(1.55, 0.08, 0.84), trim, true)
	# Dual angled waveform monitors on the astrometry desk
	for m_idx in [-1.0, 1.0]:
		var mx: float = desk_x + float(m_idx) * 0.38
		_add_box_piece(group, "ScopeHousing_%s" % str(m_idx), Vector3(mx, 1.24, 8.96), Vector3(0.62, 0.46, 0.26), trim)
		_add_box_piece(group, "ScopeScreen_%s" % str(m_idx), Vector3(mx, 1.24, 8.82), Vector3(0.54, 0.36, 0.02), crt)
		_add_box_piece(group, "ScopeWaveTrace_%s" % str(m_idx), Vector3(mx, 1.24, 8.805), Vector3(0.46, 0.025, 0.01), teal_glow if m_idx < 0.0 else gold_glow)
	# Dish Azimuth / Elevation handwheel dials on desk surface
	for dial_idx in [-1.0, 1.0]:
		var dx: float = desk_x + float(dial_idx) * 0.28
		_add_cylinder_piece(group, "DishSlewDial_%s" % str(dial_idx), Vector3(dx, 1.02, 8.62), 0.11, 0.05, metal)
		_add_status_lamp(group, "DishLockLamp_%s" % str(dial_idx), Vector3(dx, 1.04, 8.50), Color("#4fd18b"))

	# Make the Astrometry Desk directly open the Science / Data Collection tab!
	var science_station := Node3D.new()
	science_station.name = "AstrometryWorkstation"
	science_station.position = Vector3(desk_x, 1.15, 8.85)
	group.add_child(science_station)
	_make_interactable(science_station, "power_screen", "Deep-Space Astrometry Workstation")
	_add_box_collision(science_station, Vector3(1.55, 1.35, 0.85))
	var astro_label := Label3D.new()
	astro_label.name = "AstrometryLabel"
	astro_label.text = "DEEP-SPACE RADAR ARRAY\nDISH SLEW & DOPPLER LOCK"
	astro_label.position = Vector3(desk_x, 1.85, 8.85)
	astro_label.rotation_degrees.y = 180.0
	astro_label.font_size = 20
	astro_label.pixel_size = 0.005
	astro_label.modulate = Color("#d8b56c")
	group.add_child(astro_label)

	# 3. Dish Pointing Joy-Stick & Radar Lock Beacon on the central console top
	_add_cylinder_piece(group, "ConsoleRadarJoystickBase", Vector3(-1.05, 1.03, 8.55), 0.09, 0.04, trim)
	_add_cylinder_piece(group, "ConsoleRadarJoystickShaft", Vector3(-1.05, 1.12, 8.55), 0.02, 0.16, metal)
	_add_status_lamp(group, "ConsoleRadarJoystickTip", Vector3(-1.05, 1.21, 8.55), Color("#65c7cc"))
	_add_box_piece(group, "ConsoleTelemetryPad", Vector3(1.05, 1.035, 8.55), Vector3(0.55, 0.03, 0.34), green_glow)

func _add_life_support_details() -> void:
	var group := _get_group("LifeSupportZone")
	var panel := _instance_asset("res://assets/oxygen_control_panel.glb", Vector3(0.62, 0.62, 0.62), 270.0)
	panel.name = "LifeSupportControlPanel"
	panel.position = Vector3(-1.25, 1.62, -9.37)
	_make_interactable(panel, "oxygen", "Life support control panel")
	_add_box_collision(panel, Vector3(0.64, 0.56, 0.24))
	group.add_child(panel)
	var trim := load("res://materials/trim_panels.tres") as Material
	var crt := load("res://materials/screen_crt.tres") as Material
	var gauge_frame := MeshInstance3D.new()
	gauge_frame.name = "OxygenPressureGaugeFrame"
	var frame_mesh := CylinderMesh.new()
	frame_mesh.top_radius = 0.19
	frame_mesh.bottom_radius = 0.19
	frame_mesh.height = 0.075
	frame_mesh.radial_segments = 24
	gauge_frame.mesh = frame_mesh
	gauge_frame.material_override = trim
	gauge_frame.position = Vector3(-0.25, 1.62, -9.37)
	gauge_frame.rotation_degrees.x = 90.0
	group.add_child(gauge_frame)
	var gauge_face := MeshInstance3D.new()
	gauge_face.name = "OxygenPressureGaugeFace"
	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = 0.135
	face_mesh.bottom_radius = 0.135
	face_mesh.height = 0.08
	face_mesh.radial_segments = 24
	gauge_face.mesh = face_mesh
	gauge_face.material_override = crt
	gauge_face.position = Vector3(-0.25, 1.62, -9.315)
	gauge_face.rotation_degrees.x = 90.0
	group.add_child(gauge_face)
	_add_zone_label(group, "LIFE SUPPORT", Vector3(-2.65, 3.63, -9.32), 0.0)

func _add_habitation_details() -> void:
	var group := _get_group("HabitationStorageDetails")
	var trim := load("res://materials/trim_panels.tres") as Material
	var beige := load("res://materials/wall_greige.tres") as Material
	# Small side table and a compact bench make the berth read as a lived-in area.
	_add_box_piece(group, "BedsideTableTop", Vector3(7.72, 0.58, 1.15), Vector3(0.62, 0.10, 0.62), trim, true)
	for x in [-0.23, 0.23]:
		for z in [-0.23, 0.23]:
			_add_box_piece(group, "BedsideTableLeg", Vector3(7.72 + x, 0.29, 1.15 + z), Vector3(0.07, 0.58, 0.07), beige, true)
	_add_box_piece(group, "HabitationBenchSeat", Vector3(6.55, 0.27, 4.0), Vector3(1.65, 0.48, 0.58), trim, true)
	_add_box_piece(group, "HabitationBenchBack", Vector3(6.55, 0.69, 4.26), Vector3(1.65, 0.48, 0.10), beige, true)
	_add_pearl_cat(group)
	_add_berna_comms_terminal(group)
	# Two smaller copies of the existing cabinet asset read as wall lockers.
	for index in range(2):
		var locker := _instance_asset(L.ASSET_CABINET, Vector3(1.15, 1.15, 1.15), 90.0)
		locker.name = "WallLocker_%d" % (index + 1)
		locker.position = Vector3(-9.06, 0.575, 1.1 + index * 2.1)
		_make_interactable(locker, "cabinet", "Wall locker")
		_add_box_collision(locker, Vector3(0.58, 1.15, 0.88))
		group.add_child(locker)
	# A pair of scaled copies of the existing container asset form a compact crate stack.
	for index in range(2):
		var crate := _instance_asset(L.ASSET_STORAGE_CONTAINER, Vector3(0.62, 0.62, 0.62), 90.0)
		crate.name = "SupplyCrate_%d" % (index + 1)
		crate.position = Vector3(-9.24, 0.165, -3.15 - index * 0.68)
		_make_interactable(crate, "container", "Supply crate")
		_add_box_collision(crate, Vector3(0.62, 0.34, 0.52))
		group.add_child(crate)
	_add_zone_label(group, "HABITAT", Vector3(9.26, 3.55, 1.2), 270.0)
	_add_zone_label(group, "STOWAGE", Vector3(-9.26, 3.55, -2.2), 90.0)

func _add_pearl_cat(parent: Node3D) -> void:
	var cat := Node3D.new()
	cat.name = "PearlTheCat"
	cat.position = Vector3(6.55, 0.56, 3.98)
	parent.add_child(cat)
	_make_interactable(cat, "cat", "Pearl the Cat")
	_add_box_collision(cat, Vector3(0.55, 0.45, 0.45), Vector3(0, 0.15, 0))
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.92, 0.89, 0.84)
	fur.roughness = 0.75
	var eyes := _emissive_material(Color(0.35, 0.88, 0.72))
	_add_box_piece(cat, "Body", Vector3(0, 0.11, 0), Vector3(0.36, 0.20, 0.22), fur)
	_add_box_piece(cat, "Head", Vector3(-0.18, 0.22, 0), Vector3(0.18, 0.16, 0.18), fur)
	_add_box_piece(cat, "EarL", Vector3(-0.20, 0.32, -0.06), Vector3(0.05, 0.07, 0.04), fur)
	_add_box_piece(cat, "EarR", Vector3(-0.20, 0.32, 0.06), Vector3(0.05, 0.07, 0.04), fur)
	_add_box_piece(cat, "EyeL", Vector3(-0.275, 0.24, -0.05), Vector3(0.02, 0.03, 0.03), eyes)
	_add_box_piece(cat, "EyeR", Vector3(-0.275, 0.24, 0.05), Vector3(0.02, 0.03, 0.03), eyes)
	_add_box_piece(cat, "Tail", Vector3(0.22, 0.16, 0), Vector3(0.18, 0.05, 0.05), fur)
	var tag := Label3D.new()
	tag.name = "PearlLabel"
	tag.text = "PEARL"
	tag.position = Vector3(0, 0.48, 0)
	tag.font_size = 22
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("#e7edf0")
	cat.add_child(tag)

func _add_berna_comms_terminal(parent: Node3D) -> void:
	var comms := Node3D.new()
	comms.name = "BernaCommsTerminal"
	comms.position = Vector3(7.72, 0.68, 1.15)
	parent.add_child(comms)
	_make_interactable(comms, "comms", "Earth Relay / Berna Comms")
	_add_box_collision(comms, Vector3(0.50, 0.42, 0.50), Vector3(0, 0.12, 0))
	var crt := load("res://materials/screen_crt.tres") as Material
	var trim := load("res://materials/trim_panels.tres") as Material
	_add_box_piece(comms, "Base", Vector3(0, 0.03, 0), Vector3(0.34, 0.05, 0.28), trim)
	_add_box_piece(comms, "Screen", Vector3(0, 0.16, 0), Vector3(0.06, 0.24, 0.32), crt)
	var tag := Label3D.new()
	tag.name = "CommsLabel"
	tag.text = "EARTH COMMS · BERNA"
	tag.position = Vector3(0, 0.40, 0)
	tag.font_size = 20
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color("#d8b56c")
	comms.add_child(tag)

func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.25
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _brushed_metal_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.48, 0.55, 0.57)
	material.metallic = 0.68
	material.roughness = 0.34
	return material

func _add_status_lamp(parent: Node3D, lamp_name: String, position: Vector3, color: Color) -> void:
	var lamp := MeshInstance3D.new()
	lamp.name = lamp_name
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	sphere.radial_segments = 12
	sphere.rings = 6
	lamp.mesh = sphere
	lamp.material_override = _emissive_material(color)
	lamp.position = position
	parent.add_child(lamp)

func _add_junction_box(parent: Node3D, junction_name: String, position: Vector3, rotation_y: float = 0.0) -> void:
	var trim := load("res://materials/trim_panels.tres") as Material
	var beige := load("res://materials/wall_greige.tres") as Material
	var box := _add_box_piece(parent, junction_name, position, Vector3(0.30, 0.24, 0.14), trim)
	box.rotation_degrees.y = rotation_y
	_add_box_piece(parent, junction_name + "Lid", position + Vector3(0, 0, -0.085), Vector3(0.23, 0.17, 0.035), beige)
	_add_status_lamp(parent, junction_name + "LiveLamp", position + Vector3(0.085, 0.0, -0.11), Color(0.22, 0.95, 0.56))

func _add_system_junctions_and_status() -> void:
	var group := _get_group("SystemJunctionsAndIndicators")
	# Floor-line junctions split the green oxygen feed toward each corner tank pair.
	var points := [
		Vector3(-8.9, 0.30, -9.35), Vector3(8.9, 0.30, -9.35),
		Vector3(-8.9, 0.30, 9.35), Vector3(8.9, 0.30, 9.35),
	]
	for index in range(points.size()):
		_add_junction_box(group, "OxygenJunction_%d" % (index + 1), points[index])
	# Wall-side status triplet uses green / amber / red as normal / service / offline.
	var green := Color(0.20, 0.90, 0.48)
	var amber := Color(1.0, 0.62, 0.12)
	var red := Color(0.95, 0.16, 0.12)
	for index in range(3):
		var colors := [green, amber, red]
		_add_status_lamp(group, "PowerStatus_%d" % index, Vector3(-1.85 + index * 0.20, 3.22, 9.285), colors[index])
	_add_status_lamp(group, "OxygenNormalLamp", Vector3(-2.15, 2.25, -9.28), green)
	_add_status_lamp(group, "OxygenServiceLamp", Vector3(-2.15, 2.05, -9.28), amber)
	_add_status_lamp(group, "HabitatNormalLamp", Vector3(9.25, 2.20, 1.8), green)
	_add_status_lamp(group, "StowageServiceLamp", Vector3(-9.25, 2.20, -2.8), amber)

func _add_caution_markings() -> void:
	var group := _get_group("ServiceCautionMarkings")
	var ochre := load("res://materials/accent_ochre.tres") as Material
	var dark := load("res://materials/trim_panels.tres") as Material
	# Short alternating floor bars mark a service-only edge by the oxygen assembly, not the main route.
	for index in range(10):
		var x := -4.35 + index * 0.22
		var material: Material = ochre if index % 2 == 0 else dark
		_add_box_piece(group, "TankServiceStripe_%02d" % index, Vector3(x, 0.018, -7.92), Vector3(0.16, 0.02, 0.12), material)
	# A restrained caution border under the storage stack.
	for index in range(5):
		var z := -3.9 + index * 0.18
		var material: Material = ochre if index % 2 == 0 else dark
		_add_box_piece(group, "StorageCautionStripe_%02d" % index, Vector3(-8.25, 0.018, z), Vector3(0.12, 0.02, 0.14), material)

func _add_cylinder_piece(parent: Node3D, piece_name: String, position: Vector3, radius: float, height: float, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.name = piece_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	piece.mesh = mesh
	piece.material_override = material
	piece.position = position
	piece.rotation = rotation
	parent.add_child(piece)
	return piece

func _add_microgravity_fittings() -> void:
	var group := _get_group("MicrogravityFittings")
	var rail_material := _brushed_metal_material() as Material
	var strap_material := load("res://materials/accent_ochre.tres") as Material
	# Wall-mounted handrails beside the berth and along the nearby habitation wall.
	for z_center in [0.55, 3.45]:
		_add_cylinder_piece(group, "BedHandrail_%s" % str(z_center), Vector3(9.27, 1.18, z_center), 0.045, 1.45, rail_material, Vector3(deg_to_rad(90), 0, 0))
		for z in [z_center - 0.62, z_center + 0.62]:
			_add_box_piece(group, "BedRailBracket", Vector3(9.39, 1.18, z), Vector3(0.18, 0.08, 0.08), rail_material)
	_add_cylinder_piece(group, "HabitationWallHandrail", Vector3(9.26, 1.20, -3.1), 0.045, 2.0, rail_material, Vector3(deg_to_rad(90), 0, 0))
	# Two low foot loops/restraint bars at the berth edge.
	for z in [1.2, 2.8]:
		_add_box_piece(group, "BedFootRestraint_%s" % str(z), Vector3(8.15, 0.16, z), Vector3(0.32, 0.07, 0.08), strap_material)
	# Reusable small tie-down cleats on the existing storage container and added crates.
	for z in [-2.35, -1.65]:
		_add_box_piece(group, "StorageTieDown_%s" % str(z), Vector3(-8.65, 0.88, z), Vector3(0.16, 0.06, 0.06), rail_material)
	for x in [-9.34, -9.14]:
		_add_box_piece(group, "CrateTieDown_%s" % str(x), Vector3(x, 0.39, -3.16), Vector3(0.07, 0.06, 0.16), rail_material)

func _add_access_hatches_and_floor_plates() -> void:
	var group := _get_group("AccessHatchesAndFloorPlates")
	var trim := load("res://materials/trim_panels.tres") as Material
	var beige := load("res://materials/wall_greige.tres") as Material
	# Repeated structural ribs and inset-looking hatches around the otherwise plain wall modules.
	for x in [-7.8, -4.5, 4.5, 7.8]:
		_add_box_piece(group, "NorthStructuralRib_%s" % str(x), Vector3(x, 2.12, -9.38), Vector3(0.13, 3.45, 0.12), beige)
		_add_box_piece(group, "SouthStructuralRib_%s" % str(x), Vector3(x, 2.12, 9.38), Vector3(0.13, 3.45, 0.12), beige)
	for z in [-7.8, -4.5, 4.5, 7.8]:
		_add_box_piece(group, "EastStructuralRib_%s" % str(z), Vector3(9.38, 2.12, z), Vector3(0.12, 3.45, 0.13), beige)
		_add_box_piece(group, "WestStructuralRib_%s" % str(z), Vector3(-9.38, 2.12, z), Vector3(0.12, 3.45, 0.13), beige)
	# Three service hatches on clear wall sections, each with a simple handle.
	_add_box_piece(group, "WestAccessHatch", Vector3(-9.30, 2.12, 5.0), Vector3(0.12, 1.15, 1.05), trim)
	_add_box_piece(group, "WestHatchHandle", Vector3(-9.20, 2.12, 5.0), Vector3(0.09, 0.34, 0.08), beige)
	_add_box_piece(group, "EastAccessHatch", Vector3(9.30, 2.12, -5.0), Vector3(0.12, 1.15, 1.05), trim)
	_add_box_piece(group, "EastHatchHandle", Vector3(9.20, 2.12, -5.0), Vector3(0.09, 0.34, 0.08), beige)
	_add_box_piece(group, "SouthAccessHatch", Vector3(5.2, 2.08, 9.30), Vector3(1.05, 1.15, 0.12), trim)
	_add_box_piece(group, "SouthHatchHandle", Vector3(5.2, 2.08, 9.20), Vector3(0.34, 0.08, 0.09), beige)
	# Removable flush floor plates with a small contrasting pull tab.
	for x in [-6.2, 6.2]:
		for z in [-5.8, 5.8]:
			_add_box_piece(group, "RemovableFloorPlate_%s_%s" % [str(x), str(z)], Vector3(x, 0.016, z), Vector3(0.95, 0.018, 0.95), trim)
			_add_box_piece(group, "FloorPlatePullTab", Vector3(x, 0.03, z), Vector3(0.18, 0.025, 0.06), beige)

func _add_suit_rack() -> void:
	var group := _get_group("SuitRack")
	var metal := _brushed_metal_material() as Material
	var suit := load("res://materials/wall_greige.tres") as Material
	# Compact wall-side rack near habitation; simple primitives keep it lightweight.
	for z in [-0.55, 0.55]:
		_add_cylinder_piece(group, "SuitRackUpright_%s" % str(z), Vector3(9.28, 1.18, -0.55 + z), 0.045, 2.25, metal)
	_add_cylinder_piece(group, "SuitRackRail", Vector3(9.28, 2.24, -0.55), 0.045, 1.18, metal, Vector3(deg_to_rad(90), 0, 0))
	for z in [-1.1, 0.0]:
		_add_box_piece(group, "SuitRackWallStandoff", Vector3(9.40, 1.18, z), Vector3(0.18, 0.10, 0.10), metal)
	# Two low-poly helmet domes on the rack.
	for z in [-0.88, -0.22]:
		var helmet := MeshInstance3D.new()
		helmet.name = "SuitHelmet_%s" % str(z)
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.38
		sphere.radial_segments = 12
		sphere.rings = 8
		helmet.mesh = sphere
		helmet.material_override = suit
		helmet.position = Vector3(9.28, 1.88, z)
		group.add_child(helmet)

func _add_accent_lighting() -> void:
	var group := _get_group("AccentLighting")
	var cool := Color(0.30, 0.74, 1.0)
	var red := Color(1.0, 0.12, 0.08)
	var cool_material := _emissive_material(cool)
	var red_material := _emissive_material(red)
	# Emissive trims plus only three extra lights keep the added lighting inexpensive.
	_add_box_piece(group, "PowerScreenCoolHalo", Vector3(0, 2.25, 9.325), Vector3(2.22, 1.18, 0.035), cool_material)
	_add_box_piece(group, "EmergencyBeaconRed", Vector3(8.85, 3.65, -8.85), Vector3(0.24, 0.10, 0.24), red_material)
	var screen_light := OmniLight3D.new()
	screen_light.name = "CoolScreenSpill"
	screen_light.position = Vector3(0, 2.2, 8.95)
	screen_light.light_color = cool
	screen_light.light_energy = 0.35
	screen_light.omni_range = 3.2
	screen_light.shadow_enabled = false
	group.add_child(screen_light)
	var emergency_light := OmniLight3D.new()
	emergency_light.name = "EmergencyRedSpill"
	emergency_light.position = Vector3(8.78, 3.45, -8.7)
	emergency_light.light_color = red
	emergency_light.light_energy = 0.28
	emergency_light.omni_range = 1.8
	emergency_light.shadow_enabled = false
	group.add_child(emergency_light)

func _add_vent(parent: Node3D, name: String, position: Vector3, wall_axis: String) -> void:
	var trim := load("res://materials/trim_panels.tres") as Material
	var beige := load("res://materials/wall_greige.tres") as Material
	if wall_axis == "z":
		_add_box_piece(parent, name + "Frame", position, Vector3(1.3, 0.52, 0.10), trim)
		for index in range(5):
			_add_box_piece(parent, name + "Slat_%d" % index, position + Vector3(0, -0.18 + index * 0.09, -0.06), Vector3(1.08, 0.035, 0.04), beige)
	else:
		_add_box_piece(parent, name + "Frame", position, Vector3(0.10, 0.52, 1.3), trim)
		for index in range(5):
			_add_box_piece(parent, name + "Slat_%d" % index, position + Vector3(0.06, -0.18 + index * 0.09, 0), Vector3(0.04, 0.035, 1.08), beige)

func _add_station_structure() -> void:
	var group := _get_group("StationStructure")
	var trim := load("res://materials/trim_panels.tres") as Material
	var ochre := load("res://materials/accent_ochre.tres") as Material
	# Modest wall-panel rhythm, kept clear of the four blocked openings and equipment clusters.
	for x in [-7.1, -5.0, 5.0, 7.1]:
		_add_box_piece(group, "NorthWallPanel_%s" % str(x), Vector3(x, 2.1, -9.43), Vector3(1.55, 2.45, 0.07), trim)
		_add_box_piece(group, "SouthWallPanel_%s" % str(x), Vector3(x, 2.1, 9.43), Vector3(1.55, 2.45, 0.07), trim)
	for z in [-7.1, -5.0, 5.0, 7.1]:
		_add_box_piece(group, "WestWallPanel_%s" % str(z), Vector3(-9.43, 2.1, z), Vector3(0.07, 2.45, 1.55), trim)
		_add_box_piece(group, "EastWallPanel_%s" % str(z), Vector3(9.43, 2.1, z), Vector3(0.07, 2.45, 1.55), trim)
	# Vent grilles use simple low-poly slats and the station's existing trim materials.
	_add_vent(group, "NorthVent", Vector3(6.45, 3.48, -9.38), "z")
	_add_vent(group, "SouthVent", Vector3(-6.45, 3.48, 9.38), "z")
	_add_vent(group, "WestVent", Vector3(-9.38, 3.48, 6.45), "x")
	_add_vent(group, "EastVent", Vector3(9.38, 3.48, -6.45), "x")
	# Shallow overhead cable trays give the existing blue ceiling cables a visible support.
	for side in [-1.0, 1.0]:
			_add_box_piece(group, "CableTrayX_%s" % str(side), Vector3(side * 9.25, 3.96, 0), Vector3(0.18, 0.10, 18.2), trim)
			_add_box_piece(group, "CableTrayZ_%s" % str(side), Vector3(0, 3.96, side * 9.25), Vector3(18.2, 0.10, 0.18), trim)
	# Ochre lane lines outline a clear route around the central structural pillar.
	for x in [-1.65, 1.65]:
		for z_center in [-4.65, 4.65]:
			_add_box_piece(group, "WalkwayLane_%s_%s" % [str(x), str(z_center)], Vector3(x, 0.012, z_center), Vector3(0.055, 0.012, 4.7), ochre)
	for z in [-2.3, 2.3]:
		_add_box_piece(group, "PillarClearanceMark_%s" % str(z), Vector3(0, 0.012, z), Vector3(3.3, 0.012, 0.055), ochre)

func _add_roof() -> void:
	var group := _get_group("Roof")
	var combiner := CSGCombiner3D.new()
	combiner.name = "MainRoomCeiling"
	combiner.use_collision = true
	combiner.position = Vector3(0, L.CEILING_UNDERSIDE + L.CEILING_THICKNESS * 0.5, 0)
	var slab := CSGBox3D.new()
	slab.name = "MainRoomRoofSlab"
	slab.size = Vector3(20.0, L.CEILING_THICKNESS, 20.0)
	var material := load("res://materials/wall_greige.tres") as Material
	if material != null:
		slab.material = material
	combiner.add_child(slab)
	group.add_child(combiner)

func _add_fixtures() -> void:
	var group := _get_group("LightFixtures")
	var mesh := _load_mesh_from_scene(L.ASSET_LIGHT_FIXTURE)
	var positions: Array[Vector3] = []
	var y := L.CEILING_UNDERSIDE - 0.12
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		positions.append(Vector3(x, y, -9.25))
		positions.append(Vector3(x, y, 9.25))
	for z in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		positions.append(Vector3(-9.25, y, z))
		positions.append(Vector3(9.25, y, z))
	_counts.fixtures = positions.size()
	_counts.real_lights = positions.size()
	if mesh != null:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = positions.size()
		var instance := MultiMeshInstance3D.new()
		instance.name = "FixturesMultiMesh"
		instance.multimesh = multimesh
		group.add_child(instance)
		for index in range(positions.size()):
			var position: Vector3 = positions[index]
			var yaw := 0.0
			if abs(position.z) > 9.0:
				yaw = 270.0 if position.z < 0.0 else 90.0
			else:
				yaw = 0.0 if position.x < 0.0 else 180.0
			var basis := Basis(Vector3.UP, deg_to_rad(yaw)).scaled(L.FIXTURE_SCALE)
			multimesh.set_instance_transform(index, Transform3D(basis, position))
	else:
		_report.append("Light fixture mesh unavailable; fixture visuals skipped")
	for index in range(positions.size()):
		var light := OmniLight3D.new()
		light.name = "RoomLight_%d" % index
		light.position = positions[index] + Vector3(0, -0.2, 0)
		light.light_color = L.FIXTURE_LIGHT_COLOR
		light.light_energy = 0.55
		light.omni_range = 4.0
		light.shadow_enabled = false
		group.add_child(light)

func _add_green_pipes() -> void:
	var group := _get_group("GreenPipes")
	var mesh := _load_mesh_from_scene(L.ASSET_GREEN_PIPE)
	var segments: Array[Dictionary] = []
	var pipe_y := 0.12
	# Continuous perimeter run; feeds the corner tank pairs and the main pair on the north wall.
	for x in range(-9, 10):
		segments.append({"pos": Vector3(x + 0.5, pipe_y, -9.42), "rot": Vector3(0, deg_to_rad(90), 0), "len": 1.0})
		segments.append({"pos": Vector3(x + 0.5, pipe_y, 9.42), "rot": Vector3(0, deg_to_rad(90), 0), "len": 1.0})
	for z in range(-9, 10):
		segments.append({"pos": Vector3(-9.42, pipe_y, z + 0.5), "rot": Vector3.ZERO, "len": 1.0})
		segments.append({"pos": Vector3(9.42, pipe_y, z + 0.5), "rot": Vector3.ZERO, "len": 1.0})
	# Branches feed each corner tank pair from the low perimeter supply.
	for side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			segments.append({"pos": Vector3(side * 9.02, pipe_y, z_side * 9.34), "rot": Vector3(0, deg_to_rad(90), 0), "len": 0.80})
			for y in [0.5, 1.1]:
				segments.append({"pos": Vector3(side * 8.65, y, z_side * 9.30), "rot": Vector3(deg_to_rad(90), 0, 0), "len": 0.70})
	# Main feed rises beside the tank assembly and branches along the wall to its control panel.
	segments.append({"pos": Vector3(-3.90, pipe_y, -9.05), "rot": Vector3.ZERO, "len": 0.74})
	for y in [0.5, 1.0, 1.5, 2.0, 2.5]:
		segments.append({"pos": Vector3(-3.90, y, -8.80), "rot": Vector3(deg_to_rad(90), 0, 0), "len": 0.50})
	segments.append({"pos": Vector3(-3.90, 1.62, -9.04), "rot": Vector3.ZERO, "len": 0.48})
	for x in [-3.5, -2.5, -1.5]:
		segments.append({"pos": Vector3(x, 1.62, -9.28), "rot": Vector3(0, deg_to_rad(90), 0), "len": 1.0})
	_counts.pipe_segments = segments.size()
	_place_segments(group, mesh, L.ASSET_GREEN_PIPE, L.GREEN_PIPE_BASE_SCALE, L.GREEN_PIPE_SEGMENT_LENGTH, segments)

func _add_blue_cables() -> void:
	var group := _get_group("BlueCables")
	var mesh := _load_mesh_from_scene(L.ASSET_BLUE_CABLE)
	var cable_y := L.CEILING_UNDERSIDE - 0.18
	var segments: Array[Dictionary] = []
	# Blue cable follows the inside ceiling perimeter in the central room only.
	for x in range(-9, 10):
		segments.append({"pos": Vector3(x + 0.5, cable_y, -9.25), "rot": Vector3(0, deg_to_rad(90), 0), "len": 1.0})
		segments.append({"pos": Vector3(x + 0.5, cable_y, 9.25), "rot": Vector3(0, deg_to_rad(90), 0), "len": 1.0})
	for z in range(-9, 10):
		segments.append({"pos": Vector3(-9.25, cable_y, z + 0.5), "rot": Vector3.ZERO, "len": 1.0})
		segments.append({"pos": Vector3(9.25, cable_y, z + 0.5), "rot": Vector3.ZERO, "len": 1.0})
	# Dedicated drops at the power screen, both auxiliary displays and console.
	for x in [-2.05, -1.45, 0.0, 1.45, 2.05]:
		for y in [3.5, 2.5, 1.5]:
			segments.append({"pos": Vector3(x, y, 9.39), "rot": Vector3(deg_to_rad(90), 0, 0), "len": 1.0})
	_counts.cable_segments = segments.size()
	_place_segments(group, mesh, L.ASSET_BLUE_CABLE, L.BLUE_CABLE_BASE_SCALE, L.BLUE_CABLE_SEGMENT_LENGTH, segments)

func _place_segments(parent: Node3D, mesh: Mesh, asset_path: String, base_scale: Vector3, base_length: float, segments: Array[Dictionary]) -> void:
	if mesh == null:
		_report.append("Segment mesh unavailable: %s" % asset_path)
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = segments.size()
	var instance := MultiMeshInstance3D.new()
	instance.name = "SegmentsMultiMesh"
	instance.multimesh = multimesh
	parent.add_child(instance)
	for index in range(segments.size()):
		var segment := segments[index]
		var scale_value := base_scale
		scale_value.z = base_scale.z * (segment.len / max(base_length, 0.001))
		var basis := Basis.from_euler(segment.rot).scaled(scale_value)
		multimesh.set_instance_transform(index, Transform3D(basis, segment.pos))
