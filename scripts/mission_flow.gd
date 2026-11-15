extends CanvasLayer
## Mission shell, settings, debrief, and lightweight procedural sound.
## Kept separate from equipment screens so Escape never changes story progress.

const State = preload("res://scripts/life_support_state.gd")
const INK := Color("#e7edf0")
const MUTED := Color("#adbbc4")
const GOLD := Color("#d8b56c")
const TEAL := Color("#65c7cc")

var _state: State
var _ui: CanvasLayer
var _root: Control
var _column: VBoxContainer
var _page := "title"
var _return_page := "title"
var _settings := ConfigFile.new()
var _hum: AudioStreamPlayer
var _effects: AudioStreamPlayer
var _beacon: Label3D
var _pulse := 0.0
var _last_objective := ""
var _exploring := false
var _launch_until := 0.0
var _launch_banner: Label

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ui = get_parent()
	_state = get_tree().current_scene.get_node("LifeSupport")
	_settings.load("user://settings.cfg")
	_apply_settings()
	_build_shell()
	_build_audio()
	_state.feedback.connect(_play_feedback)
	_build_beacon()
	if get_tree().has_meta("start_mission"):
		get_tree().remove_meta("start_mission")
		start_mission()
	else:
		show_menu("title")
	if "--smoke-test" in OS.get_cmdline_user_args():
		_smoke_test.call_deferred()

func _build_shell() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.05, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_root.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 14)
	scroll.add_child(_column)
	_launch_banner = Label.new()
	_launch_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_launch_banner.position = Vector2(-280, 24)
	_launch_banner.size = Vector2(560, 50)
	_launch_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_launch_banner.add_theme_color_override("font_color", GOLD)
	_launch_banner.add_theme_font_size_override("font_size", 22)
	_launch_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_launch_banner.hide()
	add_child(_launch_banner)

