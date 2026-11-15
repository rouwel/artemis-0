extends SceneTree

const State = preload("res://scripts/life_support_state.gd")
const API = preload("res://scripts/nasa_api_client.gd")
var failures := 0

func _initialize() -> void:
	set_meta("testing", true)
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func near(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < 0.00001, "%s: %.8f != %.8f" % [message, actual, expected])

func _water_total(state: State) -> float:
	return state.water_kg + state.condensate_kg + state.greenhouse_biomass_water_kg

func _grow_state() -> State:
	var state := State.new()
	state.reset_demo()
	state.plant_crop()
	state.set_greenhouse_active(true)
	return state

func _run() -> void:
	_test_greenhouse()
	_test_parsers()
	change_scene_to_file("res://scenes/main.tscn")
	await scene_changed
	await process_frame
	var state: State = current_scene.get_node("LifeSupport")
	state.set_physics_process(false)
	state.reset_demo()
	var ui := current_scene.get_node("InteractionUI")
	var api: Node = ui._nasa_api
	var original: Array = api.records.duplicate(true)
	check(not original.is_empty(), "Catalogue loads offline without a key or request")
	check(not api.busy, "Entering the scene does not start a network request")
	for response in [
		[HTTPRequest.RESULT_TIMEOUT, 0, ""],
		[HTTPRequest.RESULT_SUCCESS, 429, "{}"],
		[HTTPRequest.RESULT_SUCCESS, 503, "{}"],
		[HTTPRequest.RESULT_SUCCESS, 200, "not JSON"],
		[HTTPRequest.RESULT_SUCCESS, 200, "{\"near_earth_objects\": 42}"],
	]:
		api._on_response(response[0], response[1], PackedStringArray(), str(response[2]).to_utf8_buffer())
		check(api.records == original and not api.busy, "Failed refresh preserves valid cached records")
	check(api._next_request_msec > Time.get_ticks_msec(), "Rate limiting establishes a cooldown")
	var energy_before := state.energy_units
	ui._system_panel._select_science_view("NASA catalogue")
	near(state.energy_units, energy_before, "Browsing real catalogue has no mission resource cost")
	check(state.tracking_observations_submitted == 0 and not state.decision_made, "Real data cannot advance the fictional story")
	var rack := current_scene.get_node("StationAdditions/Greenhouse/HydroponicGrowRack")
	var player := current_scene.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector3(-5.8, 0, -4.6)
	player.get_node("Camera3D").look_at(Vector3(-8.55, 1.2, -4.6))
	await physics_frame
	player._update_interactable_focus()
	check(player._focused_interactable == rack, "Grow rack reachable through the real interaction ray")
	rack.interact()
	var panel: Control = ui._system_panel
	check(panel._tabs.current_tab == 6 and not panel._tabs.tabs_visible, "Rack opens only the dedicated Greenhouse panel")
	for index in range(6):
		check(panel._tabs.is_tab_disabled(index), "Rack cannot access another system tab")
	var controls: Control = panel._greenhouse_panels[1]
	controls._plant.pressed.emit()
	controls._toggle.pressed.emit()
	state.advance_greenhouse(180.0)
	check(not controls._harvest.disabled, "Completed crop enables Harvest")
	controls._harvest.pressed.emit()
	check(controls._harvest.disabled and not controls._eat.disabled, "Harvest button cannot duplicate the crop")
	ui.close_panel()
	ui.show_system("Food")
	check(not panel._greenhouse_panels[0].visible, "Local food cabinet stays food-only")
	ui.close_panel()
	ui.show_system("Food", true)
	check(panel._greenhouse_panels[0].visible, "Central Food exposes greenhouse controls")
	check(panel._greenhouse_panels[0]._summary.text.contains("Fresh portions: 2"), "Central and local inventory agree")
	ui.close_panel()
	var purity := state.oxygen_purity
	ui._quick_eat()
	check(state.fresh_produce_portions == 1, "Quick-eat consumes a fresh portion")
	near(state.oxygen_purity, purity, "Eating fresh produce cannot create cabin oxygen")
	state.reset_demo()
	check(state.seed_kits == 2 and state.fresh_produce_portions == 0 and not state.crop_planted, "Reset restores all growing inventory")
	current_scene.queue_free()
	await process_frame
	print("Greenhouse / NASA checks: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)

func _test_greenhouse() -> void:
	var state := _grow_state()
	check(state.seed_kits == 1 and not state.plant_crop(), "Planting spends exactly one finite kit")
	state.advance_greenhouse(-1.0)
	state.advance_greenhouse(INF)
	state.advance_greenhouse(NAN)
	near(state.crop_growth_percent, 0, "Invalid time cannot grow a crop")
	state.advance_greenhouse(180.0)
	near(state.crop_growth_percent, 100, "Crop completes in 180 active seconds")
	near(state.energy_units, 5.6, "A full crop consumes 14.4 EU")
	near(state.water_kg, 1.28, "A full crop uses 0.720 kg tank water")
	near(state.condensate_kg, 0.648, "90% is retained as recoverable condensate")
	near(state.greenhouse_biomass_water_kg, 0.072, "Crop water remains accounted for")
	near(_water_total(state), 2.0, "Growth conserves all accounted water")
	check(not state.greenhouse_active, "A mature crop stops consuming resources")
	check(state.harvest_crop() and not state.harvest_crop(), "Harvest succeeds once")
	check(state.fresh_produce_portions == 2, "Harvest creates exactly two finite portions")
	state.recover_greenhouse_water()
	near(state.water_kg, 1.928, "Condensate returns to shared tank")
	near(state.energy_units, 5.4704, "Recovery spends electrical energy")
	near(_water_total(state), 2.0, "Recovery conserves water")
	check(not state.recover_greenhouse_water(), "Empty collector cannot duplicate water")
	state.eat_fresh_produce()
	state.eat_fresh_produce()
	check(not state.eat_fresh_produce(), "Produce cannot be eaten more than once")
	near(_water_total(state), 2.0, "Eating retains crop-water accounting")
	state.free()
	for boundary in ["energy", "water", "collector"]:
		state = _grow_state()
		match boundary:
			"energy": state.energy_units = 0.001
			"water": state.water_kg = 0.001
			"collector": state.condensate_kg = State.CONDENSATE_CAPACITY - 0.001
		var total := _water_total(state)
		state.advance_greenhouse(10000.0)
		check(not state.greenhouse_active, boundary + " stops the rack")
		near(_water_total(state), total, boundary + " preserves water")
		check(state.energy_units >= 0 and state.water_kg >= 0 and state.condensate_kg <= State.CONDENSATE_CAPACITY + State.EPSILON, boundary + " stays bounded")
		state.free()
	var slow := _grow_state()
	var fast := _grow_state()
	slow.advance_greenhouse(90.0)
	for step in range(5400):
		fast.advance_greenhouse(1.0 / 60.0)
	near(fast.crop_growth_percent, slow.crop_growth_percent, "Growth is frame-rate independent")
	near(fast.energy_units, slow.energy_units, "Growing energy is frame-rate independent")
	near(fast.water_kg, slow.water_kg, "Growing water is frame-rate independent")
	slow.set_greenhouse_active(false)
	slow.advance_greenhouse(90.0)
	near(slow.crop_growth_percent, 50, "Pausing preserves crop progress")
	slow.condensate_kg = 0.5
	slow.water_kg = State.WATER_CAPACITY
	check(not slow.recover_greenhouse_water(), "Full water tank blocks recovery")
	slow.water_kg -= 0.01
	var total := _water_total(slow)
	slow.recover_greenhouse_water()
	near(slow.water_kg, State.WATER_CAPACITY, "Partial recovery fills but never overflows tank")
	near(_water_total(slow), total, "Partial recovery leaves excess condensate intact")
	slow.free()
	fast.free()

func _test_parsers() -> void:
	var snapshot = JSON.parse_string(FileAccess.get_file_as_string(API.SNAPSHOT))
	check(API.validate_snapshot(snapshot).ok, "Bundled snapshot matches versioned key-free schema")
	var record: Dictionary = snapshot.records[0]
	var fixture := {"element_count": 1, "near_earth_objects": {record.date: [{
		"neo_reference_id": record.id, "name": record.name,
		"is_potentially_hazardous_asteroid": record.hazardous,
		"absolute_magnitude_h": record.absolute_magnitude_h,
		"estimated_diameter": {"meters": {"estimated_diameter_min": record.diameter_min_m, "estimated_diameter_max": record.diameter_max_m}},
		"close_approach_data": [
			{"close_approach_date": "1999-01-01", "orbiting_body": "Earth"},
			{"close_approach_date": record.date, "orbiting_body": "Earth",
			"relative_velocity": {"kilometers_per_second": str(record.velocity_km_s)},
			"miss_distance": {"kilometers": str(record.miss_distance_km), "lunar": str(record.miss_distance_lunar)}}
		]
	}]}}
	var parsed := API.parse_feed(fixture)
	check(parsed.ok and parsed.records.size() == 1, "Parser selects matching encounter rather than first approach")
	near(parsed.records[0].velocity_km_s, record.velocity_km_s, "Velocity unit remains km/s")
	near(parsed.records[0].diameter_min_m, record.diameter_min_m, "Diameter unit remains metres")
	for bad in [null, [], {}, {"near_earth_objects": []}, {"near_earth_objects": {"2011-01-01": []}}]:
		check(not API.parse_feed(bad).ok, "Malformed or wrong-period feed is rejected")
	var corrupt: Dictionary = snapshot.duplicate(true)
	corrupt.records[0].diameter_min_m = -1.0
	check(not API.validate_snapshot(corrupt).ok, "Negative dimensions invalidate disk cache")
	corrupt = snapshot.duplicate(true)
	corrupt.records[0].velocity_km_s = "10"
	check(not API.validate_snapshot(corrupt).ok, "Cache must contain normalized numeric fields")
	fixture.near_earth_objects[record.date][0].close_approach_data[1].miss_distance.kilometers = "NaN"
	check(not API.parse_feed(fixture).ok, "Nonfinite API numbers are rejected")
