extends CanvasLayer

const State = preload("res://scripts/life_support_state.gd")
const StoryDB = preload("res://scripts/story_database.gd")

const INK := Color("#e7edf0")
const MUTED := Color("#adbbc4")
const TEAL := Color("#65c7cc")
const GOLD := Color("#d8b56c")
const GREEN := Color("#4fd18b")
const CORAL := Color("#e57368")

var _state: State
var _prompt: Label
var _toast: Label
var _dialog: PanelContainer
var _dialog_title: Label
var _dialog_body: Label
var _toast_timer: Timer
var _system_panel: Control
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED

## Top-Left First-Person Player HUD + Expandable Objectives Tab
var _hud_panel: PanelContainer
var _hunger_bar: ProgressBar
var _hunger_label: Label
var _hydration_bar: ProgressBar
var _hydration_label: Label
var _oxygen_bar: ProgressBar
var _oxygen_label: Label
var _power_hud_label: Label
var _hud_hint_label: Label
var _objectives_toggle_btn: Button
var _objectives_container: VBoxContainer
var _objectives_list_box: VBoxContainer
var _active_objective_banner: Label
var _objectives_expanded := false

## Storage Compartment UI Modal
var _storage_panel: PanelContainer
var _storage_title: Label
var _storage_status_label: Label
var _container_grid: GridContainer
var _player_grid: GridContainer
var _active_container_id := "StationStorageContainer"

## Bottom-of-Screen Story Dialogue Box with Options
var _story_box: PanelContainer
var _story_speaker: Label
var _story_role: Label
var _story_text: Label
var _story_choices_box: VBoxContainer
var _current_dialogue_id := ""
var _intro_shown := false
var _objectives_signature := ""
var _storage_signature := 0
var _story_buttons: Array[Dictionary] = []
var _side_dialogue := false
var _mission_flow: CanvasLayer
var _nasa_api: Node

func _ready() -> void:
	_build_ui()
	_system_panel = preload("res://scenes/system_panel.tscn").instantiate()
	add_child(_system_panel)
	_system_panel.hide()
	_system_panel.close_requested.connect(close_panel)
	_nasa_api = preload("res://scripts/nasa_api_client.gd").new()
	_nasa_api.name = "NASAData"
	add_child(_nasa_api)
	_system_panel.bind_nasa_client(_nasa_api)
	if _system_panel.has_signal("story_requested"):
		_system_panel.connect("story_requested", start_story_dialogue)
	var state := get_tree().current_scene.get_node_or_null("LifeSupport") as State
	if state != null:
		_state = state
		_system_panel.bind_state(state)
		_state.changed.connect(_refresh_hud_and_storage)
		_state.story_triggered.connect(_receive_story)
		_refresh_hud_and_storage()
		if not get_tree().has_meta("testing"):
			_mission_flow = preload("res://scripts/mission_flow.gd").new()
			add_child(_mission_flow)

func _receive_story(dialogue_id: String) -> void:
	if dialogue_id.ends_with("_warning"):
		if not is_modal_open():
			show_message({
				"low_power_warning": "Low battery. Start the fuel cell or use a backup power cell from storage.",
				"air_warning": "Air quality falling. Restore power and switch on the CO₂ scrubber at the gas tanks.",
				"supplies_warning": "Crew supplies needed. H to eat, J to drink; inspect west-wall stowage.",
			}.get(dialogue_id, "Check station resources."))
		return
	start_story_dialogue(dialogue_id)