func _label(text: String, size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	_column.add_child(label)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#203540")
	style.border_color = Color("#41606c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 18
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#304d59")
	hover.border_color = GOLD
	button.add_theme_stylebox_override("hover", hover)
	button.pressed.connect(action)
	_column.add_child(button)
	return button

func show_menu(page: String) -> void:
	_page = page
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.show()
	_ui.get_node("Overlay").hide()
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_label("ARTEMIS–0   /   LUNAR HABITAT PROGRAM", 14, TEAL)
	var primary: Button
	match page:
		"title":
			_label("THE LAST TRANSMISSION", 42)
			_label("Keep the outpost alive. Discover what is approaching. Decide what comes next.", 21, GOLD)
			_label("A standalone lunar survival story • approximately 10–20 minutes\nFictional mission and telemetry, with real engineering ideas to discover.", 16, MUTED)
			primary = _button("Start mission", start_mission)
			_button("Controls & settings", func(): _open_settings("title"))
			_button("Credits & science sources", func(): _open_credits("title"))
			_button("Quit", func(): get_tree().quit())
		"pause":
			_label("MISSION PAUSED", 36)
			_label("Your resources and mission are paused. Conversations resume where you left them.", 17, MUTED)
			primary = _button("Resume", _resume)
			_button("Controls & settings", func(): _open_settings("pause"))
			_button("Credits & science sources", func(): _open_credits("pause"))
			_button("Restart mission", func(): show_menu("restart"))
			_button("Quit", func(): get_tree().quit())
		"restart":
			_label("RESTART MISSION?", 34)
			_label("This starts a fresh run. Current resources, observations and choices will reset.", 18)
			primary = _button("Keep playing", _resume)
			_button("Start a fresh mission", restart_mission)
		"settings":
			_label("CONTROLS & SETTINGS", 34)
			_label("WASD  Move     Mouse  Look     E  Interact / close\nH  Eat     J  Drink     C  Resume comms     Tab / O  Objectives\nEsc  Close a panel; press again to pause     F11  Fullscreen\nUse Tab / Shift+Tab and Enter to navigate menus.", 18)
			_label("Mouse sensitivity", 17, TEAL)
			var sensitivity := HSlider.new()
			sensitivity.min_value = 0.0005
			sensitivity.max_value = 0.006
			sensitivity.step = 0.0001
			sensitivity.value = float(_settings.get_value("controls", "sensitivity", 0.002))
			sensitivity.custom_minimum_size.y = 32
			sensitivity.value_changed.connect(func(value: float):
				_settings.set_value("controls", "sensitivity", value)
				_save_settings())
			_column.add_child(sensitivity)
			_label("Master volume", 17, TEAL)
			var volume := HSlider.new()
			volume.min_value = 0.0
			volume.max_value = 1.0
			volume.step = 0.05
			volume.value = float(_settings.get_value("audio", "volume", 0.65))
			volume.custom_minimum_size.y = 32
			volume.value_changed.connect(func(value: float):
				_settings.set_value("audio", "volume", value)
				_save_settings())
			_column.add_child(volume)
			_button("Toggle fullscreen  [F11]", _toggle_fullscreen)
			primary = _button("Back", func(): show_menu(_return_page))
		"credits":
			_label("CREW & REFERENCES", 34)
			_label("Rouwel Ngacha — Story & gameplay\nHaji Ibrahim — Life-support systems & integration\nRichard Ochola — NASA data & release engineering\nBernadette Akinyi — UI, learning content & QA", 19, GOLD)
			_label("Built with Godot Engine. Modular Space Kit by Kenney (CC0).\nTeam identities, assigned responsibilities and additional project models are recorded in CREDITS.md.", 17)
			_label("Fictional story: the mission, characters and story radar are game content. NASA catalogue records are dated real close approaches, separate from the story. This is not a NASA mission or a live JPL radar feed.", 17, MUTED)
			_label("Learn more:\nNASA — Environmental Control and Life Support Systems\nNASA — Space Food Systems\nSmithsonian National Air and Space Museum — Apollo Astronaut Life\nSource links and model assumptions are included in the README.", 17)
			primary = _button("Back", func(): show_menu(_return_page))
		"debrief":
			_label("MISSION DEBRIEF", 36)
			_label("Habitat emergency — mission ended" if _state.mission_failed else _state.ending_reached, 23, GOLD)
			if _state.mission_failed:
				_label("A crew vital reached zero. Try again: keep the CO₂ scrubber powered, eat before hunger runs low, and use emergency supplies from the west-wall lockers.", 18)
			else:
				_label("Your choices are recorded. Explore the station without further resource drain, or replay to follow another path.", 18)
			_label("MISSION TIME   %02d:%02d\nWATER PRODUCED   %.2f kg\nENERGY GENERATED / USED   %.1f / %.1f EU\nOBSERVATIONS   %d / 3  •  Assisted locks: %d\nEMERGENCY SUPPLIES USED   %d" % [
				int(_state.mission_seconds) / 60, int(_state.mission_seconds) % 60,
				_state.water_produced_kg, _state.energy_produced_units, _state.energy_consumed_units,
				_state.tracking_observations_submitted, _state.assisted_locks, _state.emergency_items_used], 18, TEAL)
			_label("WHAT YOUR MISSION DEMONSTRATED", 16, GOLD)
			if _state.crops_harvested > 0 or _state.greenhouse_water_used_kg > 0:
				_label("GREENHOUSE   %d crops harvested · %.3f kg water recovered · %.2f EU used\nGrowing food consumes finite seeds, nutrients, water and power. Water recovery helps; it does not make production free." % [_state.crops_harvested, _state.greenhouse_water_recovered_kg, _state.greenhouse_energy_used], 17, TEAL)
			_label("• Water and power share a cost: the fuel cell consumes finite hydrogen and oxygen.\n• Recycling needs energy: electrolysis uses more electricity than its gases return.\n• Breathing and CO₂ removal are separate needs. The air-quality meter is a simplified index.\n• Repeated observations refine a prediction; this game's asteroid solution is fictional.", 17)
			primary = _button("Replay mission", restart_mission)
			_button("Explore station", _explore)
			_button("Credits & science sources", func(): _open_credits("debrief"))
			_button("Quit", func(): get_tree().quit())
	if primary != null:
		primary.grab_focus()

func start_mission() -> void:
	_ui._intro_shown = true
	_resume()
	_ui.start_story_dialogue("arrival_intro")

func restart_mission() -> void:
	get_tree().paused = false
	get_tree().set_meta("start_mission", true)
	get_tree().reload_current_scene()

func show_debrief() -> void:
	_ui._story_box.hide()
	_ui._system_panel.hide()
	_ui._storage_panel.hide()
	show_menu("debrief")

func _explore() -> void:
	_exploring = true
	_resume()

func _resume() -> void:
	_root.hide()
	_ui.get_node("Overlay").show()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _ui.is_modal_open() else Input.MOUSE_MODE_CAPTURED

func _open_settings(from: String) -> void:
	_return_page = from
	show_menu("settings")

func _open_credits(from: String) -> void:
	_return_page = from
	show_menu("credits")

func _save_settings() -> void:
	_settings.save("user://settings.cfg")
	_apply_settings()

func _apply_settings() -> void:
	get_tree().current_scene.get_node("Player").mouse_sensitivity = float(_settings.get_value("controls", "sensitivity", 0.002))
	var volume := float(_settings.get_value("audio", "volume", 0.65))
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)

func _toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F11:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			if _root.visible:
				if _page in ["settings", "credits"]:
					show_menu(_return_page)
				elif _page in ["pause", "restart"]:
					_resume()
				get_viewport().set_input_as_handled()
			elif not _ui.is_modal_open():
				show_menu("pause")
				get_viewport().set_input_as_handled()

func _build_beacon() -> void:
	_beacon = Label3D.new()
	_beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_beacon.font_size = 28
	_beacon.pixel_size = 0.006
	_beacon.modulate = GOLD
	get_tree().current_scene.add_child.call_deferred(_beacon)

func _process(delta: float) -> void:
	if _state == null:
		return
	_pulse += delta
	_hum.volume_db = -55.0 if get_tree().paused else (-29.0 if _state.running else -40.0)
	_hum.pitch_scale = 1.12 if _state.running else 0.85
	_launch_banner.visible = _pulse < _launch_until and not _root.visible
	if _beacon.is_inside_tree():
		var objective := ""
		var location := Vector3.ZERO
		var objectives := _state.get_objectives()
		for index in range(objectives.size()):
			if objectives[index].done:
				continue
			objective = ["FUEL CELL", "FOOD & STOWAGE", "RADAR ARRAY", "RADAR ARRAY", "EARTH COMMS"][index]
			location = [Vector3(-5.1, 2.3, -8.25), Vector3(-7.7, 3.8, -2.0), Vector3(3.35, 2.4, 8.85), Vector3(3.35, 2.4, 8.85), Vector3(7.72, 1.5, 1.15)][index]
			break
		_beacon.visible = not objective.is_empty() and not _state.mission_failed and not _exploring
		_beacon.text = "CURRENT TASK\n" + objective
		_beacon.position = location + Vector3(0, sin(_pulse * 1.8) * 0.035, 0)
		if objective != _last_objective:
			if not _last_objective.is_empty():
				_play_feedback("objective")
			_last_objective = objective
	# Pause the resource clock while a transmission is being read.
	_state.set_physics_process(not _ui._story_box.visible and not _exploring)
	var light := get_tree().current_scene.get_node_or_null("OmniLight3D")
	if light != null:
		light.light_color = Color("#e6bf96") if _state.energy_units < 10.0 else Color.WHITE
		light.light_energy = 1.1 if _state.energy_units < 10.0 else 2.0

func _build_audio() -> void:
	_hum = AudioStreamPlayer.new()
	_hum.stream = _tone(60.0, 1.0, true)
	add_child(_hum)
	_hum.play()
	_effects = AudioStreamPlayer.new()
	_effects.volume_db = -18.0
	add_child(_effects)

func _exit_tree() -> void:
	# Release looping playback before the scene is replaced or the game quits.
	for player in [_hum, _effects]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null

func _tone(frequency: float, duration: float, looped: bool = false) -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var count := int(duration * sound.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in range(count):
		var t := float(i) / sound.mix_rate
		var envelope := 0.3 if looped else minf(t * 30.0, 1.0) * pow(1.0 - float(i) / count, 2.0)
		var sample := (sin(TAU * frequency * t) + 0.25 * sin(TAU * frequency * 2.0 * t)) * envelope
		bytes.encode_s16(i * 2, int(sample * 20000))
	sound.data = bytes
	if looped:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = count
	return sound

func _play_feedback(cue: String) -> void:
	var frequency: float = {"prepare": 440.0, "consume": 520.0, "transfer": 330.0, "transmit": 880.0, "warning": 180.0, "launch": 80.0, "objective": 660.0, "companion": 220.0}.get(cue, 440.0)
	_effects.stream = _tone(frequency, 2.4 if cue == "launch" else 0.24)
	_effects.play()
	if cue == "launch":
		_launch_banner.text = "RETURN ROCKET AWAY  /  INTERCEPT COMMITTED"
		_launch_until = _pulse + 4.0

func _smoke_test() -> void:
	await get_tree().process_frame
	start_mission()
	await get_tree().process_frame
	var snapshot = JSON.parse_string(FileAccess.get_file_as_string("res://data/neows_2010.json"))
	var catalogue_valid: bool = preload("res://scripts/nasa_api_client.gd").validate_snapshot(snapshot).get("ok", false)
	var api: Node = _ui._nasa_api
	if _ui._story_box.visible and _state != null and catalogue_valid and not api.records.is_empty() and not api.busy and get_tree().current_scene.has_node("StationAdditions/Greenhouse/HydroponicGrowRack"):
		print("Packaged NASA catalogue: %d records / %s" % [api.records.size(), api.source_mode])
		print("Packaged mission smoke test: PASS")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
