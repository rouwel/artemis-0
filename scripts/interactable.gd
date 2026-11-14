extends Area3D

@export var prompt_text: String = "Press E to interact"
signal interacted(body)

var player_in_range: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = true
		var ui = get_tree().current_scene.get_node_or_null("UI/PromptLabel")
		if ui:
			ui.text = prompt_text
			ui.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_in_range = false
		var ui = get_tree().current_scene.get_node_or_null("UI/PromptLabel")
		if ui and ui.text == prompt_text:
			ui.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		interacted.emit(get_tree().current_scene.get_node_or_null("Player"))
