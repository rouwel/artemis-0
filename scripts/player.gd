extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var gravity: float = 9.8
@export var interaction_distance: float = 3.5

@onready var camera: Camera3D = $Camera3D
var _focused_interactable: Node = null
var _interaction_ui: Node = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_ensure_interaction_ui()

func _ensure_interaction_ui() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	_interaction_ui = scene.get_node_or_null("InteractionUI")
	if _interaction_ui == null:
		var ui_script := load("res://scripts/interaction_ui.gd")
		if ui_script:
			_interaction_ui = CanvasLayer.new()
			_interaction_ui.name = "InteractionUI"
			_interaction_ui.set_script(ui_script)
			scene.call_deferred("add_child", _interaction_ui)

func _unhandled_input(event: InputEvent) -> void:
	if _is_panel_open():
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	elif event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("interact"):
		if is_instance_valid(_focused_interactable) and _focused_interactable.has_method("interact"):
			_focused_interactable.call("interact", self)
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_update_interactable_focus()

func _update_interactable_focus() -> void:
	_focused_interactable = null
	if camera == null:
		return
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * interaction_distance)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var node: Node = hit.get("collider")
		while node != null:
			if node.has_method("interact") and node.has_method("interaction_prompt"):
				_focused_interactable = node
				break
			node = node.get_parent()
	if is_instance_valid(_interaction_ui) and _interaction_ui.has_method("set_prompt"):
		var prompt: String = _focused_interactable.call("interaction_prompt") if is_instance_valid(_focused_interactable) else ""
		_interaction_ui.call("set_prompt", prompt)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Vector2.ZERO if _is_panel_open() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

func _is_panel_open() -> bool:
	return is_instance_valid(_interaction_ui) and _interaction_ui.is_modal_open()
