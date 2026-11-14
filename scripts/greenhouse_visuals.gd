extends Node3D

var _state: Node
var _leaves: Array[MeshInstance3D] = []
var _led_material: StandardMaterial3D
var _readout: Label3D
var _last_display := ""

func _ready() -> void:
	_state = get_tree().current_scene.get_node("LifeSupport")
	var metal := _material(Color("#546774"))
	var tray := _material(Color("#263d43"))
	var leaf := _material(Color("#70ad52"))
	_led_material = _material(Color("#9855ae"))
	_led_material.emission_enabled = true
	for x in [-0.4, 0.4]:
		for z in [-0.72, 0.72]:
			_box(Vector3(x, 1.2, z), Vector3(0.06, 2.4, 0.06), metal)
	for shelf in range(3):
		var y := 0.4 + shelf * 0.65
		_box(Vector3(0, y, 0), Vector3(0.88, 0.1, 1.5), tray)
		_box(Vector3(0, y + 0.5, 0), Vector3(0.8, 0.035, 1.4), _led_material)
		_box(Vector3(-0.32, y + 0.14, 0), Vector3(0.05, 0.04, 1.4), metal)
		for row in range(5):
			for x in [-0.17, 0.17]:
				var plant := _box(Vector3(x, y + 0.14, -0.56 + row * 0.28), Vector3(0.18, 0.16, 0.18), leaf)
				_leaves.append(plant)
	_readout = Label3D.new()
	_readout.position = Vector3(0.48, 2.6, 0)
	_readout.rotation_degrees.y = 90.0
	_readout.font_size = 24
	_readout.pixel_size = 0.005
	_readout.modulate = Color("#b7d7a7")
	add_child(_readout)
	_state.changed.connect(_refresh)
	_refresh()

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	return result

func _box(at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance

func _refresh() -> void:
	var display := "%s:%d:%s" % [_state.crop_planted, int(_state.crop_growth_percent), _state.greenhouse_active]
	if display == _last_display:
		return
	_last_display = display
	for plant in _leaves:
		plant.visible = _state.crop_planted
		plant.scale.y = 0.25 + _state.crop_growth_percent / 100.0 * 1.5
	_led_material.emission = Color("#b147cd") if _state.greenhouse_active else Color.BLACK
	_led_material.emission_energy_multiplier = 1.2 if _state.greenhouse_active else 0.0
	_readout.text = "LUNAR GREENHOUSE\n%s · %.0f%%" % ["GROWING" if _state.greenhouse_active else ("CROP PAUSED / READY" if _state.crop_planted else "PLANT A SEED KIT"), _state.crop_growth_percent]
