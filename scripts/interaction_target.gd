extends Node3D

@export_enum("power_screen", "oxygen", "fuel_cell", "water", "food", "greenhouse", "bed", "cabinet", "container", "cat", "comms") var interaction_type: String = "power_screen"
@export var display_name: String = "Station equipment"

var is_open := false

func interaction_prompt() -> String:
	match interaction_type:
		"power_screen": return "E  Open station control & deep-space array (−0.20 EU)"
		"oxygen": return "E  Open gas & CO₂ scrubber controls"
		"fuel_cell": return "E  Operate fuel cell"
		"water": return "E  Inspect water storage & electrolyzer"
		"food": return "E  Open food supplies & eat/drink"
		"greenhouse": return "E  Operate lunar greenhouse"
		"bed": return "E  Rest & check comms from Berna"
		"cabinet": return "E  Open storage locker (%s)" % display_name
		"container": return "E  Open storage compartment (%s)" % display_name
		"cat": return "E  Interact with Pearl the Cat"
		"comms": return "E  Open Earth Comms / Story Log"
	return "E  Interact with %s" % display_name

func interact(_actor: Node = null) -> void:
	var ui := _get_ui()
	if ui == null:
		return
	match interaction_type:
		"power_screen":
			if name == "AstrometryWorkstation":
				ui.show_system("Science")
			else:
				ui.show_system("Overview", true)
		"oxygen":
			ui.show_system("Gas tanks")
		"fuel_cell":
			ui.show_system("Power")
		"water":
			ui.show_system("Water")
		"food":
			ui.show_system("Food")
		"greenhouse":
			ui.show_system("Greenhouse")
		"bed":
			ui.show_message("You rest briefly on the lunar berth. Berna's photo sits on the table beside you.")
		"cabinet", "container":
			is_open = true
			if ui.has_method("show_storage"):
				ui.show_storage(name, display_name)
			else:
				ui.show_message("Storage compartment opened.")
		"cat":
			if ui.has_method("start_story_dialogue"):
				ui.start_story_dialogue("pearl_pet")
			else:
				ui.show_message("Pearl purrs happily against your suit.")
		"comms":
			if ui.has_method("trigger_next_story_or_comms"):
				ui.trigger_next_story_or_comms()
		_:
			ui.show_message("%s" % display_name)

func _get_ui() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("InteractionUI")
