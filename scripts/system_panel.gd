extends Control

signal close_requested
signal story_requested(dialogue_id: String)

const State = preload("res://scripts/life_support_state.gd")
const INK := Color("#e7edf0")
const MUTED := Color("#adbbc4")
const TEAL := Color("#65c7cc")
const GOLD := Color("#d8b56c")
const GREEN := Color("#4fd18b")
const CORAL := Color("#e57368")
const TAB_NAMES := ["Overview", "Gas tanks", "Power", "Water", "Food", "Science", "Greenhouse"]
const TRACKING_PACKETS := [
	{
		"id": "Observation 04",
		"designation": "2010-XK (Cislunar Object #404)",
		"time": "04:18:32",
		"azimuth": 128.4,
		"elevation": 22.7,
		"confidence": "HIGH",
		"range_km": 12400.0,
		"relative_speed": 0.8,
		"doppler_khz": -14.2,
		"albedo": 0.14,
		"diameter_m": 340.0,
		"mass_mt": 58.4,
		"semi_major_au": 1.184,
		"eccentricity": 0.392,
		"inclination_deg": 6.42,
		"moid_km": 4120.0,
		"impact_corridor": "Pacific / North America",
		"approach": "Inbound (Masked as Outbound)",
		"data_source": "Station Array · S-Band 2.29 GHz"
	},
	{
		"id": "Observation 05",
		"designation": "2010-XK (Confirming Earth Vector)",
		"time": "04:24:10",
		"azimuth": 131.2,
		"elevation": 24.5,
		"confidence": "HIGH",
		"range_km": 6850.0,
		"relative_speed": 4.2,
		"doppler_khz": -68.9,
		"albedo": 0.15,
		"diameter_m": 342.0,
		"mass_mt": 59.1,
		"semi_major_au": 1.184,
		"eccentricity": 0.394,
		"inclination_deg": 6.45,
		"moid_km": 820.0,
		"impact_corridor": "34.2°N, 118.4°W (Earth Impact)",
		"approach": "Earth Collision Vector",
		"data_source": "Station Array · X-Band 8.42 GHz"
	},
	{
		"id": "Observation 06",
		"designation": "2010-XK (Terminal Intercept Window)",
		"time": "04:29:45",
		"azimuth": 134.8,
		"elevation": 27.1,
		"confidence": "HIGH",
		"range_km": 1920.0,
		"relative_speed": 11.6,
		"doppler_khz": -190.4,
		"albedo": 0.16,
		"diameter_m": 342.0,
		"mass_mt": 59.1,
		"semi_major_au": 1.184,
		"eccentricity": 0.395,
		"inclination_deg": 6.46,
		"moid_km": 0.0,
		"impact_corridor": "99.8% EARTH IMPACT (T-Minus 14m)",
		"approach": "CRITICAL IMPACT IMMINENT",
		"data_source": "Station Array · High-Gain Lock"
	},
]