func _style(bg: Color, border: Color = Color("#344957"), corner: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(corner)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Overlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. Top-Left First-Person Survival HUD + Clickable Expandable Objectives Tab
	_build_hud(root)

	# 2. Center Reticle
	var reticle := Label.new()
	reticle.text = "+"
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reticle.set_anchors_preset(Control.PRESET_CENTER)
	reticle.position = Vector2(-8, -14)
	reticle.size = Vector2(16, 28)
	reticle.add_theme_font_size_override("font_size", 22)
	reticle.add_theme_color_override("font_color", Color(0.72, 0.91, 0.96, 0.9))
	root.add_child(reticle)

	# 3. Interaction Prompt
	_prompt = Label.new()
	_prompt.name = "PromptLabel"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-260, -96)
	_prompt.size = Vector2(520, 40)
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	_prompt.add_theme_color_override("font_shadow_color", Color(0.02, 0.06, 0.09, 0.9))
	_prompt.add_theme_constant_override("shadow_offset_x", 1)
	_prompt.add_theme_constant_override("shadow_offset_y", 1)
	_prompt.visible = false
	root.add_child(_prompt)

	# 4. Toast Notification
	_toast = Label.new()
	_toast.name = "ToastLabel"
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position = Vector2(-280, -150)
	_toast.size = Vector2(560, 56)
	_toast.add_theme_font_size_override("font_size", 17)
	_toast.add_theme_color_override("font_color", Color(0.82, 0.94, 0.97))
	_toast.visible = false
	root.add_child(_toast)

	# 5. Generic Info Panel
	_dialog = PanelContainer.new()
	_dialog.name = "InfoPanel"
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.position = Vector2(-250, -150)
	_dialog.size = Vector2(500, 300)
	_dialog.custom_minimum_size = Vector2(500, 300)
	_dialog.visible = false
	root.add_child(_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_dialog.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_dialog_title = Label.new()
	_dialog_title.add_theme_font_size_override("font_size", 26)
	_dialog_title.add_theme_color_override("font_color", Color(0.65, 0.88, 0.96))
	column.add_child(_dialog_title)
	_dialog_body = Label.new()
	_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_body.add_theme_font_size_override("font_size", 17)
	_dialog_body.add_theme_color_override("font_color", Color(0.91, 0.94, 0.95))
	var info_scroll := ScrollContainer.new()
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.custom_minimum_size.y = 160
	column.add_child(info_scroll)
	_dialog_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_scroll.add_child(_dialog_body)
	var close_hint := Label.new()
	close_hint.text = "Press E or Esc to close"
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	close_hint.add_theme_font_size_override("font_size", 13)
	close_hint.add_theme_color_override("font_color", Color(0.58, 0.69, 0.73))
	column.add_child(close_hint)

	# 6. Storage Compartment Inventory UI (Responsive anchors & ScrollContainer so it never compresses)
	_build_storage_ui(root)

	# 7. Bottom-of-screen Story Dialogue & Choices Box
	_build_story_ui(root)

	_toast_timer = Timer.new()
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 2.6
	_toast_timer.timeout.connect(_hide_toast)
	add_child(_toast_timer)

func _build_hud(root: Control) -> void:
	_hud_panel = PanelContainer.new()
	_hud_panel.name = "PlayerHUD"
	_hud_panel.position = Vector2(16, 16)
	_hud_panel.custom_minimum_size = Vector2(330, 0)
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.10, 0.14, 0.90), Color("#2d4654"), 8))
	root.add_child(_hud_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_panel.add_child(vbox)

	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "SUIT TELEMETRY · ARTEMIS-0"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", TEAL)
	title_row.add_child(title)

	var h_row := _create_hud_bar(vbox, "Hunger", GOLD)
	_hunger_bar = h_row.bar
	_hunger_label = h_row.label

	var w_row := _create_hud_bar(vbox, "Hydration", TEAL)
	_hydration_bar = w_row.bar
	_hydration_label = w_row.label

	var o_row := _create_hud_bar(vbox, "Cabin air quality", GREEN)
	_oxygen_bar = o_row.bar
	_oxygen_label = o_row.label

	_power_hud_label = Label.new()
	_power_hud_label.add_theme_font_size_override("font_size", 13)
	_power_hud_label.add_theme_color_override("font_color", GOLD)
	vbox.add_child(_power_hud_label)

	_hud_hint_label = Label.new()
	_hud_hint_label.text = "[H] Eat  [J] Drink  [C] Comms  [Tab/O] Objectives"
	_hud_hint_label.add_theme_font_size_override("font_size", 11)
	_hud_hint_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_hud_hint_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Clickable Objectives Tab Header Button on the HUD
	_objectives_toggle_btn = Button.new()
	_objectives_toggle_btn.name = "ObjectivesTabButton"
	_objectives_toggle_btn.text = "▶  OBJECTIVES (0/5) · [Tab/O] Expand"
	_objectives_toggle_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_objectives_toggle_btn.custom_minimum_size = Vector2(305, 30)
	_objectives_toggle_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_objectives_toggle_btn.add_theme_font_size_override("font_size", 12)
	_objectives_toggle_btn.add_theme_color_override("font_color", GOLD)
	_objectives_toggle_btn.add_theme_stylebox_override("normal", _style(Color("#152530"), TEAL, 5))
	_objectives_toggle_btn.add_theme_stylebox_override("hover", _style(Color("#203847"), GOLD, 5))
	_objectives_toggle_btn.add_theme_stylebox_override("pressed", _style(Color("#101d26"), GOLD, 5))
	_objectives_toggle_btn.pressed.connect(toggle_objectives_tab)
	vbox.add_child(_objectives_toggle_btn)

	# Always-visible current active objective one-liner when collapsed
	_active_objective_banner = Label.new()
	_active_objective_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_active_objective_banner.custom_minimum_size = Vector2(305, 0)
	_active_objective_banner.add_theme_font_size_override("font_size", 12)
	_active_objective_banner.add_theme_color_override("font_color", INK)
	vbox.add_child(_active_objective_banner)

	# Expanded Objectives Drawer
	_objectives_container = VBoxContainer.new()
	_objectives_container.name = "ObjectivesDrawer"
	_objectives_container.add_theme_constant_override("separation", 6)
	_objectives_container.visible = false
	vbox.add_child(_objectives_container)

	var drawer_scroll := ScrollContainer.new()
	drawer_scroll.custom_minimum_size.y = 230
	drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_objectives_container.add_child(drawer_scroll)
	_objectives_list_box = VBoxContainer.new()
	_objectives_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_objectives_list_box.add_theme_constant_override("separation", 6)
	drawer_scroll.add_child(_objectives_list_box)

func toggle_objectives_tab() -> void:
	_objectives_expanded = not _objectives_expanded
	if _objectives_container != null:
		_objectives_container.visible = _objectives_expanded
	if _active_objective_banner != null:
		_active_objective_banner.visible = not _objectives_expanded
	_refresh_objectives_ui()

func _refresh_objectives_ui() -> void:
	if _state == null or _objectives_toggle_btn == null:
		return
	var objs: Array[Dictionary] = _state.get_objectives()
	var signature := str(objs)
	if signature == _objectives_signature:
		_active_objective_banner.visible = not _objectives_expanded
		_objectives_toggle_btn.text = _objectives_toggle_btn.text.replace("Expand", "Collapse").replace("▶", "▼") if _objectives_expanded else _objectives_toggle_btn.text.replace("Collapse", "Expand").replace("▼", "▶")
		return
	_objectives_signature = signature
	var done_count := 0
	var next_current_title := "All mission objectives complete!"
	for o in objs:
		if o.get("done", false):
			done_count += 1
		elif next_current_title == "All mission objectives complete!":
			next_current_title = "Current: " + str(o.get("title", ""))

	var arrow := "▼" if _objectives_expanded else "▶"
	var action_word := "Collapse" if _objectives_expanded else "Expand"
	_objectives_toggle_btn.text = "%s  OBJECTIVES (%d/%d) · [Tab/O] %s" % [arrow, done_count, objs.size(), action_word]
	_active_objective_banner.text = next_current_title
	_active_objective_banner.visible = not _objectives_expanded

	for child in _objectives_list_box.get_children():
		_objectives_list_box.remove_child(child)
		child.queue_free()

	for o in objs:
		var done: bool = o.get("done", false)
		var item_card := PanelContainer.new()
		item_card.custom_minimum_size = Vector2(305, 0)
		item_card.add_theme_stylebox_override("panel", _style(
			Color(0.08, 0.16, 0.15, 0.9) if done else Color(0.09, 0.15, 0.20, 0.9),
			GREEN if done else Color("#344957"),
			4
		))
		var item_box := VBoxContainer.new()
		item_box.add_theme_constant_override("separation", 2)
		item_card.add_child(item_box)

		var hdr := Label.new()
		hdr.text = ("%s  %s" % ["[✓]" if done else "[  ]", str(o.get("title", ""))])
		hdr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hdr.add_theme_font_size_override("font_size", 12)
		hdr.add_theme_color_override("font_color", GREEN if done else GOLD)
		item_box.add_child(hdr)

		var desc := Label.new()
		desc.text = str(o.get("detail", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", MUTED if done else INK)
		item_box.add_child(desc)

		_objectives_list_box.add_child(item_card)

func _create_hud_bar(parent: VBoxContainer, label_name: String, fill_color: Color) -> Dictionary:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(header)

	var name_lbl := Label.new()
	name_lbl.text = label_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", INK)
	header.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "100%"
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", fill_color)
	header.add_child(val_lbl)

	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 80.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, 11)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#1a2933")
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	row.add_child(bar)
	return {"bar": bar, "label": val_lbl}

func _build_storage_ui(root: Control) -> void:
	_storage_panel = PanelContainer.new()
	_storage_panel.name = "StoragePanel"
	_storage_panel.anchor_left = 0.06
	_storage_panel.anchor_right = 0.94
	_storage_panel.anchor_top = 0.07
	_storage_panel.anchor_bottom = 0.93
	_storage_panel.offset_left = 0
	_storage_panel.offset_right = 0
	_storage_panel.offset_top = 0
	_storage_panel.offset_bottom = 0
	_storage_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.11, 0.14, 0.97), TEAL, 8))
	_storage_panel.visible = false
	root.add_child(_storage_panel)

	var outer_scroll := ScrollContainer.new()
	outer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_storage_panel.add_child(outer_scroll)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12)
	outer_scroll.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	var eyebrow := Label.new()
	eyebrow.text = "LUNAR OUTPOST  /  STOWAGE COMPARTMENT"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", TEAL)
	titles.add_child(eyebrow)
	_storage_title = Label.new()
	_storage_title.text = "Storage Compartment"
	_storage_title.add_theme_font_size_override("font_size", 22)
	_storage_title.add_theme_color_override("font_color", INK)
	titles.add_child(_storage_title)

	var close_btn := Button.new()
	close_btn.text = "Close [E / Esc]"
	close_btn.custom_minimum_size = Vector2(140, 38)
	close_btn.pressed.connect(close_panel)
	header.add_child(close_btn)

	_storage_status_label = Label.new()
	_storage_status_label.text = "Transfer supplies between compartment slots and your Suit Pack, or consume rations directly."
	_storage_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_storage_status_label.add_theme_font_size_override("font_size", 15)
	_storage_status_label.add_theme_color_override("font_color", GOLD)
	outer.add_child(_storage_status_label)

	var split := HBoxContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 20)
	outer.add_child(split)

	# Left: Storage Compartment Slots
	var left_box := VBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.add_theme_constant_override("separation", 8)
	split.add_child(left_box)
	var left_lbl := Label.new()
	left_lbl.text = "COMPARTMENT SLOTS (Click 'Take' to move to Suit Pack)"
	left_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_lbl.add_theme_font_size_override("font_size", 14)
	left_lbl.add_theme_color_override("font_color", TEAL)
	left_box.add_child(left_lbl)
	_container_grid = GridContainer.new()
	_container_grid.columns = 2
	_container_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_container_grid.add_theme_constant_override("h_separation", 10)
	_container_grid.add_theme_constant_override("v_separation", 10)
	left_box.add_child(_container_grid)

	# Right: Player Suit Pack Slots
	var right_box := VBoxContainer.new()
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_box.add_theme_constant_override("separation", 8)
	split.add_child(right_box)
	var right_lbl := Label.new()
	right_lbl.text = "YOUR SUIT PACK (Click 'Store' to place, or 'Eat/Drink/Use')"
	right_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_lbl.add_theme_font_size_override("font_size", 14)
	right_lbl.add_theme_color_override("font_color", GOLD)
	right_box.add_child(right_lbl)
	_player_grid = GridContainer.new()
	_player_grid.columns = 2
	_player_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_grid.add_theme_constant_override("h_separation", 10)
	_player_grid.add_theme_constant_override("v_separation", 10)
	right_box.add_child(_player_grid)

