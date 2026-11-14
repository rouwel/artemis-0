extends Node
class_name LifeSupportState

## Shared, scene-local resource, food, survival, storage, power load, and story simulation.
## Kilograms use rounded 1:8:9 stoichiometry. Energy units, rates, and meal water costs are teaching values.
signal changed
signal story_triggered(dialogue_id: String)
signal feedback(cue: String)

const HYDROGEN_CAPACITY := 1.0
const OXYGEN_CAPACITY := 8.0
const WATER_CAPACITY := 12.0
const ENERGY_CAPACITY := 100.0
const OXYGEN_RESERVE := 1.6
const HYDROGEN_RATE := 0.005
const ENERGY_PER_KG_HYDROGEN := 100.0
const EPSILON := 0.000001
const GROW_SECONDS := 180.0
const GROW_POWER_PER_SEC := 0.08
const GROW_WATER_PER_SEC := 0.004
const GROW_RECOVERY_FRACTION := 0.90
const CONDENSATE_CAPACITY := 1.0
const RECOVERY_ENERGY_PER_KG := 0.20
const HARVEST_PORTIONS := 2

## Power & life-support load constants (favorable, balanced rates so battery lasts a long time)
const COMMAND_SCREEN_OPEN_COST := 0.20
const COMMAND_SCREEN_DRAIN_PER_SEC := 0.015
const OBSERVATION_SCAN_ENERGY_COST := 1.0
const SCRUBBER_ENERGY_PER_SEC := 0.008
const ELECTROLYZER_ENERGY_PER_SEC := 0.60
const ELECTROLYZER_WATER_PER_SEC := 0.036 # 0.004 kg H2 + 0.032 kg O2 = 0.036 kg H2O
const RETURN_ROCKET_ENERGY_COST := 20.0

## Crew survival drain rates (gentle for 20-minute gameplay)
const HUNGER_DRAIN_PER_SEC := 0.04
const HYDRATION_DRAIN_PER_SEC := 0.055
const OXYGEN_PURITY_DECAY_NO_SCRUBBER := 0.12
const OXYGEN_PURITY_RECOVERY_WITH_SCRUBBER := 0.40

const FOOD_RECIPES := {
	"dehydrated_meal": {
		"name": "Dehydrated vegetable meal", "action": "Hydrate meal", "water_kg": 0.30,
		"description": "Freeze-dried food needs water before it is ready to eat.",
		"hunger_restore": 38.0, "hydration_restore": 8.0, "consume_verb": "Eat meal"
	},
	"ready_pouch": {
		"name": "Ready-to-eat stew pouch", "action": "Open pouch", "water_kg": 0.0,
		"description": "A thermostabilized pouch already contains moisture. No rehydration needed.",
		"hunger_restore": 28.0, "hydration_restore": 12.0, "consume_verb": "Eat pouch"
	},
	"powdered_drink": {
		"name": "Powdered fruit drink", "action": "Mix drink", "water_kg": 0.25,
		"description": "Add potable water to turn one powder packet into a prepared drink.",
		"hunger_restore": 5.0, "hydration_restore": 42.0, "consume_verb": "Drink"
	},
}
const INITIAL_FOOD_STOCK := {"dehydrated_meal": 6, "ready_pouch": 4, "powdered_drink": 4}
const FOOD_READY_MESSAGE := "Select a supply below. Costs are shown before you prepare one portion."

## Item catalog for Storage Containers & Player Backpack
const ITEM_CATALOG := {
	"seed_kit": {
		"name": "Microgreens Seed & Nutrient Kit",
		"category": "growing",
		"description": "One finite seed and nutrient kit for a greenhouse crop. Use to move it into the grow rack's supplies."
	},
	"hot_sauce": {
		"name": "Space Hot Sauce",
		"category": "condiment",
		"description": "A spicy condiment for familiar flavours. A small morale moment; it creates no calories, water or oxygen."
	},
	"dehydrated_meal_pkg": {
		"name": "Sealed Veggie Meal",
		"category": "food_pkg",
		"recipe_id": "dehydrated_meal",
		"description": "Freeze-dried vegetable ration. Can be transferred to Food Supplies or hydrated & eaten."
	},
	"ready_pouch_pkg": {
		"name": "Thermostabilized Stew",
		"category": "food",
		"hunger": 28.0,
		"hydration": 12.0,
		"description": "Ready-to-eat space stew pouch. Restores +28% Hunger and +12% Hydration."
	},
	"water_pouch": {
		"name": "Potable Water Pouch (0.25 kg)",
		"category": "drink",
		"hunger": 0.0,
		"hydration": 35.0,
		"description": "Emergency drinking water pouch. Restores +35% Hydration immediately."
	},
	"protein_bar": {
		"name": "Lunar Ration Bar",
		"category": "food",
		"hunger": 25.0,
		"hydration": -3.0,
		"description": "Dense caloric bar. Restores +25% Hunger."
	},
	"power_cell": {
		"name": "Backup Li-Ion Power Cell",
		"category": "utility",
		"energy": 15.0,
		"description": "Emergency battery cartridge. Discharges +15.0 EU into the station power bus."
	},
	"o2_candle": {
		"name": "Chlorate O₂ Candle",
		"category": "utility",
		"oxygen_kg": 0.60,
		"description": "Chemical oxygen generator. Adds up to 0.60 kg O₂ to the reserve. Does not remove CO₂; keep the powered scrubber running."
	},
	"berna_photo": {
		"name": "Framed Photo of Berna",
		"category": "keepsake",
		"description": "A Polaroid from 2009. On the back: 'Come back to Earth safe. — Berna'"
	},
	"pearl_treats": {
		"name": "Pearl's Freeze-Dried Salmon",
		"category": "keepsake",
		"description": "A keepsake pouch of feline treats for Pearl the station cat."
	}
}