class TrackingPlot extends Control:
	var redirected_to_moon := false
	var step_progress := 0
	var dish_az := 128.4
	var dish_el := 22.7
	var target_az := 128.4
	var target_el := 22.7
	var sweep_phase := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(380, 260)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL

	func _process(delta: float) -> void:
		if is_visible_in_tree():
			sweep_phase = fposmod(sweep_phase + delta * 0.45, 1.0)
			queue_redraw()

	func _draw() -> void:
		var plot_size := size
		draw_rect(Rect2(Vector2.ZERO, plot_size), Color("#081219"), true)
		var font := ThemeDB.fallback_font

		# Top telemetry radar plot (polar sky & cislunar trajectory)
		var radar_h := plot_size.y * 0.72
		for star in range(28):
			var star_x := fposmod(float(star * 97 + 31), plot_size.x)
			var star_y := fposmod(float(star * 53 + 19), radar_h)
			draw_circle(Vector2(star_x, star_y), 0.8, Color(0.62, 0.76, 0.80, 0.55))

		var center := Vector2(plot_size.x * 0.44, radar_h * 0.54)
		var radius := minf(plot_size.x * 0.38, radar_h * 0.42)
		for fraction in [0.33, 0.66, 0.96]:
			draw_arc(center, radius * fraction, 0.0, TAU, 72, Color("#243842"), 1.1, true)
		draw_line(Vector2(center.x, 8), Vector2(center.x, radar_h - 8), Color("#304957"), 1.0, true)
		draw_line(Vector2(18, center.y), Vector2(plot_size.x - 18, center.y), Color("#304957"), 1.0, true)

		# Rotating radar sweep beam
		var sweep_angle := sweep_phase * TAU
		var sweep_end := center + Vector2(cos(sweep_angle), sin(sweep_angle)) * (radius * 0.96)
		draw_line(center, sweep_end, Color(0.40, 0.78, 0.80, 0.42), 1.6, true)

		# Earth reference node on left edge of cislunar plot
		var earth_pos := center + Vector2(-radius * 0.78, radius * 0.32)
		draw_circle(earth_pos, 11.0, Color("#2d6f96"))
		draw_arc(earth_pos, 12.5, 0.0, TAU, 32, Color("#65c7cc"), 1.1, true)
		draw_string(font, earth_pos + Vector2(-18, 25), "Earth", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#8ed6f0"))

		# Predicted trajectory curve
		var path := PackedVector2Array()
		for step in range(26):
			var angle := deg_to_rad(198.0 - step * 6.0)
			var dist := radius * (1.14 - step * 0.015)
			if redirected_to_moon:
				dist = radius * (0.98 - step * 0.036)
			path.append(center + Vector2(cos(angle) * dist, sin(angle) * dist))
		var path_col := Color("#e57368") if redirected_to_moon else Color("#65c7cc")
		for step in range(0, path.size() - 1, 2):
			draw_line(path[step], path[step + 1], path_col, 1.8, true)

		var approach_factor := clampf(1.0 - float(step_progress) * 0.22, 0.25, 1.0)
		var target := center + Vector2(radius * 0.56 * approach_factor, -radius * 0.50 * approach_factor)
		draw_circle(center, 9.0, Color("#8398a1"))
		draw_arc(center, 10.5, 0.0, TAU, 32, Color("#cbd9dc"), 1.0, true)
		draw_circle(target, 5.5, path_col)

		# Dish pointing reticle vs target position
		var az_err := clampf((dish_az - target_az) * 3.0, -45.0, 45.0)
		var el_err := clampf((dish_el - target_el) * 3.0, -45.0, 45.0)
		var dish_reticle := target + Vector2(az_err, -el_err)
		var locked := absf(dish_az - target_az) <= 0.15 and absf(dish_el - target_el) <= 0.15
		var ret_col := Color("#4fd18b") if locked else Color("#d8b56c")
		draw_arc(dish_reticle, 11.0, 0.0, TAU, 24, ret_col, 1.4, true)
		draw_line(dish_reticle + Vector2(-15, 0), dish_reticle + Vector2(15, 0), ret_col, 1.1, true)
		draw_line(dish_reticle + Vector2(0, -15), dish_reticle + Vector2(0, 15), ret_col, 1.1, true)

		draw_string(font, center + Vector2(12, 18), "Moon (Artemis-0)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#aabac0"))
		draw_string(font, target + Vector2(10, -8), "2010-XK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, path_col)
		draw_string(font, Vector2(center.x - 4, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#c8d5d9"))
		draw_string(font, Vector2(10, 18), "DSN POLAR & CISLUNAR PLOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#65c7cc"))

		# Bottom 28%: Live Doppler / SNR Spectrum Oscilloscope Waveform
		var wave_top := radar_h + 4.0
		var wave_h := plot_size.y - wave_top - 6.0
		draw_rect(Rect2(Vector2(6, wave_top), Vector2(plot_size.x - 12, wave_h)), Color("#050c11"), true)
		draw_rect(Rect2(Vector2(6, wave_top), Vector2(plot_size.x - 12, wave_h)), Color("#233844"), false, 1.0)
		var mid_y := wave_top + wave_h * 0.56
		draw_line(Vector2(10, mid_y), Vector2(plot_size.x - 10, mid_y), Color("#1e313b"), 1.0)

		var err_dist: float = Vector2(dish_az - target_az, dish_el - target_el).length()
		var snr_factor := clampf(1.0 - err_dist / 8.0, 0.15, 1.0)
		var wave_pts := PackedVector2Array()
		var w_width := plot_size.x - 24.0
		for i in range(64):
			var frac := float(i) / 63.0
			var x := 12.0 + frac * w_width
			var carrier := sin(frac * 32.0 + sweep_phase * TAU * 3.0)
			var env := exp(-pow((frac - 0.5) / 0.18, 2.0)) * snr_factor
			var noise := sin(float(i * 37) + sweep_phase * 19.0) * 0.16 * (1.2 - snr_factor)
			var y := mid_y - (carrier * env + noise) * (wave_h * 0.38)
			wave_pts.append(Vector2(x, y))
		for i in range(wave_pts.size() - 1):
			draw_line(wave_pts[i], wave_pts[i + 1], ret_col, 1.5, true)
		var snr_db := 6.0 + snr_factor * 26.4
		draw_string(font, Vector2(14, wave_top + 14), "S/X-BAND DOPPLER SPECTRUM  |  SNR: %.1f dB  |  %s" % [
			snr_db,
			"PHASE LOCK ACQUIRED" if locked else "SLEW DISH TO LOCK"
		], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ret_col)

var _state: State
var _tabs: TabContainer
var _status: Label
var _preview: Label
var _totals: Label
var _flow: Label
var _start: Button
var _reserve: CheckBox
var _scrubber_toggle: CheckBox
var _electrolyzer_toggle: CheckBox
var _output: OptionButton
var _meters: Array[Dictionary] = []
var _heading: Label
var _eyebrow: Label
var _model_note: Label
var _overview_button: Button
var _comms_button: Button
var _close_button: Button
var _reset_button: Button
var _controls: HFlowContainer
var _production: Label
var _power_load_summary: Label
var _central_dashboard := false
var _local_system := ""
var _food_rows: Dictionary = {}
var _food_feedback: Label
var _food_summary: Label
var _drink_water_button: Button
var _science_packet: Label
var _science_readout: Label
var _science_time_input: LineEdit
var _science_azimuth: LineEdit
var _science_elevation: LineEdit
var _science_confidence: OptionButton
var _science_feedback: Label
var _science_submit: Button
var _science_autofill: Button
var _science_log_output: Label
var _science_results_output: Label
var _science_content: VBoxContainer
var _science_views: Dictionary = {}
var _science_nav_buttons: Dictionary = {}
var _science_range_stat: Label
var _science_speed_stat: Label
var _science_doppler_stat: Label
var _science_mass_stat: Label
var _science_elements_stat: Label
var _science_corridor_stat: Label
var _science_approach_stat: Label
var _tracking_plot: TrackingPlot
var _footer_hint: Label
var _shade: ColorRect
var _margin: MarginContainer
var _lesson: Label
var _science_shell: BoxContainer
var _tracking_row: BoxContainer
var _last_tracking_count := -1
var _assisted_packet := -1
var _greenhouse_panels: Array[Control] = []
var _neows_panel: Control

func bind_nasa_client(client: Node) -> void:
	_neows_panel.bind_client(client)

func _ready() -> void:
	_build()

func bind_state(state: State) -> void:
	if is_instance_valid(_state) and _state.changed.is_connected(_refresh):
		_state.changed.disconnect(_refresh)
	_state = state
	_state.changed.connect(_refresh)
	for panel in _greenhouse_panels:
		panel.bind_state(state)
	_refresh()

func open_system(tab_name: String, central_dashboard: bool = false) -> void:
	_central_dashboard = central_dashboard
	_local_system = tab_name
	# The cabinet remains food-only; central Food can also manage production.
	_greenhouse_panels[0].visible = central_dashboard
	_set_modal_layout(central_dashboard)
	var selected := maxi(0, TAB_NAMES.find(tab_name))
	for index in range(_tabs.get_tab_count()):
		_tabs.set_tab_disabled(index, false)
	_tabs.current_tab = selected
	_tabs.tabs_visible = central_dashboard
	_tabs.get_tab_bar().focus_mode = Control.FOCUS_ALL if central_dashboard else Control.FOCUS_NONE
	# Hidden navigation must not allow keyboard access to other systems.
	for index in range(_tabs.get_tab_count()):
		_tabs.set_tab_disabled(index, not central_dashboard and index != selected)
	var science_screen := tab_name == "Science"
	_overview_button.visible = central_dashboard and not science_screen
	_comms_button.visible = central_dashboard
	_reset_button.visible = central_dashboard and not science_screen
	var fuel_controls := (central_dashboard and not science_screen) or tab_name == "Power"
	_start.visible = fuel_controls
	_output.visible = fuel_controls
	_preview.visible = fuel_controls
	_production.visible = fuel_controls
	_reserve.visible = (central_dashboard or tab_name == "Gas tanks") and not science_screen
	_scrubber_toggle.visible = (central_dashboard or tab_name == "Gas tanks") and not science_screen
	_electrolyzer_toggle.visible = (central_dashboard or tab_name == "Water" or tab_name == "Power") and not science_screen
	_controls.visible = fuel_controls or _reserve.visible or _scrubber_toggle.visible or _electrolyzer_toggle.visible
	_eyebrow.text = "LUNAR OUTPOST  /  DEEP SPACE NETWORK ARRAY (−1.0 EU PER TRANSMISSION)" if science_screen else "LUNAR OUTPOST  /  %s" % ("CENTRAL CONTROL (LOAD: −0.015 EU/s)" if central_dashboard else "LOCAL EQUIPMENT")
	_heading.text = "Station radar · observation & tracking" if science_screen else ("Life support · resource transfer" if central_dashboard else {
		"Gas tanks": "Hydrogen & oxygen supply",
		"Power": "Fuel-cell & electrical bus",
		"Water": "Water storage & electrolysis",
		"Food": "Food supplies & crew nutrition",
		"Greenhouse": "Lunar greenhouse · microgreens",
	}.get(tab_name, tab_name))
	_model_note.text = "Story radar: fictional · NASA catalogue: dated historical records" if science_screen else "Accelerated teaching model"
	_model_note.visible = true
	_status.visible = not science_screen
	_production.visible = fuel_controls and not science_screen
	_preview.visible = fuel_controls and not science_screen
	_footer_hint.visible = not science_screen
	if not science_screen:
		if central_dashboard or tab_name == "Power":
			_model_note.text += " · energy units (EU) power scrubbers, screens & electrolysis"
		if central_dashboard or tab_name == "Gas tanks":
			_model_note.text += " · CO₂ removal and oxygen supply are separate needs"
		if tab_name == "Food":
			_model_note.text += " · eat prepared meals and drink water to restore HUD bars"
	_tabs.custom_minimum_size.y = 440 if science_screen else 280
	if fuel_controls and not _start.disabled:
		_start.grab_focus()
	elif _reserve.visible:
		_reserve.grab_focus()
	else:
		_close_button.grab_focus()
	_lesson.text = _lesson_for(tab_name)
	_lesson.hide()
	_update_responsive_layout()
	_refresh()

func _set_modal_layout(central_dashboard: bool) -> void:
	_shade.visible = central_dashboard
	if central_dashboard or get_viewport_rect().size.x < 1100 or _local_system == "Science":
		_margin.anchor_left = 0.0
		_margin.anchor_top = 0.0
		_margin.anchor_right = 1.0
		_margin.anchor_bottom = 1.0
		_margin.offset_left = 0.0
		_margin.offset_top = 0.0
		_margin.offset_right = 0.0
		_margin.offset_bottom = 0.0
		for side in ["left", "right", "top", "bottom"]:
			_margin.add_theme_constant_override("margin_" + side, 16)
	else:
		# Wider local overlay (54% of viewport width) so nothing compresses or clips
		_margin.anchor_left = 0.45
		_margin.anchor_top = 0.03
		_margin.anchor_right = 0.985
		_margin.anchor_bottom = 0.97
		_margin.offset_left = 0.0
		_margin.offset_top = 0.0
		_margin.offset_right = 0.0
		_margin.offset_bottom = 0.0
		for side in ["left", "right", "top", "bottom"]:
			_margin.add_theme_constant_override("margin_" + side, 8)

func _style(color: Color, border: Color = Color("#344957")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _label(parent: Node, text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _build() -> void:
	var panel_theme := Theme.new()
	panel_theme.default_font_size = 15
	panel_theme.set_color("font_color", "Label", INK)
	panel_theme.set_stylebox("normal", "Button", _style(Color("#243944")))
	panel_theme.set_stylebox("hover", "Button", _style(Color("#345360"), TEAL))
	panel_theme.set_stylebox("pressed", "Button", _style(Color("#152831"), TEAL))
	panel_theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), GOLD))
	panel_theme.set_stylebox("panel", "TabContainer", _style(Color("#172630")))
	panel_theme.set_stylebox("tab_selected", "TabContainer", _style(Color("#304854"), TEAL))
	panel_theme.set_stylebox("tab_unselected", "TabContainer", _style(Color("#172630")))
	theme = panel_theme

	_shade = ColorRect.new()
	_shade.color = Color(0.01, 0.02, 0.03, 0.78)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 16)
	add_child(_margin)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _style(Color("#101c24")))
	_margin.add_child(frame)
	var outer_scroll := ScrollContainer.new()
	outer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(outer_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	outer_scroll.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_eyebrow = _label(titles, "", 12, TEAL)
	_heading = _label(titles, "", 22)
	_comms_button = _button(header, "Comms / Story Log", _open_story_from_dashboard)
	_overview_button = _button(header, "Overview", func(): _tabs.current_tab = 0)
	_close_button = _button(header, "Close  [Esc]", func(): close_requested.emit())
	_model_note = _label(column, "", 13, MUTED)

	_tabs = TabContainer.new()
	_tabs.custom_minimum_size.y = 280
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_overview(_page("Overview"))
	_build_gases(_page("Gas tanks"))
	_build_power(_page("Power"))
	_build_water(_page("Water"))
	_build_food(_page("Food"))
	_build_tracking(_page("Science"))
	_build_greenhouse(_page("Greenhouse"))
	_tabs.tab_changed.connect(_on_main_tab_changed)

	_status = _label(column, "", 16, GOLD)
	var controls := HFlowContainer.new()
	_controls = controls
	controls.add_theme_constant_override("h_separation", 14)
	controls.add_theme_constant_override("v_separation", 8)
	column.add_child(controls)
	_start = _button(controls, "Start fuel cell", _toggle_running)
	_output = OptionButton.new()
	for value in [25, 50, 100]:
		_output.add_item("Output: %d%%" % value)
	_output.selected = 2
	_output.item_selected.connect(func(index: int):
		if _state != null:
			_state.set_output_fraction([0.25, 0.5, 1.0][index]))
	controls.add_child(_output)
	_reserve = CheckBox.new()
	_reserve.text = "Protect 20% oxygen reserve"
	_reserve.button_pressed = true
	_reserve.toggled.connect(func(enabled: bool):
		if _state != null:
			_state.set_reserve_protection(enabled))
	controls.add_child(_reserve)

	_scrubber_toggle = CheckBox.new()
	_scrubber_toggle.text = "CO₂ scrubber (−0.008 EU/s)"
	_scrubber_toggle.button_pressed = true
	_scrubber_toggle.toggled.connect(func(enabled: bool):
		if _state != null:
			_state.set_scrubber_active(enabled))
	controls.add_child(_scrubber_toggle)

	_electrolyzer_toggle = CheckBox.new()
	_electrolyzer_toggle.text = "Electrolyzer (−0.60 EU/s → H₂+O₂)"
	_electrolyzer_toggle.button_pressed = false
	_electrolyzer_toggle.toggled.connect(func(enabled: bool):
		if _state != null:
			_state.set_electrolyzer_active(enabled))
	controls.add_child(_electrolyzer_toggle)

	_reset_button = _button(controls, "Reset demo", func():
		if _state != null:
			if get_parent()._mission_flow != null:
				get_parent()._mission_flow.show_menu("restart")
			else:
				_state.reset_demo())
	_production = _label(column, "", 14, TEAL)
	_preview = _label(column, "", 14, MUTED)
	_footer_hint = _label(column, "E / Esc closes this panel. The fuel cell keeps running while you inspect other equipment.", 12, MUTED)
	_button(column, "How does this work?  /  Optional field guide", func(): _lesson.visible = not _lesson.visible)
	_lesson = _label(column, "", 16, TEAL)
	_lesson.hide()
	get_viewport().size_changed.connect(_update_responsive_layout)

func _update_responsive_layout() -> void:
	_set_modal_layout(_central_dashboard)
	var narrow := get_viewport_rect().size.x < 1100
	if _science_shell != null:
		_science_shell.vertical = narrow
	if _tracking_row != null:
		_tracking_row.vertical = narrow

func _lesson_for(tab_name: String) -> String:
	match tab_name:
		"Greenhouse":
			return "GROW FOOD, PAY THE RESOURCE COST\nControlled-environment agriculture supplies light, water and nutrients without relying on lunar soil. Plants exchange CO₂ and O₂, but a small grow rack cannot replace engineered life support. Our accelerated crop and 90% water-recovery fraction are game assumptions. Seeds and nutrients are finite."
		"Gas tanks":
			return "AIR IS MORE THAN OXYGEN\nPeople consume oxygen and exhale carbon dioxide. A powered CO₂ scrubber removes CO₂; it does not manufacture oxygen. Our air-quality bar is a simplified 0–100 index, not oxygen percentage. Reserve protection saves gas for breathing instead of spending it in the fuel cell."
		"Water":
			return "RECYCLING HAS A COST\nElectrolysis splits water into hydrogen and oxygen using electricity. Here, 0.036 kg water and 0.60 EU produce 0.004 kg H₂ and 0.032 kg O₂. Those gases return only 0.40 EU through the fuel cell. Real systems lose energy as heat; they cannot power themselves forever."
		"Food":
			return "WATER PREPARES FOOD; IT DOES NOT CREATE CALORIES\nFreeze-dried meals save launch mass but need potable water. Ready-to-eat pouches already hold moisture. Prepare a portion, then eat it; the shared tank pays the water cost. Quantities and nutrition bars are simplified game values.\nSource: NASA Space Food Systems."
		"Science":
			return "BUILD A PREDICTION FROM OBSERVATIONS\nAzimuth is direction around the horizon; elevation is angle above it. Adjust the dish until the reticle locks, then transmit. Each accepted observation reveals a closer range and updates the story. Assisted calibration is optional.\nAll orbital numbers, waveforms and impact predictions here are scripted fiction, not real JPL data."
		_:
			return "NO FREE WATER OR POWER\nA fuel cell combines hydrogen and oxygen to make water, electricity and heat. The rounded mass ratio is 1 : 8 : 9. At full output our cell uses 0.005 kg H₂ and 0.040 kg O₂ per second, making 0.045 kg water and 0.50 EU. Finite tanks and battery capacity limit production.\nRates and energy units are accelerated teaching values. Source: NASA ECLSS; Smithsonian Apollo Astronaut Life."

func _open_story_from_dashboard() -> void:
	if _state == null:
		return
	get_parent().trigger_next_story_or_comms()

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(scroll)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	scroll.add_child(page)
	return page

func _on_main_tab_changed(index: int) -> void:
	if _central_dashboard and index >= 0 and index < TAB_NAMES.size():
		if _state != null and index != 0:
			_state.spend_energy(0.05, "Command console query")
		open_system(TAB_NAMES[index], true)

func _meter(parent: Node, title: String, key: String, capacity: float, unit: String, color: Color, vertical: bool = false) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	_label(box, title, 16, color)
	var bar := ProgressBar.new()
	bar.max_value = capacity
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 20)
	if vertical:
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		bar.custom_minimum_size = Vector2(110, 140)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var tank_style := _style(Color("#24333e"))
		tank_style.set_corner_radius_all(24)
		bar.add_theme_stylebox_override("background", tank_style)
		var fill_style := _style(color, color)
		fill_style.set_corner_radius_all(22)
		bar.add_theme_stylebox_override("fill", fill_style)
	else:
		bar.add_theme_stylebox_override("background", _style(Color("#24333e")))
		bar.add_theme_stylebox_override("fill", _style(color, color))
	box.add_child(bar)
	var value := _label(box, "", 15)
	_meters.append({"key": key, "bar": bar, "label": value, "capacity": capacity, "unit": unit})