func _build_story_ui(root: Control) -> void:
	_story_box = PanelContainer.new()
	_story_box.name = "StoryDialogBox"
	_story_box.anchor_left = 0.08
	_story_box.anchor_right = 0.92
	_story_box.anchor_top = 0.62
	_story_box.anchor_bottom = 0.97
	_story_box.offset_left = 0
	_story_box.offset_right = 0
	_story_box.offset_top = 0
	_story_box.offset_bottom = 0
	_story_box.add_theme_stylebox_override("panel", _style(Color(0.04, 0.09, 0.13, 0.97), GOLD, 8))
	_story_box.visible = false
	root.add_child(_story_box)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_story_box.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var top_bar := HFlowContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	vbox.add_child(top_bar)

	_story_speaker = Label.new()
	_story_speaker.add_theme_font_size_override("font_size", 18)
	_story_speaker.add_theme_color_override("font_color", GOLD)
	top_bar.add_child(_story_speaker)

	_story_role = Label.new()
	_story_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_role.add_theme_font_size_override("font_size", 13)
	_story_role.add_theme_color_override("font_color", TEAL)
	top_bar.add_child(_story_role)

	var dismiss_btn := Button.new()
	dismiss_btn.text = "Dismiss [Esc]"
	dismiss_btn.pressed.connect(close_story_dialogue)
	top_bar.add_child(dismiss_btn)

	_story_text = Label.new()
	_story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_story_text.add_theme_font_size_override("font_size", 16)
	_story_text.add_theme_color_override("font_color", INK)
	_story_text.focus_mode = Control.FOCUS_ALL
	vbox.add_child(_story_text)

	_story_choices_box = VBoxContainer.new()
	_story_choices_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_story_choices_box)