const INITIAL_CONTAINERS := {
	"StationStorageContainer": {
		"title": "Main Stowage Container",
		"slots": [
			{"id": "water_pouch", "count": 2},
			{"id": "protein_bar", "count": 2},
			{"id": "power_cell", "count": 1},
			{"id": "dehydrated_meal_pkg", "count": 2},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
		]
	},
	"WallLocker_1": {
		"title": "Crew Locker 01 (Personal & Habitation)",
		"slots": [
			{"id": "berna_photo", "count": 1},
			{"id": "pearl_treats", "count": 2},
			{"id": "ready_pouch_pkg", "count": 2},
			{"id": "water_pouch", "count": 1},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
		]
	},
	"WallLocker_2": {
		"title": "Crew Locker 02 (Emergency Life Support)",
		"slots": [
			{"id": "o2_candle", "count": 2},
			{"id": "power_cell", "count": 2},
			{"id": "water_pouch", "count": 1},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
		]
	},
	"SupplyCrate_1": {
		"title": "Supply Crate Alpha (Rations)",
		"slots": [
			{"id": "protein_bar", "count": 3},
			{"id": "ready_pouch_pkg", "count": 2},
			{"id": "dehydrated_meal_pkg", "count": 2},
			{"id": "seed_kit", "count": 2},
			{"id": "hot_sauce", "count": 2},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
		]
	},
	"SupplyCrate_2": {
		"title": "Supply Crate Beta (Technical Stores)",
		"slots": [
			{"id": "power_cell", "count": 1},
			{"id": "o2_candle", "count": 1},
			{"id": "water_pouch", "count": 2},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
			{"id": "", "count": 0},
		]
	}
}

const INITIAL_PLAYER_INVENTORY := [
	{"id": "protein_bar", "count": 1},
	{"id": "water_pouch", "count": 1},
	{"id": "", "count": 0},
	{"id": "", "count": 0},
	{"id": "", "count": 0},
	{"id": "", "count": 0},
	{"id": "", "count": 0},
	{"id": "", "count": 0},
]

var hydrogen_kg := 0.8
var oxygen_kg := 6.4
var water_kg := 2.0
var energy_units := 20.0
var water_produced_kg := 0.0
var energy_produced_units := 0.0
var energy_consumed_units := 0.0
var running := false
var output_fraction := 1.0
var protect_oxygen_reserve := true
var status := "Ready — start the fuel cell to transfer resources."
var food_stock: Dictionary = INITIAL_FOOD_STOCK.duplicate()
var prepared_food := {"dehydrated_meal": 0, "ready_pouch": 0, "powdered_drink": 0}
var food_water_used_kg := 0.0
var food_status: String = FOOD_READY_MESSAGE
var tracking_observations_submitted := 0
var tracking_status := "No observation packets transmitted."
var tracking_log: Array[Dictionary] = []

## Player Survival Stats (0..100)
var hunger := 82.0
var hydration := 78.0
var oxygen_purity := 98.0
var survival_drain_enabled := false

## Connected Station Systems
var scrubber_active := true
var electrolyzer_active := false
var command_screen_active := false
var _low_power_warned := false

## Story & Choices State
var story_phase := 0
var asteroid_distance_km := 12400.0
var asteroid_redirected_to_moon := false
var berna_relationship := "Connected"
var told_berna_truth := false
var ending_reached := ""
var comm_history: Array[Dictionary] = []
var ever_ate_or_drank := false
var ever_opened_storage := false
var power_objective_complete := false
var supplies_objective_complete := false
var pending_dialogue := "arrival_intro"
var decision_made := false
var mission_failed := false
var mission_seconds := 0.0
var oxygen_consumed_kg := 0.0
var emergency_items_used := 0
var assisted_locks := 0
var _air_warned := false
var _needs_warned := false
var greenhouse_active := false
var crop_planted := false
var crop_growth_percent := 0.0
var seed_kits := 2
var fresh_produce_portions := 0
var condensate_kg := 0.0
var greenhouse_biomass_water_kg := 0.0
var greenhouse_water_used_kg := 0.0
var greenhouse_water_recovered_kg := 0.0
var greenhouse_energy_used := 0.0
var crops_harvested := 0
var greenhouse_status := "Plant a seed and nutrient kit, then switch on the grow lights and misting."

