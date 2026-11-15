extends SceneTree
## Render-only review helper. Run without --headless, with an output directory:
## godot --path . --script tools/capture_life_support.gd -- /tmp/opencode

var _capture_viewport: SubViewport

func _initialize() -> void:
	set_meta("testing", true)
	_capture.call_deferred()

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or not DirAccess.dir_exists_absolute(args[0]):
		push_error("Pass an existing output directory after --.")
		quit(1)
		return
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	await process_frame
	var scene := current_scene
	# Render at a known size even when a tiling window manager overrides the
	# game window dimensions. This also makes small-screen checks meaningful.
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = Vector2i(1280, 900)
	_capture_viewport.world_3d = root.find_world_3d()
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var player := scene.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.position = Vector3(-4.8, 1.0, -3.9)
	var camera := player.get_node("Camera3D") as Camera3D
	camera.look_at(Vector3(-5.0, 1.25, -8.0))
	var capture_camera := Camera3D.new()
	_capture_viewport.add_child(capture_camera)
	capture_camera.global_transform = camera.global_transform
	capture_camera.current = true
	var state := scene.get_node("LifeSupport")
	state.set_physics_process(false)
	state.set_running(true)
	state.advance(25.0)
	await _save(args[0].path_join("life-support-room.png"))
	var ui := scene.get_node("InteractionUI")
	ui.reparent(_capture_viewport)
	for tab in ["Overview", "Gas tanks", "Water", "Food", "Science"]:
		ui.show_system(tab, true)
		await _save(args[0].path_join("life-support-%s.png" % tab.to_lower().replace(" ", "-")))
	for system in ["Gas tanks", "Power", "Water", "Food"]:
		ui.show_system(system)
		await _save(args[0].path_join("life-support-local-%s.png" % system.to_lower().replace(" ", "-")))
	state.prepare_food("dehydrated_meal")
	state.prepare_food("ready_pouch")
	state.prepare_food("powdered_drink")
	await _save(args[0].path_join("life-support-food-prepared.png"))
	state.water_kg = 0.1
	state.changed.emit()
	await _save(args[0].path_join("life-support-food-shortage.png"))
	_capture_viewport.size = Vector2i(800, 600)
	ui.show_system("Food")
	await _save(args[0].path_join("life-support-small.png"))
	var panel := ui.get_node("SystemPanel")
	panel._tabs.get_current_tab_control().scroll_vertical = 10000
	await _save(args[0].path_join("life-support-food-scrolled.png"))
	quit()

func _save(path: String) -> void:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := _capture_viewport.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Screenshot failed: %s" % path)
	else:
		print("Saved ", path)
