extends VBoxContainer

var _api: Node
var _provenance: Label
var _status: Label
var _selector: OptionButton
var _details: Label
var _refresh_button: Button
var _records_signature := ""

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_label("NASA NeoWs / historical close approaches", 21)
	_label("November 14–15, 2010. Browse real catalogue records alongside the fictional mission. Fetching today does not make these live observations.", 16)
	_provenance = _label("", 14)
	_status = _label("", 15)
	_refresh_button = Button.new()
	_refresh_button.text = "Refresh historical catalogue from NASA"
	_refresh_button.custom_minimum_size.y = 40
	_refresh_button.pressed.connect(func(): _api.refresh_catalogue())
	add_child(_refresh_button)
	_selector = OptionButton.new()
	_selector.custom_minimum_size.y = 40
	_selector.fit_to_longest_item = false
	_selector.item_selected.connect(func(_index: int): _show_selection())
	add_child(_selector)
	_details = _label("", 17)
	_label("READING THE DATA\n“Potentially hazardous” is a classification based on orbit and size; it is not an impact prediction. Miss distance describes an Earth close approach. Lunar distances are distance units, not a lunar collision forecast. Estimated diameters are a range.\nObject-2010-XK and its 99.8% impact probability belong only to the fictional story. Catalogue browsing costs no station energy and cannot advance or change the mission.", 15)
	_label("Source: https://api.nasa.gov/neo/rest/v1/feed\nThe browser edition uses the bundled historical snapshot; Linux players may optionally refresh with a locally configured NASA key." if OS.has_feature("web") else "Source: https://api.nasa.gov/neo/rest/v1/feed\nOnline refresh uses a locally configured NASA_API_KEY or user://nasa.cfg. No key is bundled in the game. Data loads from a verified snapshot when offline.", 14)

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	add_child(label)
	return label

func bind_client(api: Node) -> void:
	_api = api
	_api.updated.connect(_refresh)
	_refresh()

func _refresh() -> void:
	_provenance.text = "%s · Retrieved: %s · %d record(s)" % [_api.source_mode, _api.retrieved_at if not _api.retrieved_at.is_empty() else "unavailable", _api.records.size()]
	_status.text = _api.status
	_refresh_button.visible = not OS.has_feature("web")
	_refresh_button.disabled = _api.busy
	var signature := str(_api.records)
	if signature != _records_signature:
		_records_signature = signature
		var selected_key := ""
		if _selector.selected >= 0:
			selected_key = str(_selector.get_item_metadata(_selector.selected))
		_selector.clear()
		var selection := 0
		for record in _api.records:
			_selector.add_item("%s · %s" % [record.name, record.date])
			var index := _selector.item_count - 1
			var key: String = record.id + ":" + record.date
			_selector.set_item_metadata(index, key)
			if key == selected_key:
				selection = index
		if _selector.item_count > 0:
			_selector.select(selection)
		_selector.disabled = _selector.item_count == 0
	_show_selection()

func _show_selection() -> void:
	if _selector.selected < 0 or _selector.selected >= _api.records.size():
		_details.text = "No close-approach records available."
		return
	var record: Dictionary = _api.records[_selector.selected]
	_details.text = "%s  /  NASA ID %s\nEarth close approach: %s\nPotentially hazardous classification: %s\nAbsolute magnitude H: %.2f\nEstimated diameter: %.1f–%.1f m\nRelative approach speed: %.3f km/s\nMiss distance: %.0f km  /  %.3f lunar distances" % [
		record.name, record.id, record.date, "Yes" if record.hazardous else "No",
		record.absolute_magnitude_h, record.diameter_min_m, record.diameter_max_m,
		record.velocity_km_s, record.miss_distance_km, record.miss_distance_lunar]