func _refresh_hud_and_storage() -> void:
	if _state == null:
		return
	if _hunger_bar != null:
		_hunger_bar.value = _state.hunger
		_hunger_label.text = "%.0f%%" % _state.hunger
	if _hydration_bar != null:
		_hydration_bar.value = _state.hydration
		_hydration_label.text = "%.0f%%" % _state.hydration
	if _oxygen_bar != null:
		_oxygen_bar.value = _state.oxygen_purity
		_oxygen_label.text = "%.0f%%" % _state.oxygen_purity
	if _power_hud_label != null:
		var load_rate := _state.total_power_load_per_sec()
		_power_hud_label.text = "Station Battery: %.1f EU  (Load: −%.3f EU/s)" % [_state.energy_units, load_rate]

	_refresh_objectives_ui()
	for entry in _story_buttons:
		var required: float = entry.choice.get("require_energy", 0.0)
		entry.button.disabled = _state.energy_units + State.EPSILON < required
		entry.button.tooltip_text = "Need %.1f EU. Dismiss, charge at the fuel cell, then press C to resume." % required if entry.button.disabled else ""

	if _storage_panel != null and _storage_panel.visible:
		_storage_status_label.text = _state.storage_status
		var signature := hash([_state.containers.get(_active_container_id, {}), _state.player_inventory])
		if signature != _storage_signature:
			_rebuild_storage_grids()

