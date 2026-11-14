extends SceneTree

const ASSET_DIR := "res://assets"
const OUT_PATH := "res://scenes/asset_gallery.tscn"

func _initialize() -> void:
    var root := Node3D.new()
    root.name = "AssetGallery"
    _add_environment(root)
    _add_reference_pillar(root)

    var files: Array[String] = []
    for f: String in DirAccess.get_files_at(ASSET_DIR):
        if f.ends_with(".glb"):
            files.append(f)
    files.sort()

    var x := 0.0
    for f: String in files:
        var scene := load(ASSET_DIR + "/" + f) as PackedScene
        if scene == null:
            push_error("Could not load " + f)
            continue
        var holder := Node3D.new()
        holder.name = f.get_basename()
        holder.position = Vector3(x, 1.0, 0)
        root.add_child(holder)
        holder.owner = root

        var inst := scene.instantiate()
        holder.add_child(inst)
        inst.owner = root

        _arrow(holder, root, Vector3.RIGHT, Color.RED, "X")
        _arrow(holder, root, Vector3.UP, Color.GREEN, "Y")
        _arrow(holder, root, Vector3.BACK, Color.BLUE, "Z")

        var title := Label3D.new()
        title.name = "FileName"
        title.text = f
        title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        title.no_depth_test = true
        title.font_size = 48
        title.pixel_size = 0.006
        title.position = Vector3(0, 1.8, 0)
        holder.add_child(title)
        title.owner = root

        print("== ", f)
        _walk(inst, 1)
        x += 3.0

    var packed := PackedScene.new()
    var err := packed.pack(root)
    if err != OK:
        push_error("pack failed: " + str(err))
        quit(1)
        return
    err = ResourceSaver.save(packed, OUT_PATH)
    if err != OK:
        push_error("save failed: " + str(err))
        quit(1)
        return
    print("Saved ", OUT_PATH, " with ", files.size(), " assets")
    quit()

func _add_environment(root: Node3D) -> void:
    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-50, 30, 0)
    sun.shadow_enabled = false
    root.add_child(sun)
    sun.owner = root
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#2B2B33")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    env.ambient_light_energy = 0.6
    var we := WorldEnvironment.new()
    we.name = "WorldEnvironment"
    we.environment = env
    root.add_child(we)
    we.owner = root

func _add_reference_pillar(root: Node3D) -> void:
    var m := MeshInstance3D.new()
    m.name = "Reference_1_8m"
    var c := CylinderMesh.new()
    c.top_radius = 0.15
    c.bottom_radius = 0.15
    c.height = 1.8
    m.mesh = c
    m.position = Vector3(-3, 0.9, 0)
    root.add_child(m)
    m.owner = root

func _arrow(parent: Node3D, owner_node: Node, axis: Vector3, color: Color, text: String) -> void:
    var m := MeshInstance3D.new()
    m.name = "Axis_" + text
    var c := CylinderMesh.new()
    c.top_radius = 0.02
    c.bottom_radius = 0.02
    c.height = 1.0
    m.mesh = c
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.no_depth_test = true
    m.material_override = mat
    if axis == Vector3.RIGHT:
        m.rotation_degrees = Vector3(0, 0, -90)
    elif axis == Vector3.BACK:
        m.rotation_degrees = Vector3(90, 0, 0)
    m.position = axis * 0.5
    parent.add_child(m)
    m.owner = owner_node
    var l := Label3D.new()
    l.name = "AxisLabel_" + text
    l.text = text
    l.modulate = color
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = true
    l.font_size = 64
    l.pixel_size = 0.004
    l.position = axis * 1.1
    parent.add_child(l)
    l.owner = owner_node

func _walk(n: Node, depth: int) -> void:
    var line := "  ".repeat(depth) + str(n.name) + " (" + n.get_class() + ")"
    var n3 := n as Node3D
    if n3 != null:
        line += " pos=" + str(n3.position) + " scale=" + str(n3.scale)
    var mi := n as MeshInstance3D
    if mi != null and mi.mesh != null:
        var a: AABB = mi.mesh.get_aabb()
        line += " mesh_aabb_pos=" + str(a.position) + " size=" + str(a.size)
    print(line)
    for c in n.get_children():
        _walk(c, depth + 1)
