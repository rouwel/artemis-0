extends Node3D

## Live readouts and flow markers share the same state as every control panel.
const State = preload("res://scripts/life_support_state.gd")
const WATER_START := Vector3(-5.55, 0.65, -8.25)
const WATER_ELBOW := Vector3(-7.15, 0.65, -8.25)
const WATER_END := Vector3(-7.15, 0.65, -7.25)

var _state: State
var _water_gauge: MeshInstance3D
var _water_label: Label3D
var _gas_label: Label3D
var _cell_label: Label3D
var _markers: Array[MeshInstance3D] = []
var _phase := 0.0

func _ready() -> void:
	_state = get_tree().current_scene.get_node_or_null("LifeSupport") as State
	var builder := get_parent()
	var metal := builder._brushed_metal_material() as Material
	var trim := load("res://materials/trim_panels.tres") as Material
	var beige := load("res://materials/wall_greige.tres") as Material
	var water_material := builder._emissive_material(Color("#479cae")) as Material
	var gas_material := builder._emissive_material(Color("#c6a45c")) as Material

	# A compact, accessible stack beside the existing large gas pair.
	var cell := Node3D.new()
	cell.name = "FuelCell"
	cell.position = Vector3(-5.1, 0.6, -8.25)
	add_child(cell)
	builder._make_interactable(cell, "fuel_cell", "Hydrogen / oxygen fuel cell")
	builder._add_box_piece(cell, "Housing", Vector3.ZERO, Vector3(1.2, 1.2, 0.85), beige)
	builder._add_box_collision(cell, Vector3(1.2, 1.2, 0.85))
	for index in range(6):
		builder._add_box_piece(cell, "StackPlate%d" % index, Vector3(0, -0.38 + index * 0.15, 0.44), Vector3(0.85, 0.055, 0.035), trim)
	_cell_label = _label("FuelCellReadout", Vector3(-5.1, 1.65, -8.0), 24)
	_gas_label = _label("GasPairReadout", Vector3(-3.2, 2.9, -8.0), 22)
	_label("HydrogenIdentification", Vector3(-3.90, 1.6, -8.02), 24).text = "H₂\nHYDROGEN"
	_label("OxygenIdentification", Vector3(-2.50, 1.6, -8.02), 24).text = "O₂\nOXYGEN"
	_pipe(Vector3(-3.90, 0.50, -8.25), Vector3(-4.5, 0.50, -8.25), gas_material)
	_pipe(Vector3(-2.50, 0.30, -8.25), Vector3(-4.5, 0.30, -8.25), metal)

	var water := Node3D.new()
	water.name = "WaterStorage"
	water.position = Vector3(-7.15, 0, -7.25)
	add_child(water)
	builder._make_interactable(water, "water", "Corner water storage")
	builder._add_cylinder_piece(water, "Tank", Vector3(0, 1.05, 0), 0.55, 1.9, metal)
	builder._add_box_collision(water, Vector3(1.1, 2.1, 1.1), Vector3(0, 1.05, 0))
	for y in [0.25, 1.80]:
		builder._add_cylinder_piece(water, "TankBand", Vector3(0, y, 0), 0.57, 0.09, trim)
	builder._add_box_piece(water, "GaugeBacking", Vector3(0, 1.05, 0.56), Vector3(0.17, 1.35, 0.035), trim)
	var gauge_holder: Node3D = builder._add_box_piece(water, "WaterLevel", Vector3(0, 0.4, 0.59), Vector3(0.10, 1.2, 0.04), water_material)
	_water_gauge = gauge_holder.get_child(0) as MeshInstance3D
	_water_label = _label("WaterReadout", Vector3(-7.15, 2.35, -6.95), 24)
	_label("WaterIdentification", Vector3(-7.15, 1.15, -6.63), 20).text = "H₂O\nWATER"

	# Visible conditioning block and a dedicated blue transfer line.
	_pipe(WATER_START, WATER_ELBOW, water_material)
	_pipe(WATER_ELBOW, WATER_END, water_material)
	builder._add_box_piece(self, "WaterConditioner", Vector3(-6.15, 0.65, -8.25), Vector3(0.45, 0.45, 0.40), beige)
	_label("ConditionerLabel", Vector3(-6.15, 1.12, -8.0), 18).text = "WATER\nCONDITIONING"
	for index in range(4):
		var marker := MeshInstance3D.new()
		marker.name = "FlowMarker%d" % index
		var sphere := SphereMesh.new()
		sphere.radius = 0.065
		sphere.height = 0.13
		sphere.radial_segments = 8
		sphere.rings = 4
		marker.mesh = sphere
		marker.material_override = builder._emissive_material(Color("#bfeef4"))
		add_child(marker)
		_markers.append(marker)
	if _state != null:
		_state.changed.connect(_refresh)
	_refresh()

func _label(label_name: String, at: Vector3, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.position = at
	label.font_size = font_size
	label.pixel_size = 0.006
	label.modulate = Color("#e3edf0")
	label.outline_size = 6
	label.outline_modulate = Color("#101b20")
	add_child(label)
	return label

func _pipe(start: Vector3, end: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.045
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 12
	var pipe := MeshInstance3D.new()
	pipe.mesh = mesh
	pipe.material_override = material
	pipe.position = (start + end) * 0.5
	var direction := (end - start).normalized()
	pipe.quaternion = Quaternion(Vector3.UP, direction)
	add_child(pipe)

func _refresh() -> void:
	if _state == null:
		return
	var fill := _state.water_kg / State.WATER_CAPACITY
	_water_gauge.scale.y = maxf(fill, 0.001)
	_water_gauge.position.y = fill * 0.6
	_water_gauge.visible = fill > 0.0
	_water_label.text = "WATER STORAGE\n%.1f%%  |  %.2f kg" % [fill * 100.0, _state.water_kg]
	_gas_label.text = "FUEL-CELL GAS SUPPLY\nH₂ %.1f%%   /   O₂ %.1f%%" % [_state.hydrogen_kg / State.HYDROGEN_CAPACITY * 100.0, _state.oxygen_kg / State.OXYGEN_CAPACITY * 100.0]
	_cell_label.text = "FUEL CELL\n%s" % ("RUNNING" if _state.running else "STOPPED")
	for marker in _markers:
		marker.visible = _state.running

func _process(delta: float) -> void:
	if _state == null or not _state.running:
		return
	_phase = fposmod(_phase + delta * _state.output_fraction * 0.4, 1.0)
	var first_length := WATER_START.distance_to(WATER_ELBOW)
	var full_length := first_length + WATER_ELBOW.distance_to(WATER_END)
	for index in range(_markers.size()):
		var distance := fposmod(_phase + float(index) / _markers.size(), 1.0) * full_length
		if distance < first_length:
			_markers[index].position = WATER_START.lerp(WATER_ELBOW, distance / first_length)
		else:
			_markers[index].position = WATER_ELBOW.lerp(WATER_END, (distance - first_length) / (full_length - first_length))