func show_storage(container_id: String, display_title: String = "") -> void:
	if _state == null:
		return
	_state.ever_opened_storage = true
	_state.set_command_screen_active(false)
	if not _state.containers.has(container_id):
		container_id = "StationStorageContainer"
	_active_container_id = container_id
	_enter_modal()
	_dialog.hide()
	_system_panel.hide()
	_story_box.hide()
	var c_data: Dictionary = _state.containers[container_id]
	_storage_title.text = c_data.get("title", display_title if not display_title.is_empty() else container_id)
	_storage_panel.show()
	_rebuild_storage_grids()
	_refresh_objectives_ui()

func _rebuild_storage_grids() -> void:
	if _state == null or _container_grid == null or _player_grid == null:
		return
	_storage_status_label.text = _state.storage_status
	_storage_signature = hash([_state.containers.get(_active_container_id, {}), _state.player_inventory])
	var columns := 1 if get_viewport().get_visible_rect().size.x < 1050 else 2
	_container_grid.columns = columns
	_player_grid.columns = columns
	for child in _container_grid.get_children():
		_container_grid.remove_child(child)
		child.queue_free()
	for child in _player_grid.get_children():
		_player_grid.remove_child(child)
		child.queue_free()

	var c_slots: Array = _state.containers.get(_active_container_id, {}).get("slots", [])
	for idx in range(c_slots.size()):
		var slot: Dictionary = c_slots[idx]
		_container_grid.add_child(_create_slot_card(slot, idx, true))

	for idx in range(_state.player_inventory.size()):
		var slot: Dictionary = _state.player_inventory[idx]
		_player_grid.add_child(_create_slot_card(slot, idx, false))

