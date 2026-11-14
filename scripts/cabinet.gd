extends Node3D

var open := false
@onready var left_hinge: Node3D = $LeftHinge
@onready var right_hinge: Node3D = $RightHinge

func toggle(_body: Node = null) -> void:
	open = not open
	var t := 0.15
	var left_target := deg_to_rad(-100) if open else 0.0
	var right_target := deg_to_rad(100) if open else 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(left_hinge, "rotation:y", left_target, t)
	tw.tween_property(right_hinge, "rotation:y", right_target, t)

func _on_interacted(body: Node) -> void:
	toggle(body)
