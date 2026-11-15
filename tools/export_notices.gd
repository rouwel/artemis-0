extends SceneTree

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Pass the package output directory after --.")
		quit(1)
		return
	var output := FileAccess.open(arguments[0].path_join("Godot-Licenses.txt"), FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string("GODOT ENGINE\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY COMPONENTS\n")
	for component in Engine.get_copyright_info():
		output.store_string("\n%s\n" % component.name)
		for part in component.parts:
			output.store_string("Files: %s\nCopyright: %s\nLicense: %s\n" % [", ".join(part.files), "\n".join(part.copyright), part.license])
	for name in Engine.get_license_info():
		output.store_string("\n%s\n%s\n" % [name, Engine.get_license_info()[name]])
	output.close()
	quit()