## Storage & Inventory State
var containers: Dictionary = {}
var player_inventory: Array = []
var storage_status := "Click an item to transfer between your Suit Pack and the Storage Compartment, or use it directly."

func _ready() -> void:
	_reset_inventories()
	# Enable live survival/power tick only when running inside the actual playable scene
	if get_parent() != null and get_parent().name == "Main":
		survival_drain_enabled = true

func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or mission_failed or not ending_reached.is_empty():
		return
	# Small shared steps keep production and demand ordered consistently.
	var remaining := delta
	while remaining > EPSILON:
		var step := minf(remaining, 1.0 / 60.0)
		advance(step)
		if survival_drain_enabled:
			mission_seconds += step
			advance_station_systems(step)
		remaining -= step

func _reset_inventories() -> void:
	containers = INITIAL_CONTAINERS.duplicate(true)
	player_inventory = INITIAL_PLAYER_INVENTORY.duplicate(true)
	storage_status = "Click an item to transfer between your Suit Pack and the Storage Compartment, or use it directly."

func reset_demo() -> void:
	hydrogen_kg = 0.8
	oxygen_kg = 6.4
	water_kg = 2.0
	energy_units = 20.0
	water_produced_kg = 0.0
	energy_produced_units = 0.0
	energy_consumed_units = 0.0
	running = false
	output_fraction = 1.0
	protect_oxygen_reserve = true
	status = "Ready — start the fuel cell to transfer resources."
	food_stock = INITIAL_FOOD_STOCK.duplicate()
	for item_id in prepared_food:
		prepared_food[item_id] = 0
	food_water_used_kg = 0.0
	food_status = FOOD_READY_MESSAGE
	tracking_observations_submitted = 0
	tracking_status = "No observation packets transmitted."
	tracking_log.clear()
	hunger = 82.0
	hydration = 78.0
	oxygen_purity = 98.0
	scrubber_active = true
	electrolyzer_active = false
	command_screen_active = false
	_low_power_warned = false
	story_phase = 0
	asteroid_distance_km = 12400.0
	asteroid_redirected_to_moon = false
	berna_relationship = "Connected"
	told_berna_truth = false
	ending_reached = ""
	comm_history.clear()
	ever_ate_or_drank = false
	ever_opened_storage = false
	power_objective_complete = false
	supplies_objective_complete = false
	pending_dialogue = "arrival_intro"
	decision_made = false
	mission_failed = false
	mission_seconds = 0.0
	oxygen_consumed_kg = 0.0
	emergency_items_used = 0
	assisted_locks = 0
	_air_warned = false
	_needs_warned = false
	greenhouse_active = false
	crop_planted = false
	crop_growth_percent = 0.0
	seed_kits = 2
	fresh_produce_portions = 0
	condensate_kg = 0.0
	greenhouse_biomass_water_kg = 0.0
	greenhouse_water_used_kg = 0.0
	greenhouse_water_recovered_kg = 0.0
	greenhouse_energy_used = 0.0
	crops_harvested = 0
	greenhouse_status = "Plant a seed and nutrient kit, then switch on the grow lights and misting."
	_reset_inventories()
	changed.emit()

func get_objectives() -> Array[Dictionary]:
	power_objective_complete = power_objective_complete or (water_produced_kg >= 0.50 - EPSILON and energy_units >= 22.0)
	supplies_objective_complete = supplies_objective_complete or (ever_ate_or_drank and ever_opened_storage)
	return [
		{
			"title": "1. Generate Water & Power at Fuel Cell",
			"detail": "Start the H₂/O₂ Fuel Cell (north wall or Power tab) to generate >= 0.50 kg water and charge the station battery (>= 22 EU).",
			"done": power_objective_complete
		},
		{
			"title": "2. Inspect Stowage & Hydrate / Eat Rations",
			"detail": "Open a Storage Compartment or Food Supplies Cabinet (west wall), prepare/take a ration or water pouch, and Eat [H] or Drink [J].",
			"done": supplies_objective_complete
		},
		{
			"title": "3. Transmit Deep-Space Radar Lock 04 (12,400 km)",
			"detail": "Open the Command Console -> Science tab, calibrate or load Dish Lock 04 (04:18:32, AZ 128.4°, EL 22.7°, HIGH), and transmit.",
			"done": tracking_observations_submitted >= 1
		},
		{
			"title": "4. Track Approaching Asteroid: Locks 05 & 06",
			"detail": "Align the Deep-Space Array to transmit Observation 05 (6,850 km) and Observation 06 (1,920 km) to reveal Object-2010-XK's trajectory.",
			"done": tracking_observations_submitted >= 3
		},
		{
			"title": "5. Final Decision: Return Rocket & Berna Comms",
			"detail": "With >= 20 EU battery charge, choose whether to launch your return rocket into the asteroid and whether to tell Berna the truth.",
			"done": not ending_reached.is_empty()
		}
	]