func _build_overview(page: VBoxContainer) -> void:
	_label(page, "Turn stored gases into useful water and power", 20)
	_flow = _label(page, "", 16, TEAL)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	page.add_child(grid)
	_meter(grid, "Hydrogen · H₂", "hydrogen_kg", State.HYDROGEN_CAPACITY, "kg", GOLD)
	_meter(grid, "Oxygen · O₂", "oxygen_kg", State.OXYGEN_CAPACITY, "kg", TEAL)
	_meter(grid, "Water storage", "water_kg", State.WATER_CAPACITY, "kg", TEAL)
	_meter(grid, "Battery energy", "energy_units", State.ENERGY_CAPACITY, "EU", GOLD)
	_totals = _label(page, "", 15, MUTED)
	_food_summary = _label(page, "", 15, MUTED)
	_label(page, "Connected Systems: The Fuel Cell generates +0.50 EU/s and +0.045 kg/s water. Station loads: −0.008 EU/s CO₂ scrubber, −0.015 EU/s command screen.", 15)

func _build_gases(page: VBoxContainer) -> void:
	_label(page, "Separate tanks. One controlled reaction.", 20)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	page.add_child(row)
	_meter(row, "HYDROGEN · H₂", "hydrogen_kg", State.HYDROGEN_CAPACITY, "kg", GOLD, true)
	_meter(row, "OXYGEN · O₂", "oxygen_kg", State.OXYGEN_CAPACITY, "kg", TEAL, true)
	_label(page, "The fuel cell uses about 8 times as much oxygen as hydrogen by mass. These tank capacities are also in an 8:1 ratio, so their fill percentages fall together.", 15, MUTED)
	_label(page, "Reserve protection keeps 1.6 kg of oxygen out of the fuel cell. The CO₂ scrubber uses electricity to remove exhaled carbon dioxide. Breathing consumes oxygen separately; air quality is a gameplay index, not a gas concentration.", 15)

