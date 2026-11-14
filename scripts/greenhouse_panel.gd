extends VBoxContainer

const State = preload("res://scripts/life_support_state.gd")
var _state: State
var _summary: Label
var _progress: ProgressBar
var _status: Label
var _plant: Button
var _toggle: Button
var _harvest: Button
var _eat: Button
var _recover: Button

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_label("LUNAR GREENHOUSE / MICROGREENS", 20)
	_label("Controlled-environment growing, inspired by CSA food-production education. A 180-second crop is an accelerated game rule; real crops take days or weeks.", 15)
	_summary = _label("", 16)
	_progress = ProgressBar.new()
	_progress.max_value = 100.0
	_progress.custom_minimum_size.y = 24
	add_child(_progress)
	_status = _label("", 16)
	_status.add_theme_color_override("font_color", Color("#d8b56c"))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	actions.add_theme_constant_override("v_separation", 8)
	add_child(actions)
	_plant = _button(actions, "Plant 1 seed + nutrient kit", func(): _state.plant_crop())
	_toggle = _button(actions, "Start lights & misting", func(): _state.set_greenhouse_active(not _state.greenhouse_active))
	_harvest = _button(actions, "Harvest 2 portions", func(): _state.harvest_crop())
	_eat = _button(actions, "Eat fresh produce", func(): _state.eat_fresh_produce())
	_recover = _button(actions, "Recover condensate", func(): _state.recover_greenhouse_water())
	_label("COSTS AT FULL GROWTH\n0.08 EU/s + 0.004 kg water/s. A full crop costs 14.4 EU and routes 0.720 kg water through the rack.\n90% enters the condensate collector; 10% stays accounted for in crop/food water. Recovering condensate costs 0.20 EU/kg and requires free tank space.", 15)
	_label("Harvesting produces 2 portions. Each restores +35 hunger / +25 hydration (game values). Pausing preserves crop progress. Seed and nutrient kits are finite; extra kits are in Supply Crate Alpha.", 15)
	_label("SCIENCE NOTE\nPlants use light, water, nutrients and CO₂ to build biomass and release oxygen. This small rack contributes only +0.01/s to the abstract air-quality index, far below unfiltered cabin decline. It cannot replace the CO₂ scrubber or refill gas tanks. Eating vegetables does not add cabin oxygen.\nThe 90% recovery fraction is a gameplay assumption, not a CSA hardware specification.", 15)
	var source := RichTextLabel.new()
	source.bbcode_enabled = true
	source.fit_content = true
	source.scroll_active = false
	source.text = "[url=https://www.asc-csa.gc.ca/eng/youth-educators/toolkits/food-production/]CSA: Food production on the Moon and in remote areas (opens browser)[/url]"
	source.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
	add_child(source)

func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label

func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func bind_state(state: State) -> void:
	if is_instance_valid(_state) and _state.changed.is_connected(_refresh):
		_state.changed.disconnect(_refresh)
	_state = state
	_state.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_summary.text = "Seed kits: %d  ·  Fresh portions: %d  ·  Crops harvested: %d\nCrop: %.1f%%  ·  Condensate: %.3f / %.1f kg\nWater returned: %.3f kg  ·  Water retained in crops/food: %.3f kg\nTank water: %.3f kg  ·  Battery: %.2f EU  ·  Growing/recovery energy used: %.2f EU" % [
		_state.seed_kits, _state.fresh_produce_portions, _state.crops_harvested,
		_state.crop_growth_percent, _state.condensate_kg, State.CONDENSATE_CAPACITY,
		_state.greenhouse_water_recovered_kg, _state.greenhouse_biomass_water_kg,
		_state.water_kg, _state.energy_units, _state.greenhouse_energy_used]
	_progress.value = _state.crop_growth_percent
	_status.text = _state.greenhouse_status
	_plant.disabled = _state.crop_planted or _state.seed_kits <= 0
	_toggle.text = "Stop lights & misting" if _state.greenhouse_active else "Start lights & misting"
	_toggle.disabled = not _state.greenhouse_active and not _state.greenhouse_blocking_reason().is_empty()
	_toggle.tooltip_text = _state.greenhouse_blocking_reason()
	_harvest.disabled = not _state.crop_planted or _state.crop_growth_percent < 100.0 - State.EPSILON
	_eat.disabled = _state.fresh_produce_portions <= 0
	_recover.disabled = _state.condensate_kg <= State.EPSILON or _state.water_kg >= State.WATER_CAPACITY - State.EPSILON or _state.energy_units <= State.EPSILON
