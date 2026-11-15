extends SceneTree

var view: SubViewport
var output := "/tmp/opencode"

func _initialize() -> void:
	set_meta("testing", true)
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	await process_frame
	view = SubViewport.new()
	view.size = Vector2i(1280, 900)
	view.world_3d = root.find_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(view)
	var player := current_scene.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.position = Vector3(0, 1.7, 2)
	camera.look_at(Vector3(0, 1.8, 9))
	camera.current = true
	var state := current_scene.get_node("LifeSupport")
	state.set_physics_process(false)
	var ui := current_scene.get_node("InteractionUI")
	ui.reparent(view)
	var flow := preload("res://scripts/mission_flow.gd").new()
	ui.add_child(flow)
	ui._mission_flow = flow
	flow.set_process(false)
	await save("release-title")
	flow.show_menu("credits")
	await save("release-credits")
	flow.start_mission()
	await save("release-arrival")
	ui.close_panel()
	ui.show_storage("StationStorageContainer")
	await save("release-storage")
	ui.close_panel()
	ui.toggle_objectives_tab()
	await save("release-objectives")
	ui.toggle_objectives_tab()
	ui.show_system("Science")
	await save("release-radar")
	ui._system_panel._select_science_view("NASA catalogue")
	await save("release-nasa-catalogue")
	ui._system_panel._select_science_view("Observation")
	ui.close_panel()
	state.plant_crop()
	state.set_greenhouse_active(true)
	state.advance_greenhouse(90.0)
	camera.position = Vector3(-5.3, 1.6, -3.5)
	camera.look_at(Vector3(-8.55, 1.3, -4.6))
	await save("release-grow-rack")
	ui.show_system("Greenhouse")
	await save("release-greenhouse")
	ui.close_panel()
	ui.show_system("Water")
	ui._system_panel._lesson.show()
	await save("release-learning")
	ui.close_panel()
	flow.show_menu("pause")
	await save("release-pause")
	flow._open_settings("pause")
	await save("release-settings")
	flow._resume()
	state.ending_reached = "Sacrificed for Earth (Told Berna Truth)"
	state.tracking_observations_submitted = 3
	state.mission_seconds = 624.0
	flow.show_debrief()
	await save("release-debrief")
	view.size = Vector2i(800, 600)
	flow.show_menu("title")
	await save("release-small-title")
	flow.show_menu("credits")
	await save("release-small-credits")
	flow._resume()
	state.ending_reached = ""
	ui.show_storage("StationStorageContainer")
	await save("release-small-storage")
	ui.close_panel()
	ui.start_story_dialogue("obs_3_climax")
	await save("release-small-story")
	ui.close_panel()
	ui.show_system("Science")
	ui._system_panel._select_science_view("NASA catalogue")
	await save("release-small-nasa")
	ui._system_panel._select_science_view("Observation")
	await save("release-small-radar")
	ui._system_panel._tabs.get_current_tab_control().scroll_vertical = 10000
	await save("release-small-radar-controls")
	ui.close_panel()
	ui.show_system("Greenhouse")
	await save("release-small-greenhouse")
	ui._system_panel._tabs.get_current_tab_control().scroll_vertical = 10000
	await save("release-small-greenhouse-guide")
	ui.close_panel()
	state.ending_reached = "Preserved Return Ship (Told Berna Truth)"
	flow.show_debrief()
	await save("release-small-debrief")
	paused = false
	view.queue_free()
	current_scene.queue_free()
	await process_frame
	quit()

func save(stem: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := output.path_join(stem + ".png")
	var result := view.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Capture failed: " + path)
	else:
		print("Saved ", path)