func _build_power(page: VBoxContainer) -> void:
	_label(page, "Fuel cell & station electrical loads", 20)
	_meter(page, "Stored battery energy", "energy_units", State.ENERGY_CAPACITY, "EU", GOLD)
	_power_load_summary = _label(page, "", 15, TEAL)
	_label(page, "Chemical energy in hydrogen and oxygen becomes electricity and water. Operating the Command Screen (−0.20 EU wake, −0.015 EU/s active), transmitting Science observations (−1.0 EU), running the CO₂ scrubber (−0.008 EU/s), or running the Water Electrolyzer (−0.60 EU/s) uses battery energy.", 15)
	_label(page, "At full output: 0.005 kg H₂ + 0.040 kg O₂ each second → 0.045 kg water + 0.5 EU.\nNote: Launching the Return Rocket for asteroid deflection requires 20.0 EU.", 14, MUTED)

func _build_water(page: VBoxContainer) -> void:
	_label(page, "Corner tank · collected water & electrolysis", 20)
	_meter(page, "Water in storage", "water_kg", State.WATER_CAPACITY, "kg", TEAL)
	_label(page, "Follow the blue transfer pipe from the fuel cell to the northwest corner. Its moving markers show active transfer; the tank's external gauge follows the same stored quantity as this screen.", 15)
	_label(page, "You can drink potable water directly, use it to hydrate food, or enable the Water Electrolyzer to split water back into H₂ and O₂ gas.", 15, MUTED)
	_label(page, "Water is made from the atoms in the two gas tanks. It does not appear for free.", 17, TEAL)

