extends Node3D

@export var wall_material: Material = preload("res://materials/wall_red.tres")

func _ready() -> void:
	var main_room := get_node_or_null("RoomLarge")
	if main_room != null:
		_apply_to_meshes(main_room)
	var opening_walls := get_node_or_null("StationAdditions/OpeningBlockers")
	if opening_walls != null:
		_apply_to_meshes(opening_walls)

func _apply_to_meshes(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		node.material_override = wall_material
	for child in node.get_children():
		_apply_to_meshes(child)
