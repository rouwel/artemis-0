extends SceneTree

const State = preload("res://scripts/life_support_state.gd")
const Story = preload("res://scripts/story_database.gd")
const SystemPanel = preload("res://scripts/system_panel.gd")
var failures := 0

func _initialize() -> void:
	set_meta("testing", true)
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func near(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < 0.00001, "%s (%.8f != %.8f)" % [message, actual, expected])

func _stabilize(state: State) -> void:
	state.set_running(true)
	state.advance(12.0)
	state.set_running(false)
	state.ever_opened_storage = true
	state.drink_direct_water()
	state.get_objectives()

func _run() -> void:
	_test_resources()
	_test_story_transactions()
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	await process_frame
	var state: State = current_scene.get_node("LifeSupport")
	state.set_physics_process(false)
	state.reset_demo()
	var ui := current_scene.get_node("InteractionUI")
	var panel := ui.get_node("SystemPanel")
	# Objective and inventory controls survive normal simulation updates.
	ui.show_storage("StationStorageContainer")
	var first_card: Node = ui._container_grid.get_child(0)
	var first_objective: Node = ui._objectives_list_box.get_child(0)
	state.advance_station_systems(0.1)
	check(ui._container_grid.get_child(0) == first_card, "Inventory cards remain stable during resource ticks")
	check(ui._objectives_list_box.get_child(0) == first_objective, "Objectives remain stable during resource ticks")
	# Real button dispatch must transfer only one item.
	var before: int = state.containers.StationStorageContainer.slots[0].count
	var take := first_card.get_child(0).get_child(2).get_child(0)
	take.pressed.emit()
	check(state.containers.StationStorageContainer.slots[0].count == before - 1, "Storage Take button transfers exactly one item")
	ui.close_panel()
	_stabilize(state)
	# Dismiss/resume must preserve an intermediate conversation node.
	ui.start_story_dialogue("arrival_intro")
	ui._on_story_choice_selected(Story.DIALOGUES.arrival_intro.choices[1])
	check(state.pending_dialogue == "arrival_question", "Dialogue choice advances the saved conversation")
	ui.close_panel()
	ui.trigger_next_story_or_comms()
	check(ui._current_dialogue_id == "arrival_question", "Comms resumes interrupted conversation")
	ui.close_panel()
	# The dedicated radar station must not expose the central dashboard.
	var station := current_scene.get_node("StationAdditions/OperationsZone/AstrometryWorkstation") if current_scene.has_node("StationAdditions/OperationsZone/AstrometryWorkstation") else current_scene.find_child("AstrometryWorkstation", true, false)
	check(station != null, "Radar workstation is present")
	if station != null:
		station.interact()
		check(panel._tabs.current_tab == 5 and not panel._tabs.tabs_visible, "Radar station exposes only Science")
		check(not panel._reset_button.visible, "Radar station cannot reset the mission")
	ui.close_panel()
	# Actual manual invalid packet, persistent feedback, then all three locks.
	ui.show_system("Science")
	panel._science_azimuth.text = "0"
	panel._submit_tracking_packet()
	var validation_text: String = panel._science_feedback.text
	state.advance_station_systems(0.1)
	check(panel._science_feedback.text == validation_text, "Validation feedback survives live resource refresh")
	check(state.tracking_observations_submitted == 0, "Invalid alignment does not transmit")
	for index in range(3):
		ui.show_system("Science")
		panel._autofill_next_packet()
		var energy_before: float = state.energy_units
		panel._submit_tracking_packet()
		check(state.tracking_observations_submitted == index + 1, "Observation %d progresses once" % index)
		near(state.energy_units, energy_before - 1.0, "Observation charges exactly one EU")
		check(not state.command_screen_active, "Story transition stops command-screen drain")
		ui.close_panel()
	check(state.assisted_locks == 3, "Assisted observations are counted")
	# Energy can change after a choice is displayed. Validate at execution.
	state.energy_units = 20.0
	ui.start_story_dialogue("obs_3_climax")
	state.energy_units = 19.0
	ui._on_story_choice_selected(Story.DIALOGUES.obs_3_climax.choices[0])
	check(not state.decision_made, "A stale launch choice cannot bypass energy cost")
	state.energy_units = 25.0
	state.changed.emit()
	check(not ui._story_choices_box.get_child(0).disabled, "Launch button refreshes after charging")
	ui._on_story_choice_selected(Story.DIALOGUES.obs_3_climax.choices[0])
	check(state.decision_made and state.asteroid_redirected_to_moon, "Launch succeeds with sufficient power")
	near(state.energy_units, 5.0, "Launch spends 20 EU")
	ui._on_story_choice_selected(Story.DIALOGUES.choice_tell_berna.choices[0])
	check(not state.ending_reached.is_empty(), "Truth choice reaches the epilogue")
	check(not state.apply_story_effect("keep_ship"), "Completed decision is immutable")
	ui.close_panel()
	# Exercise the real mission shell: pause, debrief, exploration, restart.
	var flow := preload("res://scripts/mission_flow.gd").new()
	ui.add_child(flow)
	check(paused and flow._root.visible, "Title menu pauses the world")
	var water_before := state.water_kg
	await process_frame
	near(state.water_kg, water_before, "Paused menu preserves resources")
	flow.show_debrief()
	check(flow._page == "debrief" and paused, "Debrief is an explicit end state")
	flow._explore()
	check(not paused and flow._exploring, "Explore resumes the world without mission drain")
	flow.show_menu("pause")
	flow._open_settings("pause")
	check(flow._page == "settings", "Settings are accessible from pause")
	flow._resume()
	current_scene.queue_free()
	await process_frame
	print("Mission checks: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)

func _test_resources() -> void:
	var state := State.new()
	state.reset_demo()
	state.scrubber_active = false
	state.set_electrolyzer_active(true)
	var before_mass := state.hydrogen_kg + state.oxygen_kg + state.water_kg
	state.advance_station_systems(1.0)
	near(state.hydrogen_kg, 0.804, "Electrolysis produces hydrogen")
	near(state.water_kg, 1.964, "Electrolysis consumes water")
	near(state.energy_units, 19.4, "Electrolysis consumes 0.60 EU")
	near(state.hydrogen_kg + state.oxygen_kg + state.water_kg + state.oxygen_consumed_kg, before_mass, "Electrolysis accounts for mass including respiration")
	check(State.ELECTROLYZER_ENERGY_PER_SEC > 0.004 * State.ENERGY_PER_KG_HYDROGEN, "Round trip cannot generate free electricity")
	for boundary in ["hydrogen", "oxygen", "water", "energy"]:
		state.reset_demo()
		state.scrubber_active = false
		state.electrolyzer_active = true
		match boundary:
			"hydrogen": state.hydrogen_kg = State.HYDROGEN_CAPACITY - 0.0001
			"oxygen": state.oxygen_kg = State.OXYGEN_CAPACITY - 0.0001
			"water": state.water_kg = 0.0001
			"energy": state.energy_units = 0.0001
		before_mass = state.hydrogen_kg + state.oxygen_kg + state.water_kg
		state.advance_station_systems(2.0)
		near(state.hydrogen_kg + state.oxygen_kg + state.water_kg + state.oxygen_consumed_kg, before_mass, boundary + " capacity preserves mass")
		check(state.water_kg >= 0 and state.energy_units >= 0 and state.oxygen_kg <= State.OXYGEN_CAPACITY + State.EPSILON and state.hydrogen_kg <= State.HYDROGEN_CAPACITY + State.EPSILON, boundary + " remains bounded")
	state.reset_demo()
	state.energy_units = 0.5
	check(not state.spend_energy(1.0), "Insufficient energy rejects an atomic action")
	near(state.energy_units, 0.5, "Failed action does not consume partial payment")
	state.reset_demo()
	state.water_produced_kg = 0.49
	state.energy_units = 23.0
	check(not state.get_objectives()[0].done, "Water and battery targets must both be met")
	state.water_produced_kg = 0.5
	check(state.get_objectives()[0].done, "Exact objective threshold succeeds")
	state.energy_units = 1.0
	check(state.get_objectives()[0].done, "Completed objective stays complete")
	state.ever_opened_storage = true
	check(not state.get_objectives()[1].done, "Opening storage alone is insufficient")
	state.drink_direct_water()
	check(state.get_objectives()[1].done, "Inspection plus consumption satisfies supplies objective")
	state.reset_demo()
	state.energy_units = 0.0
	state.oxygen_purity = 30.0
	state.advance_station_systems(1.0)
	check(not state.scrubber_active, "Power loss stops the scrubber")
	check(state.use_inventory_item(2, "StationStorageContainer"), "An emergency power cell restores power")
	state.set_scrubber_active(true)
	var air_before := state.oxygen_purity
	state.advance_station_systems(5.0)
	check(state.oxygen_purity > air_before and state.energy_units > 0, "Stored supplies and scrubber control recover the emergency")
	check(state.emergency_items_used == 1, "Emergency supply use appears in debrief accounting")
	state.reset_demo()
	state.hydration = 0.001
	state.advance_station_systems(1.0)
	check(state.mission_failed and not state.running, "Zero vital ends the mission")
	state.reset_demo()
	check(not state.mission_failed and state.pending_dialogue == "arrival_intro", "Reset restores mission state")
	state.free()

func _test_story_transactions() -> void:
	for launch in [true, false]:
		for truth in [true, false]:
			var state := State.new()
			state.reset_demo()
			state.record_tracking_observation(SystemPanel.TRACKING_PACKETS[0])
			check(state.tracking_observations_submitted == 0, "Tracking requires habitat stabilization")
			_stabilize(state)
			for packet in SystemPanel.TRACKING_PACKETS:
				state.record_tracking_observation(packet)
			check(state.tracking_observations_submitted == 3, "Three valid observations advance the story")
			state.energy_units = 25.0
			check(state.apply_story_effect("launch_intercept" if launch else "keep_ship"), "Final decision succeeds")
			check(state.apply_story_effect("told_truth" if truth else "hid_truth"), "Each ending is reachable")
			check(state.asteroid_redirected_to_moon == launch and state.told_berna_truth == truth, "Ending preserves both choices")
			var energy_before := state.energy_units
			check(not state.apply_story_effect("launch_intercept"), "Repeated ending cannot spend power")
			near(state.energy_units, energy_before, "Completed ending is stable")
			state.free()