func _build_food(page: VBoxContainer) -> void:
	_label(page, "Prepare & consume supplies for the crew", 20)
	_meter(page, "Potable water available · safe to drink", "water_kg", State.WATER_CAPACITY, "kg", TEAL)
	var direct_row := HFlowContainer.new()
	direct_row.add_theme_constant_override("h_separation", 12)
	direct_row.add_theme_constant_override("v_separation", 6)
	page.add_child(direct_row)
	var direct_lbl := _label(direct_row, "Direct hydration from potable water tank (0.25 kg water → +32% Hydration):", 15, INK)
	direct_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drink_water_button = _button(direct_row, "Drink Water (0.25 kg)", func():
		if _state != null:
			_state.drink_direct_water())

	_food_feedback = _label(page, "", 15, GOLD)
	for item_id in State.FOOD_RECIPES:
		var recipe: Dictionary = State.FOOD_RECIPES[item_id]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("#20323e")))
		page.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		card.add_child(column)
		# Use HFlowContainer so buttons never compress or clip on narrow screens
		var header := HFlowContainer.new()
		header.add_theme_constant_override("h_separation", 10)
		header.add_theme_constant_override("v_separation", 6)
		column.add_child(header)
		var title := _label(header, recipe.name, 17)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.custom_minimum_size.x = 180
		var prepare := _button(header, recipe.action, _prepare_food.bind(item_id))
		var consume := _button(header, "%s (+%d%% H / +%d%% W)" % [
			recipe.get("consume_verb", "Consume"),
			int(recipe.get("hunger_restore", 25.0)),
			int(recipe.get("hydration_restore", 10.0))
		], _consume_food.bind(item_id))
		_label(column, recipe.description, 14, MUTED)
		_label(column, "Cost: 1 sealed package + %.2f kg water → 1 prepared portion" % recipe.water_kg, 14)
		var inventory := _label(column, "", 15, TEAL)
		var availability := _label(column, "", 14, GOLD)
		_food_rows[item_id] = {
			"button": prepare,
			"consume_button": consume,
			"inventory": inventory,
			"availability": availability
		}
	_label(page, "Eating prepared meals and drinking water immediately restores your Hunger and Hydration bars on the top-left HUD.", 14, MUTED)
	var source := RichTextLabel.new()
	source.bbcode_enabled = true
	source.fit_content = true
	source.scroll_active = false
	source.text = "[url=https://www.nasa.gov/humans-in-space/space-food-systems/]NASA · Space Food Systems (opens your browser)[/url]"
	source.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
	page.add_child(source)
	_build_greenhouse(page)

func _build_greenhouse(page: VBoxContainer) -> void:
	var panel := preload("res://scripts/greenhouse_panel.gd").new()
	page.add_child(panel)
	_greenhouse_panels.append(panel)

func _prepare_food(item_id: String) -> void:
	if _state != null:
		_state.prepare_food(item_id)

func _consume_food(item_id: String) -> void:
	if _state != null:
		_state.consume_prepared_food(item_id)

func _build_tracking(page: VBoxContainer) -> void:
	var shell := BoxContainer.new()
	_science_shell = shell
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 12)
	page.add_child(shell)
	var navigation := HFlowContainer.new()
	navigation.custom_minimum_size.x = 148
	navigation.add_theme_constant_override("separation", 8)
	shell.add_child(navigation)
	_science_content = VBoxContainer.new()
	_science_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_science_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_science_content)
	for view_name in ["Observation", "Data Log", "Results", "Settings", "NASA catalogue"]:
		var nav_button := _button(navigation, view_name, _select_science_view.bind(view_name))
		nav_button.custom_minimum_size = Vector2(144, 48)
		nav_button.toggle_mode = true
		_science_nav_buttons[view_name] = nav_button
	var observation := VBoxContainer.new()
	observation.add_theme_constant_override("separation", 8)
	var data_log := VBoxContainer.new()
	data_log.add_theme_constant_override("separation", 8)
	var results := VBoxContainer.new()
	results.add_theme_constant_override("separation", 8)
	var settings := VBoxContainer.new()
	settings.add_theme_constant_override("separation", 8)
	_science_views = {"Observation": observation, "Data Log": data_log, "Results": results, "Settings": settings}
	var catalogue := VBoxContainer.new()
	_science_views["NASA catalogue"] = catalogue
	for view in _science_views.values():
		view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_science_content.add_child(view)
	_build_observation_view(observation)
	_build_science_log_view(data_log)
	_build_science_results_view(results)
	_build_science_settings_view(settings)
	_neows_panel = preload("res://scripts/neows_panel.gd").new()
	catalogue.add_child(_neows_panel)
	_select_science_view("Observation")

func _select_science_view(view_name: String) -> void:
	for name in _science_views:
		_science_views[name].visible = name == view_name
		_science_nav_buttons[name].button_pressed = name == view_name

