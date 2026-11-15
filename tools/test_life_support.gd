extends SceneTree

const State = preload("res://scripts/life_support_state.gd")
var _failures := 0

func _initialize() -> void:
	set_meta("testing", true)
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		push_error(description)

func _near(actual: float, expected: float, description: String) -> void:
	_check(absf(actual - expected) < 0.00001, "%s: got %.8f, expected %.8f" % [description, actual, expected])

func _run() -> void:
	_test_food_resources()
	var state := State.new()
	var initial_mass := state.hydrogen_kg + state.oxygen_kg + state.water_kg
	state.set_running(true)
	state.advance(10.0)
	_near(state.hydrogen_kg, 0.75, "Hydrogen consumed")
	_near(state.oxygen_kg, 6.0, "Oxygen consumed by mass ratio")
	_near(state.water_kg, 2.45, "Water delivered")
	_near(state.energy_units, 25.0, "Energy stored")
	_near(state.hydrogen_kg + state.oxygen_kg + state.water_kg, initial_mass, "Mass conserved")
	state.set_running(false)
	state.advance(10.0)
	_near(state.water_kg, 2.45, "Stopped cell transfers nothing")
	state.set_running(true)
	state.advance(-1.0)
	state.advance(NAN)
	state.advance(INF)
	_near(state.water_kg, 2.45, "Invalid time ignored")

	# Running with a large step must stop exactly at the protected reserve.
	state.reset_demo()
	state.set_running(true)
	state.advance(100000.0)
	_near(state.oxygen_kg, State.OXYGEN_RESERVE, "Oxygen reserve protected")
	_check(not state.running, "Cell stops at reserve")
	state.set_running(true)
	_check(not state.running, "Cannot restart a blocked cell")
	state.set_reserve_protection(false)
	state.set_running(true)
	state.advance(100000.0)
	_near(state.oxygen_kg, 0.0, "Reserve can intentionally be spent")
	_check(not state.running, "Cell stops at depletion")

	# Output capacities cap the same transfer, not separate clamped outputs.
	for boundary in ["water", "energy", "hydrogen", "oxygen"]:
		state.reset_demo()
		state.set_reserve_protection(false)
		match boundary:
			"water": state.water_kg = State.WATER_CAPACITY - 0.09
			"energy": state.energy_units = State.ENERGY_CAPACITY - 1.0
			"hydrogen": state.hydrogen_kg = 0.01
			"oxygen": state.oxygen_kg = 0.08
		var before := [state.hydrogen_kg, state.oxygen_kg, state.water_kg, state.energy_units]
		state.set_running(true)
		state.advance(10000.0)
		_near(before[0] - state.hydrogen_kg, 0.01, boundary + " limits reaction extent")
		_near(before[1] - state.oxygen_kg, 0.08, boundary + " preserves oxygen ratio")
		_near(state.water_kg - before[2], 0.09, boundary + " preserves water ratio")
		_near(state.energy_units - before[3], 1.0, boundary + " preserves energy accounting")
		_check(not state.running, boundary + " stops production")
		_check(state.hydrogen_kg >= 0 and state.oxygen_kg >= 0, boundary + " no negative inputs")
		_check(state.water_kg <= State.WATER_CAPACITY and state.energy_units <= State.ENERGY_CAPACITY, boundary + " no overflow")

	# Same elapsed time produces the same result at different frame rates.
	var other := State.new()
	state.reset_demo()
	state.set_output_fraction(0.5)
	other.set_output_fraction(0.5)
	state.set_running(true)
	other.set_running(true)
	state.advance(60.0)
	for step in range(3600):
		other.advance(1.0 / 60.0)
	_near(state.water_kg, other.water_kg, "Frame-rate independent transfer")
	_near(state.energy_units, other.energy_units, "Frame-rate independent energy")
	state.free()
	other.free()

	# Main-scene wiring, all entry points, modal controls, and live readouts.
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	var scene := current_scene
	await process_frame
	var live: State = scene.get_node("LifeSupport")
	live.set_physics_process(false)
	live.survival_drain_enabled = false
	live.reset_demo()
	var ui := scene.get_node("InteractionUI")
	ui._intro_shown = true
	var player := scene.get_node("Player")
	var original_mouse_mode := Input.mouse_mode
	for tab in ["Overview", "Gas tanks", "Power", "Water", "Food", "Science"]:
		ui.show_system(tab, true)
		_check(ui.is_modal_open(), tab + " opens a modal")
		_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, tab + " releases cursor")
	var old_position: Vector3 = player.position
	Input.action_press("move_forward")
	player._physics_process(0.1)
	Input.action_release("move_forward")
	_near(player.position.x, old_position.x, "Modal blocks horizontal movement x")
	_near(player.position.z, old_position.z, "Modal blocks horizontal movement z")
	live.set_running(true)
	live.advance(10.0)
	var panel := ui.get_node("SystemPanel")
	_check(panel._totals.text.contains("0.450 kg"), "Panel reflects shared production")
	var equipment := scene.get_node("StationAdditions/LifeSupportEquipment")
	_check(equipment.get_node("WaterReadout").text.contains("2.45 kg"), "World tank reflects shared water")
	ui.close_panel()
	_check(not ui.is_modal_open(), "Closing restores gameplay")
	_check(Input.mouse_mode == original_mouse_mode, "Closing restores previous mouse mode")

	# Raycasts must reach the visible equipment rather than a wall or oversized
	# collider. Exercise the player's actual E dispatch into the shared panel.
	player.set_physics_process(false)
	var camera: Camera3D = player.get_node("Camera3D")
	var targets := [
		{"from": Vector3(-3.9, 0, -6.1), "at": Vector3(-3.9, 1.2, -8.8), "kind": "oxygen", "tab": 1},
		{"from": Vector3(-2.5, 0, -6.1), "at": Vector3(-2.5, 1.2, -8.8), "kind": "oxygen", "tab": 1},
		{"from": Vector3(-5.1, 0, -6.1), "at": Vector3(-5.1, 0.8, -8.25), "kind": "fuel_cell", "tab": 2},
		{"from": Vector3(-7.15, 0, -4.8), "at": Vector3(-7.15, 1.15, -7.25), "kind": "water", "tab": 3},
		{"from": Vector3(-5.8, 0, -2.0), "at": Vector3(-8.6, 2.13, -2.0), "kind": "food", "tab": 4},
		{"from": Vector3(0, 0, 6.5), "at": Vector3(0, 2.25, 9.372), "kind": "power_screen", "tab": 0},
	]
	for target in targets:
		player.position = target.from
		camera.look_at(target.at)
		await physics_frame
		player._update_interactable_focus()
		var focused: Node = player._focused_interactable
		_check(focused != null, target.kind + " reachable by interaction ray")
		if focused == null:
			continue
		_check(focused.interaction_type == target.kind, target.kind + " ray selects correct equipment")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		key.pressed = true
		player._unhandled_input(key)
		_check(ui.is_modal_open(), target.kind + " E opens panel")
		_check(panel._tabs.current_tab == target.tab, target.kind + " opens correct tab")
		var central: bool = target.kind == "power_screen"
		_check(panel._tabs.tabs_visible == central, target.kind + " navigation matches station scope")
		_check(panel._overview_button.visible == central, target.kind + " overview restricted to central control")
		_check(panel._reset_button.visible == central, target.kind + " reset restricted to central control")
		_check(panel._start.visible == (central or target.kind == "fuel_cell"), target.kind + " fuel-cell controls scoped")
		_check(panel._reserve.visible == (central or target.kind == "oxygen"), target.kind + " reserve control scoped")
		_check(panel._preview.visible == (central or target.kind == "fuel_cell"), target.kind + " preview scoped")
		for index in range(panel._tabs.get_tab_count()):
			_check(panel._tabs.is_tab_disabled(index) == (not central and index != target.tab), target.kind + " only permitted pages navigable")
		ui._input(key)
		_check(not ui.is_modal_open(), target.kind + " E closes panel")
	# A local panel must retain live state, including changes made elsewhere.
	ui.show_system("Water")
	live.advance(10.0)
	_check(panel._status.text.contains("0.045 kg/s"), "Local water panel shows live inflow")
	_check(panel._status.text.contains("9.100 kg"), "Local water capacity updates")
	ui.close_panel()
	ui.show_system("Overview", true)
	_check(panel._totals.text.contains("0.900 kg"), "Returning to central control retains production")
	_check(panel._tabs.current_tab == 0 and panel._tabs.tabs_visible, "Central control restores overview and tabs")
	ui.close_panel()
	live.reset_demo()
	ui.show_system("Food")
	panel._food_rows["dehydrated_meal"].button.pressed.emit()
	_near(live.water_kg, 1.7, "Food button consumes shared water")
	_check(panel._food_rows["dehydrated_meal"].inventory.text.contains("Prepared portions: 1"), "Local inventory immediately updates")
	_check(equipment.get_node("WaterReadout").text.contains("1.70 kg"), "World water gauge follows food consumption")
	# Spend the rest of the dry-meal stock. The drink now lacks water, while
	# ready-to-eat pouches remain usable.
	for portion in range(5):
		panel._food_rows["dehydrated_meal"].button.pressed.emit()
	_check(panel._food_rows["dehydrated_meal"].button.disabled, "Out-of-stock preparation disabled")
	_check(panel._food_rows["dehydrated_meal"].availability.text.contains("Out of stock"), "Stock shortage explained")
	_check(panel._food_rows["powdered_drink"].button.disabled, "Water shortage disables drink")
	_check(panel._food_rows["powdered_drink"].availability.text.contains("Not enough water"), "Water shortage explained")
	_check(not panel._food_rows["ready_pouch"].button.disabled, "Ready pouch available without preparation water")
	live.set_running(true)
	live.advance(8.0)
	_check(not panel._food_rows["powdered_drink"].button.disabled, "Fuel-cell water enables drink without reopening panel")
	panel._food_rows["powdered_drink"].button.pressed.emit()
	_check(live.prepared_food.powdered_drink == 1, "Replenished water prepares a drink")
	ui.close_panel()
	ui.show_system("Food", true)
	_check(panel._tabs.current_tab == 4 and panel._tabs.tabs_visible, "Central Food tab accessible")
	_check(panel._food_rows["dehydrated_meal"].inventory.text.contains("Prepared portions: 6"), "Prepared inventory persists across local and central screens")
	panel._reset_button.pressed.emit()
	_check(live.prepared_food.dehydrated_meal == 0 and live.food_stock.dehydrated_meal == 6, "Central reset restores food inventories")
	_near(live.water_kg, 2.0, "Central reset restores water")
	ui.close_panel()

	# Test new features: HUD bars, eating/drinking, power depletion from command screen & observations, storage UI, and story dialogue choices
	_check(ui._hud_panel != null and ui._hud_panel.visible, "First-person HUD is visible")
	_near(ui._hunger_bar.value, 82.0, "HUD displays initial hunger")
	_near(ui._hydration_bar.value, 78.0, "HUD displays initial hydration")
	_near(ui._oxygen_bar.value, 98.0, "HUD displays initial oxygen purity")

	# Prepare and eat food + drink water -> improves HUD bars
	live.hunger = 50.0
	live.hydration = 40.0
	live.prepare_food("dehydrated_meal")
	_check(live.consume_prepared_food("dehydrated_meal"), "Eating prepared meal succeeds")
	_check(live.hunger > 50.0, "Eating food improves hunger bar on HUD")
	_near(ui._hunger_bar.value, live.hunger, "HUD hunger bar reflects eaten food")
	_check(live.drink_direct_water(), "Drinking potable water succeeds")
	_check(live.hydration > 60.0, "Drinking water improves hydration bar on HUD")
	_near(ui._hydration_bar.value, live.hydration, "HUD hydration bar reflects water drank")

	# Using command screen & Science observation depletes electricity
	var energy_before_screen := live.energy_units
	ui.show_system("Overview", true)
	_check(live.energy_units < energy_before_screen, "Opening command screen depletes electricity")
	live.survival_drain_enabled = true
	var energy_before_tick := live.energy_units
	live.advance_station_systems(5.0)
	_check(live.energy_units < energy_before_tick, "Active command screen & scrubber deplete station power over time")
	live.survival_drain_enabled = false
	ui.close_panel()

	# Storage compartment opens Storage UI and allows item transfers
	ui.show_storage("StationStorageContainer", "Main Stowage Container")
	_check(ui._storage_panel.visible and ui.is_modal_open(), "Opening storage compartment exposes Storage UI")
	_check(live.transfer_container_to_player("StationStorageContainer", 0), "Transfer item from storage container to player suit pack")
	_check(live.transfer_player_to_container("StationStorageContainer", 0), "Place item from player suit pack into storage container")
	ui.close_panel()

	# Story dialogue box at bottom of screen with choices
	ui.start_story_dialogue("arrival_intro")
	_check(ui._story_box.visible and ui.is_modal_open(), "Story dialogue box appears at bottom of screen")
	_check(ui._story_choices_box.get_child_count() >= 2, "Story dialogue displays interactive choice buttons")
	ui.close_panel()

	# Expandable Objectives Tab on HUD
	_check(ui._objectives_toggle_btn != null, "Objectives tab button exists on HUD")
	_check(not ui._objectives_expanded, "Objectives drawer starts collapsed")
	ui._objectives_toggle_btn.pressed.emit()
	_check(ui._objectives_expanded and ui._objectives_container.visible, "Clicking Objectives tab expands objective checklist")
	_check(ui._objectives_list_box.get_child_count() == 5, "All 5 clear mission objectives are listed")
	ui._objectives_toggle_btn.pressed.emit()
	_check(not ui._objectives_expanded, "Clicking Objectives tab again collapses it")

	scene.queue_free()
	await process_frame
	print("Life support checks: %s" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	quit(0 if _failures == 0 else 1)

func _test_food_resources() -> void:
	var state := State.new()
	var independent := State.new()
	var initial_mass := state.hydrogen_kg + state.oxygen_kg + state.water_kg
	_check(state.prepare_food("dehydrated_meal"), "Dry meal can be prepared")
	_near(state.water_kg, 1.7, "Dry meal water cost")
	_check(state.food_stock.dehydrated_meal == 5 and state.prepared_food.dehydrated_meal == 1, "One package becomes one portion")
	_check(independent.food_stock.dehydrated_meal == 6, "Inventories are not shared between state instances")
	_check(state.prepare_food("ready_pouch"), "Ready pouch can be opened")
	_near(state.water_kg, 1.7, "Ready pouch uses no preparation water")
	_check(state.prepare_food("powdered_drink"), "Drink can be mixed")
	_near(state.water_kg, 1.45, "Drink water cost")
	_near(state.water_kg + state.food_water_used_kg, 2.0, "Preparation accounts for water held in food")
	state.set_running(true)
	state.advance(10.0)
	_near(state.hydrogen_kg + state.oxygen_kg + state.water_kg + state.food_water_used_kg, initial_mass, "Production and preparation conserve accounted mass")

	state.reset_demo()
	state.water_kg = 0.29
	_check(not state.prepare_food("dehydrated_meal"), "Insufficient water rejected")
	_near(state.water_kg, 0.29, "Failed preparation does not consume water")
	_check(state.food_stock.dehydrated_meal == 6 and state.prepared_food.dehydrated_meal == 0, "Failed preparation leaves inventory intact")
	_check(not state.prepare_food("unknown"), "Unknown recipe rejected")
	state.water_kg = 0.30
	_check(state.prepare_food("dehydrated_meal"), "Exact water amount accepted")
	_near(state.water_kg, 0.0, "Exact preparation leaves no water")
	_check(state.prepare_food("ready_pouch"), "Pouch can be opened at zero tank water")
	for attempt in range(10):
		state.prepare_food("ready_pouch")
	_check(state.food_stock.ready_pouch == 0 and state.prepared_food.ready_pouch == 4, "Repeated requests cannot duplicate finite stock")
	_check(not state.prepare_food("ready_pouch"), "Exhausted stock rejected")
	_near(state.water_kg, 0.0, "No-water recipes never subtract water")

	state.reset_demo()
	state.water_kg = State.WATER_CAPACITY
	state.set_running(true)
	_check(not state.running, "Full tank blocks production")
	state.prepare_food("dehydrated_meal")
	_check(state.blocking_reason().is_empty() and not state.running, "Food frees capacity without auto-starting fuel cell")
	state.set_running(true)
	state.advance(1.0)
	_check(state.water_kg > State.WATER_CAPACITY - 0.3, "Production can resume after preparation")
	state.reset_demo()
	_check(state.food_stock == State.INITIAL_FOOD_STOCK, "Reset restores every food stock")
	_check(state.prepared_food == {"dehydrated_meal": 0, "ready_pouch": 0, "powdered_drink": 0}, "Reset clears prepared portions")
	_near(state.food_water_used_kg, 0.0, "Reset clears preparation water accounting")
	state.free()
	independent.free()