func _create_slot_card(slot: Dictionary, slot_index: int, is_container: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(180, 96)
	var empty: bool = slot.get("id", "").is_empty() or slot.get("count", 0) <= 0
	card.add_theme_stylebox_override("panel", _style(
		Color("#14222b") if empty else Color("#1d3240"),
		Color("#2a3d4a") if empty else TEAL,
		5
	))
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	if empty:
		var empty_lbl := Label.new()
		empty_lbl.text = "[ Empty Slot %d ]" % (slot_index + 1)
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color("#586e7a"))
		vbox.add_child(empty_lbl)
		return card

	var item_id: String = slot.id
	var info: Dictionary = State.ITEM_CATALOG.get(item_id, {})
	var title := Label.new()
	title.text = "%s  ×%d" % [info.get("name", item_id), slot.count]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", INK)
	card.tooltip_text = info.get("description", "")
	vbox.add_child(title)

	var desc_lbl := Label.new()
	desc_lbl.text = info.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", MUTED)
	vbox.add_child(desc_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	var transfer_btn := Button.new()
	transfer_btn.text = "Take" if is_container else "Store"
	transfer_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transfer_btn.pressed.connect(func():
		if is_container:
			_state.transfer_container_to_player(_active_container_id, slot_index)
		else:
			_state.transfer_player_to_container(_active_container_id, slot_index)
	)
	btn_row.add_child(transfer_btn)

	var use_btn := Button.new()
	var cat: String = info.get("category", "")
	use_btn.text = "Eat/Drink" if (cat == "food" or cat == "drink") else ("Inspect" if cat == "keepsake" else "Use")
	use_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	use_btn.pressed.connect(func():
		_state.use_inventory_item(slot_index, _active_container_id if is_container else "")
	)
	btn_row.add_child(use_btn)
	return card

func start_story_dialogue(dialogue_id: String) -> void:
	if dialogue_id.is_empty() or not StoryDB.DIALOGUES.has(dialogue_id):
		close_story_dialogue()
		return
	_current_dialogue_id = dialogue_id
	_side_dialogue = dialogue_id == "pearl_pet" or dialogue_id.ends_with("_warning")
	if _state != null:
		_state.set_command_screen_active(false)
		if not _side_dialogue:
			_state.pending_dialogue = dialogue_id
	var data: Dictionary = StoryDB.DIALOGUES[dialogue_id]
	_enter_modal()
	_dialog.hide()
	_system_panel.hide()
	_storage_panel.hide()
	_story_box.show()
	_story_box.anchor_top = 0.40 if get_viewport().get_visible_rect().size.y < 700 else 0.56

	_story_speaker.text = data.get("speaker", "TRANSMISSION")
	_story_role.text = data.get("role", "")
	_story_text.text = data.get("text", "")
	if _state != null:
		if _state.comm_history.is_empty() or _state.comm_history.back().text != _story_text.text:
			_state.log_comm_entry(_story_speaker.text, _story_text.text)

	_story_buttons.clear()
	for child in _story_choices_box.get_children():
		_story_choices_box.remove_child(child)
		child.queue_free()

	var choices: Array = data.get("choices", [])
	for idx in range(choices.size()):
		var c: Dictionary = choices[idx]
		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var req_energy: float = float(c.get("require_energy", 0.0))
		var label_text: String = "%d.  %s" % [idx + 1, c.get("text", "Continue")]
		if req_energy > 0.0 and _state != null and _state.energy_units < req_energy:
			btn.disabled = true
			label_text += "  [Need %.1f EU — have %.1f EU. Run Fuel Cell!]" % [req_energy, _state.energy_units]
		btn.text = label_text
		btn.custom_minimum_size.y = 38
		btn.add_theme_stylebox_override("normal", _style(Color("#1d313d"), TEAL, 5))
		btn.add_theme_stylebox_override("hover", _style(Color("#2a4758"), GOLD, 5))
		btn.pressed.connect(_on_story_choice_selected.bind(c))
		_story_choices_box.add_child(btn)
		_story_buttons.append({"button": btn, "choice": c})
	_story_text.grab_focus()
	_story_box.get_child(0).set_deferred("scroll_vertical", 0)

func _on_story_choice_selected(choice: Dictionary) -> void:
	if _state != null and choice.has("effect"):
		if not _state.apply_story_effect(str(choice.get("effect"))):
			_story_role.text = "Action unavailable. Check power; dismiss and press C to resume."
			return
	var next_id: String = str(choice.get("next", ""))
	if not _side_dialogue and _state != null:
		_state.pending_dialogue = next_id
	if next_id.is_empty():
		close_story_dialogue()
	else:
		start_story_dialogue(next_id)

func close_story_dialogue() -> void:
	if _story_box != null:
		_story_box.hide()
	if not is_modal_open():
		Input.mouse_mode = _previous_mouse_mode
		_hud_panel.show()
	if _state != null and (_current_dialogue_id.begins_with("ending_") or _current_dialogue_id == "mission_failure"):
		if _mission_flow != null:
			_mission_flow.show_debrief()

func trigger_next_story_or_comms() -> void:
	if _state == null:
		return
	if not _state.pending_dialogue.is_empty():
		start_story_dialogue(_state.pending_dialogue)
	else:
		var entries: Array[String] = []
		for entry in _state.comm_history.slice(maxi(0, _state.comm_history.size() - 4)):
			entries.append("%s\n%s" % [entry.speaker, entry.text])
		show_info("Recent transmissions", "\n\n".join(entries))

func set_prompt(text: String) -> void:
	if _prompt == null or _dialog == null:
		return
	_prompt.text = text
	_prompt.visible = not text.is_empty() and not is_modal_open()

func is_modal_open() -> bool:
	return (
		(_dialog != null and _dialog.visible)
		or (_system_panel != null and _system_panel.visible)
		or (_storage_panel != null and _storage_panel.visible)
		or (_story_box != null and _story_box.visible)
	)

func show_system(tab_name: String, central_dashboard: bool = false) -> void:
	if get_tree().current_scene.get_node_or_null("LifeSupport") == null:
		show_info("Station systems", "Open the main scene to run the life-support simulation.")
		return
	if _state != null:
		_state.set_command_screen_active(central_dashboard or tab_name == "Science")
		if tab_name == "Food":
			_state.ever_opened_storage = true
	_enter_modal()
	_dialog.hide()
	_storage_panel.hide()
	_story_box.hide()
	_system_panel.show()
	_system_panel.open_system(tab_name, central_dashboard)

func _enter_modal() -> void:
	if not is_modal_open():
		_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_toast_timer.stop()
	_toast.hide()
	_prompt.hide()
	_hud_panel.hide()

func close_panel() -> void:
	var was_story := _story_box != null and _story_box.visible
	if _state != null and _state.command_screen_active:
		_state.set_command_screen_active(false)
	_dialog.hide()
	_system_panel.hide()
	if _storage_panel != null:
		_storage_panel.hide()
	if _story_box != null:
		_story_box.hide()
	Input.mouse_mode = _previous_mouse_mode
	_hud_panel.show()
	if was_story and _state != null and (_current_dialogue_id.begins_with("ending_") or _current_dialogue_id == "mission_failure") and _mission_flow != null:
		_mission_flow.show_debrief()

func show_info(title: String, body: String) -> void:
	_enter_modal()
	_system_panel.hide()
	_storage_panel.hide()
	_story_box.hide()
	_dialog_title.text = title
	_dialog_body.text = body
	_dialog.visible = true
	_prompt.visible = false

func show_message(text: String) -> void:
	if is_modal_open():
		return
	_toast.text = text
	_toast.visible = true
	_toast_timer.start()

func _hide_toast() -> void:
	_toast.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_O) and not is_modal_open():
			toggle_objectives_tab()
			get_viewport().set_input_as_handled()
			return
	if not is_modal_open():
		if event is InputEventKey and event.pressed and not event.echo and _state != null:
			if event.physical_keycode == KEY_H:
				_quick_eat()
				get_viewport().set_input_as_handled()
			elif event.physical_keycode == KEY_J:
				_quick_drink()
				get_viewport().set_input_as_handled()
			elif event.physical_keycode == KEY_C:
				trigger_next_story_or_comms()
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()