func _build_observation_view(page: VBoxContainer) -> void:
	var tracking_row := BoxContainer.new()
	_tracking_row = tracking_row
	tracking_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracking_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tracking_row.custom_minimum_size.y = 265
	tracking_row.add_theme_constant_override("separation", 12)
	page.add_child(tracking_row)
	var plot_frame := PanelContainer.new()
	plot_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plot_frame.custom_minimum_size = Vector2(380, 260)
	plot_frame.add_theme_stylebox_override("panel", _style(Color("#0c1720")))
	tracking_row.add_child(plot_frame)
	_tracking_plot = TrackingPlot.new()
	plot_frame.add_child(_tracking_plot)

	# Realistic NASA JPL HORIZONS & Goldstone Radar Astrometry Telemetry Readout
	var tracking_view := VBoxContainer.new()
	tracking_view.custom_minimum_size.x = 320
	tracking_view.add_theme_constant_override("separation", 5)
	tracking_row.add_child(tracking_view)
	_label(tracking_view, "SIMULATED RADAR TELEMETRY", 15, TEAL)
	_label(tracking_view, "●  Target: Object-2010-XK (Apollo NEO)", 13, GOLD)
	var divider := HSeparator.new()
	tracking_view.add_child(divider)
	_science_range_stat = _science_stat(tracking_view, "SLANT RANGE", "12,400 km")
	_science_speed_stat = _science_stat(tracking_view, "RADIAL VELOCITY", "-0.8 km/s")
	_science_doppler_stat = _science_stat(tracking_view, "DOPPLER SHIFT", "-14.2 kHz (S-Band)")
	_science_mass_stat = _science_stat(tracking_view, "EST. DIAMETER / MASS", "340 m  /  58.4 Mt")
	_science_elements_stat = _science_stat(tracking_view, "ORBIT (a / e / i)", "1.18 AU / 0.39 / 6.4°")
	_science_corridor_stat = _science_stat(tracking_view, "EARTH MOID / RISK", "4,120 km (Palermo +1.8)")
	_science_approach_stat = _science_stat(tracking_view, "TRAJECTORY STATE", "Inbound (Masked)")

	var hdr_row := HFlowContainer.new()
	hdr_row.add_theme_constant_override("h_separation", 10)
	hdr_row.add_theme_constant_override("v_separation", 6)
	page.add_child(hdr_row)
	var enter_lbl := _label(hdr_row, "ANTENNA DISH POINTING & TELEMETRY LOCK (−1.0 EU per transmission)", 16, TEAL)
	enter_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_science_autofill = _button(hdr_row, "Assist: calibrate dish", _autofill_next_packet)

	# Manual Dish Slew Fine-Tuning Controls
	var slew_row := HFlowContainer.new()
	slew_row.add_theme_constant_override("h_separation", 8)
	slew_row.add_theme_constant_override("v_separation", 6)
	page.add_child(slew_row)
	var slew_label := _label(slew_row, "Manual dish slew:", 13, MUTED)
	slew_label.custom_minimum_size.x = 135
	slew_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_button(slew_row, "AZ −0.1°", func(): _nudge_dish(-0.1, 0.0))
	_button(slew_row, "AZ +0.1°", func(): _nudge_dish(0.1, 0.0))
	_button(slew_row, "EL −0.1°", func(): _nudge_dish(0.0, -0.1))
	_button(slew_row, "EL +0.1°", func(): _nudge_dish(0.0, 0.1))

	var fields := HFlowContainer.new()
	fields.add_theme_constant_override("h_separation", 12)
	fields.add_theme_constant_override("v_separation", 8)
	page.add_child(fields)
	_science_time_input = _science_entry(fields, "UTC EPOCH TIME", "04:18:32", "")
	_science_azimuth = _science_entry(fields, "DISH AZIMUTH", "128.4", "°")
	_science_elevation = _science_entry(fields, "DISH ELEVATION", "22.7", "°")
	_science_azimuth.text_changed.connect(func(_t: String): _sync_plot_dish())
	_science_elevation.text_changed.connect(func(_t: String): _sync_plot_dish())

	var confidence_box := VBoxContainer.new()
	confidence_box.custom_minimum_size.x = 165
	fields.add_child(confidence_box)
	_label(confidence_box, "SIGNAL CONFIDENCE", 12, MUTED)
	_science_confidence = OptionButton.new()
	_science_confidence.add_item("LOW")
	_science_confidence.add_item("MEDIUM")
	_science_confidence.add_item("HIGH")
	_science_confidence.select(2)
	_science_confidence.custom_minimum_size.y = 40
	confidence_box.add_child(_science_confidence)

	var oxygen_notice := PanelContainer.new()
	oxygen_notice.add_theme_stylebox_override("panel", _style(Color("#18232a"), GOLD))
	page.add_child(oxygen_notice)
	_label(oxygen_notice, "Each transmission costs 1.0 EU. Match the target coordinates shown below; all telemetry is fictional.", 14, GOLD)
	_science_submit = _button(page, "➤  TRANSMIT RADAR ASTROMETRY PACKET (−1.0 EU)", _submit_tracking_packet)
	_science_submit.custom_minimum_size.y = 46
	_science_submit.add_theme_stylebox_override("normal", _style(GOLD, GOLD))
	_science_submit.add_theme_stylebox_override("hover", _style(Color("#e7c77f"), GOLD))
	_science_submit.add_theme_color_override("font_color", Color("#172630"))
	_science_feedback = _label(page, "Ready to record Observation 04.", 14, MUTED)

func _nudge_dish(d_az: float, d_el: float) -> void:
	if _science_azimuth.text.is_valid_float():
		_science_azimuth.text = "%.1f" % (_science_azimuth.text.to_float() + d_az)
	if _science_elevation.text.is_valid_float():
		_science_elevation.text = "%.1f" % (_science_elevation.text.to_float() + d_el)
	_sync_plot_dish()

func _sync_plot_dish() -> void:
	if _tracking_plot == null:
		return
	if _science_azimuth != null and _science_azimuth.text.is_valid_float():
		_tracking_plot.dish_az = _science_azimuth.text.to_float()
	if _science_elevation != null and _science_elevation.text.is_valid_float():
		_tracking_plot.dish_el = _science_elevation.text.to_float()
	_tracking_plot.queue_redraw()

func _autofill_next_packet() -> void:
	if _state == null:
		return
	var idx := clampi(_state.tracking_observations_submitted, 0, TRACKING_PACKETS.size() - 1)
	var pkt: Dictionary = TRACKING_PACKETS[idx]
	if _assisted_packet != idx:
		_state.assisted_locks += 1
		_assisted_packet = idx
	_science_time_input.text = str(pkt.time)
	_science_azimuth.text = "%.1f" % float(pkt.azimuth)
	_science_elevation.text = "%.1f" % float(pkt.elevation)
	_science_confidence.select(2)
	_sync_plot_dish()
	_science_feedback.text = "Auto-calibrated dish to %s (UTC %s, AZ %.1f°, EL %.1f°). Click TRANSMIT below." % [pkt.id, pkt.time, pkt.azimuth, pkt.elevation]

func _science_entry(parent: Control, title: String, default_value: String, suffix: String) -> LineEdit:
	var field := VBoxContainer.new()
	field.custom_minimum_size.x = 165
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_constant_override("separation", 4)
	parent.add_child(field)
	_label(field, title, 12, MUTED)
	var row := HBoxContainer.new()
	field.add_child(row)
	var input := LineEdit.new()
	input.text = default_value
	input.custom_minimum_size.y = 40
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(input)
	if not suffix.is_empty():
		_label(row, suffix, 15, TEAL)
	return input