func set_command_screen_active(active: bool) -> void:
	if active and not command_screen_active:
		spend_energy(COMMAND_SCREEN_OPEN_COST, "Command screen wake & telemetry sync")
	command_screen_active = active
	changed.emit()

func spend_energy(amount: float, reason: String = "") -> bool:
	if amount <= 0.0:
		return true
	if energy_units + EPSILON < amount:
		if not reason.is_empty():
			status = "Not enough battery energy for %s." % reason
		changed.emit()
		return false
	energy_units = maxf(0.0, energy_units - amount)
	energy_consumed_units += amount
	if energy_units < 10.0 and not _low_power_warned and survival_drain_enabled:
		_low_power_warned = true
		story_triggered.emit("low_power_warning")
	elif energy_units >= 15.0:
		_low_power_warned = false
	changed.emit()
	return true

func total_power_load_per_sec() -> float:
	var load := 0.0
	if command_screen_active:
		load += COMMAND_SCREEN_DRAIN_PER_SEC
	if scrubber_active:
		load += SCRUBBER_ENERGY_PER_SEC
	if electrolyzer_active:
		load += ELECTROLYZER_ENERGY_PER_SEC
	if greenhouse_active:
		load += GROW_POWER_PER_SEC
	return load

func set_scrubber_active(enabled: bool) -> void:
	scrubber_active = enabled and energy_units > EPSILON
	changed.emit()

func set_electrolyzer_active(enabled: bool) -> void:
	if enabled and (energy_units <= 1.0 or water_kg <= 0.1):
		status = "Electrolyzer blocked — requires stored water and electrical power."
		electrolyzer_active = false
		changed.emit()
		return
	electrolyzer_active = enabled
	changed.emit()