func _quick_eat() -> void:
	if _state == null:
		return
	if _state.fresh_produce_portions > 0:
		_state.eat_fresh_produce()
		show_message(_state.greenhouse_status)
		return
	for recipe_id in ["dehydrated_meal", "ready_pouch"]:
		if _state.prepared_food.get(recipe_id, 0) > 0:
			_state.consume_prepared_food(recipe_id)
			show_message(_state.food_status)
			return
	for idx in range(_state.player_inventory.size()):
		var slot: Dictionary = _state.player_inventory[idx]
		var cat: String = State.ITEM_CATALOG.get(slot.get("id", ""), {}).get("category", "")
		if cat == "food" and slot.get("count", 0) > 0:
			_state.use_inventory_item(idx)
			show_message(_state.storage_status)
			return
	show_message("No prepared food in Food Supplies or Suit Pack! Open Food Cabinet or Storage.")

func _quick_drink() -> void:
	if _state == null:
		return
	if _state.prepared_food.get("powdered_drink", 0) > 0:
		_state.consume_prepared_food("powdered_drink")
		show_message(_state.food_status)
		return
	for idx in range(_state.player_inventory.size()):
		var slot: Dictionary = _state.player_inventory[idx]
		var cat: String = State.ITEM_CATALOG.get(slot.get("id", ""), {}).get("category", "")
		if cat == "drink" and slot.get("count", 0) > 0:
			_state.use_inventory_item(idx)
			show_message(_state.storage_status)
			return
	if _state.drink_direct_water():
		show_message(_state.food_status)
	else:
		show_message("No prepared drinks or potable water available!")