func _science_stat(parent: VBoxContainer, title: String, value: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var left := _label(row, title, 12, MUTED)
	left.custom_minimum_size.x = 135
	var right := _label(row, value, 13, INK)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return right

func _build_science_log_view(page: VBoxContainer) -> void:
	_label(page, "DEEP SPACE NETWORK · ASTROMETRY DATA LOG", 19, TEAL)
	_science_log_output = _label(page, "No observations have been submitted.", 15, MUTED)

func _build_science_results_view(page: VBoxContainer) -> void:
	_science_packet = _label(page, "OBSERVATION 04  ·  READY", 19, TEAL)
	_science_readout = _label(page, "ORBITAL EPHEMERIS & IMPACT CORRIDOR SOLUTION", 15, MUTED)
	_label(page, "FICTIONAL MISSION · TELEMETRY REPORT", 18, TEAL)
	_science_results_output = _label(page, "Awaiting observation submission.", 15, INK)

func _build_science_settings_view(page: VBoxContainer) -> void:
	_label(page, "STATION ARRAY HARDWARE SPECIFICATIONS", 19, TEAL)
	_science_stat(page, "ANTENNA APERTURE", "12.0 m High-Gain Parabolic Dish")
	_science_stat(page, "TRANSCEIVER BANDS", "S-Band (2.29 GHz) / X-Band (8.42 GHz)")
	_science_stat(page, "TIME REFERENCE", "UTC · Rubidium Atomic Clock")
	_science_stat(page, "ANGULAR TOLERANCE", "±0.15° Beamwidth Lock")
	_science_stat(page, "RANGE RESOLUTION", "±15 m Delay-Doppler")
	_science_stat(page, "UPLINK COST", "1.0 EU per Ephemeris Packet")

func _submit_tracking_packet() -> void:
	if _state == null:
		_science_feedback.text = "Tracking record is unavailable."
		return
	var objectives := _state.get_objectives()
	if not objectives[0].done or not objectives[1].done:
		_science_feedback.text = "Stabilize the habitat first: generate 0.50 kg water, reach 22 EU, inspect supplies, and eat or drink."
		return
	if _state.energy_units < State.OBSERVATION_SCAN_ENERGY_COST:
		_science_feedback.text = "INSUFFICIENT POWER — need %.1f EU to transmit radar packet. Run the Fuel Cell!" % State.OBSERVATION_SCAN_ENERGY_COST
		_science_feedback.add_theme_color_override("font_color", CORAL)
		return
	var next_idx := _state.tracking_observations_submitted
	if next_idx >= TRACKING_PACKETS.size():
		_science_feedback.text = "All 3 deep-space asteroid observations have been transmitted."
		return
	var expected: Dictionary = TRACKING_PACKETS[next_idx]
	if _science_time_input.text.strip_edges() != expected.time or not _science_azimuth.text.is_valid_float() or not _science_elevation.text.is_valid_float():
		_science_feedback.text = "CHECK FAILED — verify UTC time (%s), Azimuth (%.1f°), and Elevation (%.1f°), or click 'Auto-Calibrate Dish'." % [expected.time, expected.azimuth, expected.elevation]
		_science_feedback.add_theme_color_override("font_color", GOLD)
		return
	if absf(_science_azimuth.text.to_float() - float(expected.azimuth)) > 0.15 or absf(_science_elevation.text.to_float() - float(expected.elevation)) > 0.15 or _science_confidence.get_item_text(_science_confidence.selected) != "HIGH":
		_science_feedback.text = "CHECK FAILED — dish pointing does not match %s lock (AZ %.1f°, EL %.1f°, HIGH). Click 'Auto-Calibrate Dish'!" % [expected.id, expected.azimuth, expected.elevation]
		_science_feedback.add_theme_color_override("font_color", GOLD)
		return
	var record: Dictionary = expected.duplicate(true)
	record["time"] = _science_time_input.text.strip_edges()
	record["azimuth"] = _science_azimuth.text.to_float()
	record["elevation"] = _science_elevation.text.to_float()
	record["confidence"] = _science_confidence.get_item_text(_science_confidence.selected)
	_state.record_tracking_observation(record)
	_science_feedback.add_theme_color_override("font_color", TEAL)
	# Keep the last dish pointing; the next lock must be acquired by the player.
	if _state.tracking_observations_submitted < TRACKING_PACKETS.size():
		var next_pkt: Dictionary = TRACKING_PACKETS[_state.tracking_observations_submitted]
		_science_time_input.text = str(next_pkt.time)
		_sync_plot_dish()
	_last_tracking_count = -1
	_refresh_tracking()

func _refresh_tracking() -> void:
	if _state == null or _science_packet == null:
		return
	var count := _state.tracking_observations_submitted
	var all_done := count >= TRACKING_PACKETS.size()
	var current_pkt: Dictionary = TRACKING_PACKETS[clampi(count, 0, TRACKING_PACKETS.size() - 1)]
	_science_packet.text = "%s  ·  %s" % [current_pkt.id.to_upper(), "TRANSMITTED" if all_done else "READY"]
	_science_readout.text = _state.tracking_status if count > 0 else "Unknown object · predicted trajectory · Station Array"
	if count != _last_tracking_count:
		_last_tracking_count = count
		if count == 0:
			_science_time_input.text = "04:18:32"
			_science_azimuth.text = "127.9"
			_science_elevation.text = "22.2"
			_assisted_packet = -1
		_science_feedback.text = "All locks transmitted. Press C to resume the final transmission." if all_done else "TARGET: %s · UTC %s · AZ %.1f° · EL %.1f° · HIGH confidence. Adjust the dish or use Assist." % [current_pkt.id, current_pkt.time, current_pkt.azimuth, current_pkt.elevation]
	_science_submit.disabled = all_done
	if _tracking_plot != null:
		_tracking_plot.redirected_to_moon = _state.asteroid_redirected_to_moon
		_tracking_plot.step_progress = count
		_tracking_plot.target_az = float(current_pkt.azimuth)
		_tracking_plot.target_el = float(current_pkt.elevation)
		_sync_plot_dish()
	if _science_range_stat != null:
		var shown_pkt: Dictionary = _state.tracking_log.back() if not _state.tracking_log.is_empty() else TRACKING_PACKETS[0]
		_science_range_stat.text = "%s km" % String.num(float(shown_pkt.range_km), 0)
		_science_speed_stat.text = "-%.1f km/s (Closing)" % float(shown_pkt.relative_speed)
		_science_doppler_stat.text = "%.1f kHz" % float(shown_pkt.get("doppler_khz", -14.2))
		_science_mass_stat.text = "%.0f m  /  %.1f Mt" % [float(shown_pkt.get("diameter_m", 340.0)), float(shown_pkt.get("mass_mt", 58.4))]
		_science_elements_stat.text = "a=%.2f AU, e=%.2f, i=%.1f°" % [
			float(shown_pkt.get("semi_major_au", 1.18)),
			float(shown_pkt.get("eccentricity", 0.39)),
			float(shown_pkt.get("inclination_deg", 6.4))
		]
		_science_corridor_stat.text = "LUNAR CRATER IMPACT" if _state.asteroid_redirected_to_moon else str(shown_pkt.get("impact_corridor", "Pacific"))
		_science_approach_stat.text = "DEFLECTED TO MOON" if _state.asteroid_redirected_to_moon else str(shown_pkt.approach)
	if _state.tracking_log.is_empty():
		_science_log_output.text = "No observations have been submitted.\n\nObservation 04 is ready for entry from the Station Array."
		_science_results_output.text = "Awaiting observation submission."
	else:
		var entries: Array[String] = []
		for record in _state.tracking_log:
			entries.append("%s  |  UTC %s  |  AZ %.1f°  EL %.1f°  |  RANGE %.0f km  |  DOPPLER %.1f kHz  |  CORRIDOR: %s" % [
				record.id,
				record.time,
				record.azimuth,
				record.elevation,
				record.range_km,
				float(record.get("doppler_khz", -14.2)),
				str(record.get("impact_corridor", "Earth"))
			])
		_science_log_output.text = "\n\n".join(entries)
		var latest: Dictionary = _state.tracking_log.back()
		_science_results_output.text = "SUBMITTED  ·  %d observation(s)\n\n%s was accepted and transmitted to Earth.\nData source: %s.\nRange estimate: %.0f km.\nRelative speed estimate: %.1f km/s.\nKeplerian Elements: a = %.3f AU, e = %.3f, i = %.2f°\nEstimated Mass: %.1f Megatons (%.0f m diameter)\nImpact Corridor: %s\nApproach: %s." % [
			_state.tracking_observations_submitted,
			latest.id,
			str(latest.get("data_source", "Station Array")),
			float(latest.range_km),
			float(latest.relative_speed),
			float(latest.get("semi_major_au", 1.184)),
			float(latest.get("eccentricity", 0.392)),
			float(latest.get("inclination_deg", 6.42)),
			float(latest.get("mass_mt", 58.4)),
			float(latest.get("diameter_m", 340.0)),
			"Lunar Outpost Artemis-0 (Earth Saved)" if _state.asteroid_redirected_to_moon else str(latest.get("impact_corridor", "Earth")),
			"Outbound" if _state.tracking_observations_submitted == 1 and not _state.asteroid_redirected_to_moon else ("Deflected toward Moon" if _state.asteroid_redirected_to_moon else str(latest.approach))
		]

func _toggle_running() -> void:
	if _state != null:
		_state.set_running(not _state.running)

func _refresh() -> void:
	if _state == null or _status == null:
		return
	for meter in _meters:
		var amount: float = _state.get(meter.key)
		meter.bar.value = amount
		meter.label.text = "%.1f%%  ·  %.3f / %.1f %s" % [amount / meter.capacity * 100.0, amount, meter.capacity, meter.unit]
	_status.text = _state.status
	var sealed_count := 0
	var prepared_count := 0
	for item_id in _food_rows:
		var row: Dictionary = _food_rows[item_id]
		var reason := _state.food_blocking_reason(item_id)
		row.button.disabled = not reason.is_empty()
		row.button.tooltip_text = reason
		var prep_amt: int = _state.prepared_food.get(item_id, 0)
		if row.has("consume_button"):
			row.consume_button.disabled = prep_amt <= 0
		row.inventory.text = "Sealed packages: %d    |    Prepared portions: %d" % [_state.food_stock[item_id], prep_amt]
		row.availability.text = reason
		row.availability.visible = not reason.is_empty()
		sealed_count += _state.food_stock[item_id]
		prepared_count += prep_amt
	if _drink_water_button != null:
		_drink_water_button.disabled = _state.water_kg < 0.25
	_food_feedback.text = _state.food_status
	_food_summary.text = "Food supplies: %d sealed packages  ·  %d prepared portions  |  Crew Hunger: %.0f%%  ·  Hydration: %.0f%%" % [sealed_count, prepared_count, _state.hunger, _state.hydration]
	if _power_load_summary != null:
		_power_load_summary.text = "Active Station Load: −%.3f EU/s  |  Total Consumed: %.2f EU  |  CO₂ scrubber: %s  |  Electrolyzer: %s" % [
			_state.total_power_load_per_sec(),
			_state.energy_consumed_units,
			"ON" if _state.scrubber_active else "OFF",
			"ON" if _state.electrolyzer_active else "OFF"
		]
	_refresh_tracking()
	if not _central_dashboard:
		if _local_system == "Water":
			_status.text = "Incoming flow: %.3f kg/s  ·  Free capacity: %.3f kg" % [
				_state.preview(1.0).water if _state.running else 0.0,
				State.WATER_CAPACITY - _state.water_kg]
		elif _local_system == "Gas tanks":
			_status.text = "Oxygen reserve: %s  ·  Available to fuel cell: %.3f kg  ·  Air quality index: %.0f / 100" % [
				"protected" if _state.protect_oxygen_reserve else "unprotected",
				maxf(0.0, _state.oxygen_kg - _state.oxygen_floor()),
				_state.oxygen_purity]
		elif _local_system == "Food":
			_status.text = "Prepared portions: %d  ·  Water used for preparation: %.2f kg" % [prepared_count, _state.food_water_used_kg]
		elif _local_system == "Greenhouse":
			_status.text = _state.greenhouse_status
	_start.text = "Stop fuel cell" if _state.running else "Start fuel cell"
	_start.disabled = not _state.running and not _state.blocking_reason().is_empty()
	_reserve.set_pressed_no_signal(_state.protect_oxygen_reserve)
	_scrubber_toggle.set_pressed_no_signal(_state.scrubber_active)
	_electrolyzer_toggle.set_pressed_no_signal(_state.electrolyzer_active)
	_output.select([0.25, 0.5, 1.0].find(_state.output_fraction))
	var transfer := _state.preview()
	_preview.text = "Next 10 s at selected output: −%.3f kg H₂  /  −%.3f kg O₂  →  +%.3f kg water  /  +%.2f EU (limited by available storage)." % [transfer.hydrogen, transfer.oxygen, transfer.water, transfer.energy]
	_flow.text = "H₂ + O₂  →  FUEL CELL  →  WATER + ELECTRICITY + HEAT\nTransfer: %s   |   Active Station Load: −%.3f EU/s" % ["ACTIVE" if _state.running else "STOPPED", _state.total_power_load_per_sec()]
	_totals.text = "Produced this session: %.3f kg water  ·  %.2f EU     |     1 kg water goal: %s" % [_state.water_produced_kg, _state.energy_produced_units, "complete" if _state.water_produced_kg >= 1.0 else "%.0f%%" % (_state.water_produced_kg * 100.0)]
	_production.text = "Fuel-cell production this session: %.3f kg water  ·  %.2f EU  (Consumed by station: %.2f EU)" % [_state.water_produced_kg, _state.energy_produced_units, _state.energy_consumed_units]