func advance_station_systems(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var changed_any := false

	# 1. Command screen active electrical drain
	if command_screen_active and energy_units > 0.0:
		var used := minf(energy_units, COMMAND_SCREEN_DRAIN_PER_SEC * delta)
		energy_units -= used
		energy_consumed_units += used
		changed_any = true

	# Air quality is a gameplay index, NOT an oxygen concentration.
	# Breathing consumes oxygen even when the CO2 scrubber is switched off.
	var breathed := minf(oxygen_kg, 0.0004 * delta)
	oxygen_kg -= breathed
	oxygen_consumed_kg += breathed
	# 2. Powered CO2 removal, bounded by available electrical energy.
	if scrubber_active:
		var needed := SCRUBBER_ENERGY_PER_SEC * delta
		var used := minf(energy_units, needed) if oxygen_kg > EPSILON else 0.0
		var operating_time := used / SCRUBBER_ENERGY_PER_SEC
		energy_units -= used
		energy_consumed_units += used
		oxygen_purity = clampf(oxygen_purity + OXYGEN_PURITY_RECOVERY_WITH_SCRUBBER * operating_time - OXYGEN_PURITY_DECAY_NO_SCRUBBER * (delta - operating_time), 0.0, 100.0)
		if operating_time + EPSILON < delta:
			scrubber_active = false
		changed_any = true
	else:
		oxygen_purity = maxf(0.0, oxygen_purity - OXYGEN_PURITY_DECAY_NO_SCRUBBER * delta)
		changed_any = true

	# 3. Water Electrolyzer (splits H2O -> H2 + O2 using electrical power)
	if electrolyzer_active:
		var operating_time := minf(delta, energy_units / ELECTROLYZER_ENERGY_PER_SEC)
		operating_time = minf(operating_time, water_kg / ELECTROLYZER_WATER_PER_SEC)
		operating_time = minf(operating_time, maxf(0.0, HYDROGEN_CAPACITY - hydrogen_kg) / 0.004)
		operating_time = minf(operating_time, maxf(0.0, OXYGEN_CAPACITY - oxygen_kg) / 0.032)
		var used := operating_time * ELECTROLYZER_ENERGY_PER_SEC
		energy_units = maxf(0.0, energy_units - used)
		energy_consumed_units += used
		water_kg = maxf(0.0, water_kg - operating_time * ELECTROLYZER_WATER_PER_SEC)
		hydrogen_kg += operating_time * 0.004
		oxygen_kg += operating_time * 0.032
		if operating_time + EPSILON < delta:
			electrolyzer_active = false
			status = "Electrolysis stopped: water, energy or gas storage limit reached."
		changed_any = true

	advance_greenhouse(delta, false)

	# 4. Crew Metabolism: Hunger & Hydration gradual drain
	hunger = maxf(0.0, hunger - HUNGER_DRAIN_PER_SEC * delta)
	hydration = maxf(0.0, hydration - HYDRATION_DRAIN_PER_SEC * delta)
	changed_any = true

	if energy_units < 10.0 and not _low_power_warned:
		_low_power_warned = true
		story_triggered.emit("low_power_warning")
		feedback.emit("warning")
	elif energy_units >= 15.0:
		_low_power_warned = false
	if oxygen_purity < 35.0 and not _air_warned:
		_air_warned = true
		story_triggered.emit("air_warning")
		feedback.emit("warning")
	elif oxygen_purity > 55.0:
		_air_warned = false
	if minf(hunger, hydration) < 25.0 and not _needs_warned:
		_needs_warned = true
		story_triggered.emit("supplies_warning")
		feedback.emit("warning")
	elif minf(hunger, hydration) > 40.0:
		_needs_warned = false
	if minf(hunger, minf(hydration, oxygen_purity)) <= EPSILON and not mission_failed:
		mission_failed = true
		running = false
		pending_dialogue = "mission_failure"
		story_triggered.emit("mission_failure")

	if changed_any:
		changed.emit()

func plant_crop() -> bool:
	if crop_planted or seed_kits <= 0:
		greenhouse_status = "Harvest the current crop first." if crop_planted else "No seed kits left. Inspect Supply Crate Alpha."
		changed.emit()
		return false
	seed_kits -= 1
	crop_planted = true
	crop_growth_percent = 0.0
	greenhouse_status = "Microgreens planted. Switch on lights and misting to grow."
	feedback.emit("prepare")
	changed.emit()
	return true

func greenhouse_blocking_reason() -> String:
	if not crop_planted:
		return "Plant a seed and nutrient kit first."
	if crop_growth_percent >= 100.0 - EPSILON:
		return "Crop ready. Harvest before planting again."
	if energy_units <= EPSILON:
		return "No electrical power. Charge the battery."
	if water_kg <= EPSILON:
		return "No tank water. Recover condensate or start the fuel cell."
	if condensate_kg >= CONDENSATE_CAPACITY - EPSILON:
		return "Condensate collector full. Recover water to continue."
	return ""

func set_greenhouse_active(enabled: bool) -> void:
	var reason := greenhouse_blocking_reason()
	greenhouse_active = enabled and reason.is_empty()
	greenhouse_status = "Growing microgreens. Keep water and power available." if greenhouse_active else (reason if enabled else "Grow lights and misting stopped. Crop progress is retained.")
	changed.emit()

func advance_greenhouse(delta: float, notify: bool = true) -> void:
	if not greenhouse_active or not is_finite(delta) or delta <= 0.0:
		return
	var operating_time := minf(delta, maxf(0.0, 100.0 - crop_growth_percent) * GROW_SECONDS / 100.0)
	operating_time = minf(operating_time, energy_units / GROW_POWER_PER_SEC)
	operating_time = minf(operating_time, water_kg / GROW_WATER_PER_SEC)
	operating_time = minf(operating_time, maxf(0.0, CONDENSATE_CAPACITY - condensate_kg) / (GROW_WATER_PER_SEC * GROW_RECOVERY_FRACTION))
	var water := operating_time * GROW_WATER_PER_SEC
	var energy := operating_time * GROW_POWER_PER_SEC
	water_kg = maxf(0.0, water_kg - water)
	energy_units = maxf(0.0, energy_units - energy)
	energy_consumed_units += energy
	greenhouse_energy_used += energy
	greenhouse_water_used_kg += water
	condensate_kg += water * GROW_RECOVERY_FRACTION
	# This ledger retains water held in crops, harvested produce and eaten produce.
	greenhouse_biomass_water_kg += water * (1.0 - GROW_RECOVERY_FRACTION)
	crop_growth_percent = minf(100.0, crop_growth_percent + operating_time * 100.0 / GROW_SECONDS)
	# A small teaching-model contribution, not an oxygen concentration or gas source.
	oxygen_purity = minf(100.0, oxygen_purity + operating_time * 0.01)
	var reason := greenhouse_blocking_reason()
	if not reason.is_empty():
		greenhouse_active = false
		greenhouse_status = reason
	if notify:
		changed.emit()

func recover_greenhouse_water() -> bool:
	var amount := minf(condensate_kg, maxf(0.0, WATER_CAPACITY - water_kg))
	amount = minf(amount, energy_units / RECOVERY_ENERGY_PER_KG)
	if amount <= EPSILON:
		greenhouse_status = "Recovery needs condensate, battery power and space in the water tank."
		changed.emit()
		return false
	var energy := amount * RECOVERY_ENERGY_PER_KG
	condensate_kg = maxf(0.0, condensate_kg - amount)
	water_kg += amount
	energy_units = maxf(0.0, energy_units - energy)
	energy_consumed_units += energy
	greenhouse_energy_used += energy
	greenhouse_water_recovered_kg += amount
	greenhouse_status = "Recovered %.3f kg water using %.3f EU. Treatment and pumping are simplified." % [amount, energy]
	feedback.emit("transfer")
	changed.emit()
	return true

func harvest_crop() -> bool:
	if not crop_planted or crop_growth_percent < 100.0 - EPSILON:
		greenhouse_status = "The crop needs to reach 100% before harvesting."
		changed.emit()
		return false
	crop_planted = false
	greenhouse_active = false
	crop_growth_percent = 0.0
	fresh_produce_portions += HARVEST_PORTIONS
	crops_harvested += 1
	greenhouse_status = "Harvested 2 microgreens portions. Eat a portion or plant another seed kit."
	feedback.emit("prepare")
	changed.emit()
	return true

func eat_fresh_produce() -> bool:
	if fresh_produce_portions <= 0:
		greenhouse_status = "No fresh produce available. Grow and harvest a crop first."
		changed.emit()
		return false
	fresh_produce_portions -= 1
	hunger = minf(100.0, hunger + 35.0)
	hydration = minf(100.0, hydration + 25.0)
	ever_ate_or_drank = true
	greenhouse_status = "Fresh microgreens eaten (+35 hunger, +25 hydration). Fresh flavours lift the crew's spirits."
	feedback.emit("consume")
	changed.emit()
	return true

func food_blocking_reason(item_id: String) -> String:
	if not FOOD_RECIPES.has(item_id):
		return "Unknown food supply."
	if food_stock[item_id] <= 0:
		return "Out of stock — no sealed packages left."
	var water_cost: float = FOOD_RECIPES[item_id].water_kg
	if water_kg + EPSILON < water_cost:
		return "Not enough water — need %.2f kg, have %.2f kg." % [water_cost, water_kg]
	return ""

func prepare_food(item_id: String) -> bool:
	# Validate and transfer together so rapid clicks cannot spend missing supplies.
	var reason := food_blocking_reason(item_id)
	if not reason.is_empty():
		food_status = reason
		changed.emit()
		return false
	var recipe: Dictionary = FOOD_RECIPES[item_id]
	var water_cost: float = recipe.water_kg
	food_stock[item_id] -= 1
	water_kg = maxf(0.0, water_kg - water_cost)
	prepared_food[item_id] += 1
	food_water_used_kg += water_cost
	food_status = "Prepared: %s. Used 1 package and %.2f kg water." % [recipe.name, water_cost]
	feedback.emit("prepare")
	# Preparing food frees tank capacity, but never restarts a stopped fuel cell.
	if not running:
		status = blocking_reason()
		if status.is_empty():
			status = "Ready — start the fuel cell to transfer resources."
	changed.emit()
	return true

func consume_prepared_food(item_id: String) -> bool:
	if not FOOD_RECIPES.has(item_id):
		return false
	if prepared_food.get(item_id, 0) <= 0:
		food_status = "No prepared portion of %s ready to consume." % FOOD_RECIPES[item_id].name
		changed.emit()
		return false
	var recipe: Dictionary = FOOD_RECIPES[item_id]
	prepared_food[item_id] -= 1
	var h_gain: float = recipe.get("hunger_restore", 25.0)
	var w_gain: float = recipe.get("hydration_restore", 10.0)
	hunger = clampf(hunger + h_gain, 0.0, 100.0)
	hydration = clampf(hydration + w_gain, 0.0, 100.0)
	ever_ate_or_drank = true
	feedback.emit("consume")
	food_status = "Consumed %s (+%.0f%% Hunger, +%.0f%% Hydration)." % [recipe.name, h_gain, w_gain]
	changed.emit()
	return true

func drink_direct_water() -> bool:
	var drink_kg := 0.25
	if water_kg + EPSILON < drink_kg:
		food_status = "Not enough potable water in storage tank to drink (need 0.25 kg)."
		changed.emit()
		return false
	water_kg = maxf(0.0, water_kg - drink_kg)
	food_water_used_kg += drink_kg
	hydration = clampf(hydration + 32.0, 0.0, 100.0)
	ever_ate_or_drank = true
	feedback.emit("consume")
	food_status = "Drank 0.25 kg potable water (+32% Hydration)."
	changed.emit()
	return true

## Storage & Inventory Transfer / Consumption Operations
func transfer_container_to_player(container_id: String, slot_index: int) -> bool:
	ever_opened_storage = true
	if not containers.has(container_id):
		return false
	var slots: Array = containers[container_id].slots
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Dictionary = slots[slot_index]
	if slot.id.is_empty() or slot.count <= 0:
		return false
	if not _add_to_slots(player_inventory, slot.id, 1):
		storage_status = "Suit Pack is full!"
		changed.emit()
		return false
	var item_name: String = ITEM_CATALOG.get(slot.id, {}).get("name", slot.id)
	slot.count -= 1
	if slot.count <= 0:
		slot.id = ""
		slot.count = 0
	storage_status = "Moved 1× %s to your Suit Pack." % item_name
	feedback.emit("transfer")
	changed.emit()
	return true

func transfer_player_to_container(container_id: String, slot_index: int) -> bool:
	if not containers.has(container_id):
		return false
	if slot_index < 0 or slot_index >= player_inventory.size():
		return false
	var slot: Dictionary = player_inventory[slot_index]
	if slot.id.is_empty() or slot.count <= 0:
		return false
	var c_slots: Array = containers[container_id].slots
	if not _add_to_slots(c_slots, slot.id, 1):
		storage_status = "%s has no free slots!" % containers[container_id].title
		changed.emit()
		return false
	var item_name: String = ITEM_CATALOG.get(slot.id, {}).get("name", slot.id)
	slot.count -= 1
	if slot.count <= 0:
		slot.id = ""
		slot.count = 0
	storage_status = "Stored 1× %s in %s." % [item_name, containers[container_id].title]
	feedback.emit("transfer")
	changed.emit()
	return true

func use_inventory_item(slot_index: int, from_container_id: String = "") -> bool:
	var slots: Array = player_inventory if from_container_id.is_empty() else containers.get(from_container_id, {}).get("slots", [])
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var slot: Dictionary = slots[slot_index]
	if slot.id.is_empty() or slot.count <= 0:
		return false
	var item_id: String = slot.id
	var info: Dictionary = ITEM_CATALOG.get(item_id, {})
	var category: String = info.get("category", "")
	match category:
		"growing":
			seed_kits += 1
			slot.count -= 1
			if slot.count <= 0:
				slot.id = ""
			storage_status = "Moved a seed and nutrient kit into greenhouse supplies."
		"condiment":
			slot.count -= 1
			if slot.count <= 0:
				slot.id = ""
			storage_status = "A taste of home. Hot sauce adds flavour, not food, water or oxygen."
		"food", "drink":
			var h_gain: float = info.get("hunger", 0.0)
			var w_gain: float = info.get("hydration", 0.0)
			hunger = clampf(hunger + h_gain, 0.0, 100.0)
			hydration = clampf(hydration + w_gain, 0.0, 100.0)
			ever_ate_or_drank = true
			slot.count -= 1
			if slot.count <= 0:
				slot.id = ""
			storage_status = "Consumed %s (%s%d%% Hunger, %s%d%% Hydration)." % [
				info.get("name", item_id),
				"+" if h_gain >= 0 else "", int(h_gain),
				"+" if w_gain >= 0 else "", int(w_gain)
			]
		"food_pkg":
			var recipe_id: String = info.get("recipe_id", "dehydrated_meal")
			food_stock[recipe_id] = food_stock.get(recipe_id, 0) + 1
			slot.count -= 1
			if slot.count <= 0:
				slot.id = ""
			storage_status = "Added %s to Food Supplies Cabinet stock." % info.get("name", item_id)
		"utility":
			if (info.has("energy") and energy_units >= ENERGY_CAPACITY - EPSILON) or (info.has("oxygen_kg") and oxygen_kg >= OXYGEN_CAPACITY - EPSILON):
				storage_status = "Storage is full. Save this emergency supply for later."
				changed.emit()
				return false
			emergency_items_used += 1
			if info.has("energy"):
				var e_gain: float = info.get("energy", 15.0)
				e_gain = minf(e_gain, ENERGY_CAPACITY - energy_units)
				energy_units = minf(ENERGY_CAPACITY, energy_units + e_gain)
				storage_status = "Discharged %s (+%.1f EU to station battery)." % [info.get("name", item_id), e_gain]
			elif info.has("oxygen_kg"):
				var o_gain: float = info.get("oxygen_kg", 0.6)
				o_gain = minf(o_gain, OXYGEN_CAPACITY - oxygen_kg)
				oxygen_kg = minf(OXYGEN_CAPACITY, oxygen_kg + o_gain)
				storage_status = "Used %s (+%.2f kg O₂). Switch on the CO₂ scrubber to recover air quality." % [info.get("name", item_id), o_gain]
			slot.count -= 1
			if slot.count <= 0:
				slot.id = ""
		"keepsake":
			storage_status = info.get("description", "Personal item.")
			changed.emit()
			return true
		_:
			return false
	changed.emit()
	feedback.emit("consume")
	return true

func _add_to_slots(slots: Array, item_id: String, amount: int) -> bool:
	for s in slots:
		if s.id == item_id:
			s.count += amount
			return true
	for s in slots:
		if s.id.is_empty() or s.count <= 0:
			s.id = item_id
			s.count = amount
			return true
	return false

func set_running(enabled: bool) -> void:
	var reason := blocking_reason()
	running = enabled and reason.is_empty()
	status = "Running — transferring water and electrical energy." if running else "Stopped by operator."
	if enabled and not reason.is_empty():
		status = reason
	changed.emit()

func set_output_fraction(value: float) -> void:
	if not is_finite(value):
		return
	output_fraction = clampf(value, 0.25, 1.0)
	changed.emit()

func set_reserve_protection(enabled: bool) -> void:
	protect_oxygen_reserve = enabled
	if running and not blocking_reason().is_empty():
		running = false
		status = blocking_reason()
	elif not running:
		status = blocking_reason()
		if status.is_empty():
			status = "Ready — start the fuel cell to transfer resources."
	changed.emit()

func blocking_reason() -> String:
	if hydrogen_kg <= EPSILON:
		return "Stopped — hydrogen tank empty."
	if oxygen_kg <= oxygen_floor() + EPSILON:
		return "Stopped — protected oxygen reserve reached." if protect_oxygen_reserve else "Stopped — oxygen tank empty."
	if water_kg >= WATER_CAPACITY - EPSILON:
		return "Stopped — water tank full. No water is discarded."
	if energy_units >= ENERGY_CAPACITY - EPSILON:
		return "Stopped — battery full. No energy is discarded."
	return ""

func oxygen_floor() -> float:
	return OXYGEN_RESERVE if protect_oxygen_reserve else 0.0

func available_hydrogen_equivalent() -> float:
	# All inputs and output capacities limit the SAME reaction extent.
	var amount := minf(hydrogen_kg, maxf(0.0, oxygen_kg - oxygen_floor()) / 8.0)
	amount = minf(amount, maxf(0.0, WATER_CAPACITY - water_kg) / 9.0)
	amount = minf(amount, maxf(0.0, ENERGY_CAPACITY - energy_units) / ENERGY_PER_KG_HYDROGEN)
	return maxf(amount, 0.0)

func preview(seconds: float = 10.0) -> Dictionary:
	var amount := minf(HYDROGEN_RATE * output_fraction * maxf(seconds, 0.0), available_hydrogen_equivalent())
	return {
		"hydrogen": amount,
		"oxygen": amount * 8.0,
		"water": amount * 9.0,
		"energy": amount * ENERGY_PER_KG_HYDROGEN,
	}

func advance(delta: float) -> void:
	if not running or not is_finite(delta) or delta <= 0.0:
		return
	var transfer := preview(delta)
	hydrogen_kg = maxf(0.0, hydrogen_kg - transfer.hydrogen)
	oxygen_kg = maxf(0.0, oxygen_kg - transfer.oxygen)
	water_kg = minf(WATER_CAPACITY, water_kg + transfer.water)
	energy_units = minf(ENERGY_CAPACITY, energy_units + transfer.energy)
	water_produced_kg += transfer.water
	energy_produced_units += transfer.energy
	var reason := blocking_reason()
	if not reason.is_empty():
		running = false
		status = reason
	changed.emit()

func record_tracking_observation(record: Dictionary) -> void:
	# Using the information gathering command screen to submit observations depletes electricity
	if mission_failed or decision_made or tracking_log.size() >= 3:
		return
	var objectives := get_objectives()
	if not objectives[0].done or not objectives[1].done:
		tracking_status = "Stabilize the habitat first: generate water and power, inspect supplies, and eat or drink."
		changed.emit()
		return
	if record.get("id", "") != "Observation %02d" % (tracking_log.size() + 4):
		return
	if not spend_energy(OBSERVATION_SCAN_ENERGY_COST, "Deep-space radar array transmission"):
		return
	tracking_log.append(record.duplicate(true))
	tracking_observations_submitted = tracking_log.size()
	asteroid_distance_km = float(record.get("range_km", asteroid_distance_km))
	tracking_status = "%s accepted and transmitted to Earth (−%.1f EU)." % [record.get("id", "Observation"), OBSERVATION_SCAN_ENERGY_COST]
	story_phase = maxi(story_phase, tracking_observations_submitted)
	changed.emit()
	feedback.emit("transmit")
	if tracking_observations_submitted == 1:
		pending_dialogue = "obs_1_reveal"
		story_triggered.emit("obs_1_reveal")
	elif tracking_observations_submitted == 2:
		pending_dialogue = "obs_2_truth"
		story_triggered.emit("obs_2_truth")
	elif tracking_observations_submitted >= 3:
		pending_dialogue = "obs_3_climax"
		story_triggered.emit("obs_3_climax")

func apply_story_effect(effect: String) -> bool:
	if not ending_reached.is_empty() or mission_failed:
		return false
	match effect:
		"berna_reassured":
			berna_relationship = "Reassured & Warm"
		"berna_distant":
			berna_relationship = "Worried & Distant"
		"launch_intercept":
			if decision_made or tracking_observations_submitted < 3:
				return false
			if not spend_energy(RETURN_ROCKET_ENERGY_COST, "Return Rocket Kinetic Intercept Launch"):
				return false
			decision_made = true
			asteroid_redirected_to_moon = true
			feedback.emit("launch")
			tracking_status = "ALERT: Return ship launched! Object-2010-XK deflected from Earth — now on lunar impact vector."
		"keep_ship":
			if decision_made or tracking_observations_submitted < 3:
				return false
			decision_made = true
			asteroid_redirected_to_moon = false
			tracking_status = "CRITICAL: Return ship held at pad. Object-2010-XK continuing on Earth impact trajectory."
		"told_truth":
			if not decision_made:
				return false
			told_berna_truth = true
			ending_reached = "Sacrificed for Earth (Told Berna Truth)" if asteroid_redirected_to_moon else "Preserved Return Ship (Told Berna Truth)"
		"hid_truth":
			if not decision_made:
				return false
			told_berna_truth = false
			ending_reached = "Sacrificed for Earth (Protected Berna from Truth)" if asteroid_redirected_to_moon else "Preserved Return Ship (Hid Truth from Berna)"
		"feed_pearl":
			# A companion comforts the crew; petting cannot produce oxygen.
			feedback.emit("companion")
	changed.emit()
	return true

func log_comm_entry(speaker: String, text: String) -> void:
	comm_history.append({"speaker": speaker, "text": text})
