extends Node3D

func sleep(_body: Node = null) -> void:
	var ui = get_tree().current_scene.get_node_or_null("UI/PromptLabel")
	if ui:
		ui.text = "Sleeping..."
		ui.visible = true
		await get_tree().create_timer(1.5).timeout
		if ui.text == "Sleeping...":
			ui.text = "Press E to sleep"
			ui.visible = true

func _on_interacted(body: Node) -> void:
	sleep(body)
