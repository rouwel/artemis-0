extends SceneTree

# Read-only room measurement tool for Godot 4.7
# Run: Godot --headless --path . --script res://tools/measure_rooms.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const OUT_PATH := "res://tools/room_profile.txt"
const ROOM_NAMES := ["RoomLarge", "SmallRoom1", "SmallRoom2", "SmallRoom3"]
const ROOM_CENTERS := {
	"RoomLarge": Vector3(0, 0, 0),
	"SmallRoom1": Vector3(12, 0, 0),
	"SmallRoom2": Vector3(-12, 0, 0),
	"SmallRoom3": Vector3(0, 0, -12),
}

var _lines: Array[String] = []
var _wall_items: Array = [] # {mesh: TriangleMesh, xform: Transform3D, room: String, name: String}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	_log("=== measure_rooms.gd ===")
	if not ResourceLoader.exists(MAIN_SCENE):
		_err("Missing main scene: %s" % MAIN_SCENE)
		_finish()
		return
	var ps = load(MAIN_SCENE)
	if ps == null or not (ps is PackedScene):
		_err("Failed to load PackedScene: %s" % MAIN_SCENE)
		_finish()
		return
	var inst = ps.instantiate()
	if inst == null:
		_err("Failed to instantiate main scene")
		_finish()
		return
	# BEFORE adding to tree, free specified nodes if present
	for nm in ["StationAdditions", "Player", "Floor"]:
		var n = inst.get_node_or_null(nm)
		if n:
			_log("Freeing node before add: %s" % nm)
			n.free()
	root.add_child(inst)
	await process_frame
	_collect_geometry(inst)
	for room in ROOM_NAMES:
		_measure_room(room)
	_save()
	_log("Saved: %s" % OUT_PATH)
	_finish()

func _finish() -> void:
	quit()

func _log(s: String) -> void:
	print(s)
	_lines.append(s)

func _err(s: String) -> void:
	push_error(s)
	_log("ERROR: " + s)

func _collect_geometry(root_node: Node) -> void:
	_wall_items.clear()
	# Room meshes
	for room in ROOM_NAMES:
		var rn = root_node.get_node_or_null(room)
		if rn == null:
			_err("Room node not found: %s" % room)
			continue
		_collect_meshes_under(rn, room)
	# Blocker* / CapA anywhere, assigned to nearest room centre
	_collect_blockers_caps(root_node)
	_log("Collected wall mesh items: %d" % _wall_items.size())

func _collect_meshes_under(n: Node, room: String) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			var tm = mi.mesh.generate_triangle_mesh()
			if tm:
				_wall_items.append({"mesh": tm, "xform": mi.global_transform, "room": room, "name": mi.get_path()})
	for c in n.get_children():
		_collect_meshes_under(c, room)

func _collect_blockers_caps(root_node: Node) -> void:
	var nodes: Array[Node] = []
	_gather_by_name(root_node, nodes)
	for n in nodes:
		var room = _nearest_room(n)
		if n is MeshInstance3D:
			_collect_meshes_under_assigned(n, room)
		else:
			_collect_meshes_under(n, room)

func _gather_by_name(n: Node, out: Array[Node]) -> void:
	var nm = str(n.name)
	if nm.begins_with("Blocker") or nm == "CapA":
		out.append(n)
	for c in n.get_children():
		_gather_by_name(c, out)

func _nearest_room(n: Node) -> String:
	var p := Vector3.ZERO
	if n is Node3D:
		p = (n as Node3D).global_position
	var best := "RoomLarge"
	var best_d := INF
	for r in ROOM_NAMES:
		var d = p.distance_to(ROOM_CENTERS[r])
		if d < best_d:
			best_d = d
			best = r
	return best

func _collect_meshes_under_assigned(n: Node, room: String) -> void:
	# avoid double-adding if already under room? blockers are under rooms in main.tscn, so they were collected; check by path
	# but easier to skip duplicates by name+room not necessary; duplicates rare
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			var tm = mi.mesh.generate_triangle_mesh()
			if tm:
				_wall_items.append({"mesh": tm, "xform": mi.global_transform, "room": room, "name": str(mi.get_path())})
	for c in n.get_children():
		_collect_meshes_under_assigned(c, room)

func _cast(origin: Vector3, dir: Vector3, max_dist: float = 25.0, room_filter: String = "") -> Variant:
	var best: Variant = null
	var best_d := INF
	var end := origin + dir.normalized() * max_dist
	for item in _wall_items:
		if room_filter != "" and str(item.room) != room_filter:
			continue
		var xform: Transform3D = item.xform
		var inv: Transform3D = xform.affine_inverse()
		var local_o := inv * origin
		var local_e := inv * end
		var tm: TriangleMesh = item.mesh
		if tm == null:
			continue
		var res: Dictionary = tm.intersect_ray(local_o, local_e)
		if res.is_empty():
			continue
		var local_hit: Vector3 = res.position
		var world_hit: Vector3 = xform * local_hit
		var d := origin.distance_to(world_hit)
		if d < best_d:
			best_d = d
			var local_n: Vector3 = res.get("normal", Vector3.UP)
			var world_n := (xform.basis * local_n).normalized()
			best = {"position": world_hit, "distance": d, "normal": world_n}
	return best

func _measure_room(room: String) -> void:
	_log("")
	_log("===== ROOM: %s =====" % room)
	var center: Vector3 = ROOM_CENTERS[room]
	_log("center_world=%s" % [center])
	# a) floor and ceiling heights
	var sample_xz := [Vector2(0,0), Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1), Vector2(2,2), Vector2(-2,-2)]
	_log("-- Floor/Ceiling samples (room-filtered rays) --")
	for off in sample_xz:
		var o_floor := Vector3(center.x + off.x, 3.0, center.z + off.y)
		var hf = _cast(o_floor, Vector3.DOWN, 25.0, room)
		var o_ceil := Vector3(center.x + off.x, 1.0, center.z + off.y)
		var hc = _cast(o_ceil, Vector3.UP, 25.0, room)
		var fs = "MISS" if hf == null else str(snappedf((hf as Dictionary).position.y, 0.01))
		var cs = "MISS" if hc == null else str(snappedf((hc as Dictionary).position.y, 0.01))
		_log("sample xz=%s floor_y=%s ceiling_y=%s" % [off, fs, cs])
	# b) radial scan
	for h in [0.5, 1.2, 2.5, 3.8]:
		var parts: Array[String] = []
		var origin := Vector3(center.x, h, center.z)
		for a in range(0, 360, 5):
			var rad = deg_to_rad(float(a))
			var dir = Vector3(cos(rad), 0, sin(rad))
			var hit = _cast(origin, dir, 25.0, room)
			if hit == null:
				parts.append("%d:MISS" % a)
			else:
				parts.append("%d:%.3f" % [a, (hit as Dictionary).distance])
		_log("RADIAL y=%.1f %s" % [h, " ".join(parts)])
	# c) straight scan
	var is_large = (room == "RoomLarge")
	var side_range = 9.5 if is_large else 5.5
	for dir_info in [["+X", Vector3(1,0,0), Vector3(0,0,1)], ["-X", Vector3(-1,0,0), Vector3(0,0,1)], ["+Z", Vector3(0,0,1), Vector3(1,0,0)], ["-Z", Vector3(0,0,-1), Vector3(1,0,0)]]:
		var dname: String = dir_info[0]
		var dir: Vector3 = dir_info[1]
		var side: Vector3 = dir_info[2]
		for h in [1.2, 3.0]:
			_straight_scan(room, center, dname, dir, side, h, side_range)

func _straight_scan(room: String, center: Vector3, dname: String, dir: Vector3, side: Vector3, h: float, side_range: float) -> void:
	var hits: Array = [] # {side: float, world_coord: float, pos: Vector3, miss: bool}
	var s := -side_range
	while s <= side_range + 0.001:
		var origin = center + side * s + Vector3(0, h, 0)
		var res = _cast(origin, dir, 25.0, room)
		if res == null:
			hits.append({"s": snappedf(s, 0.1), "miss": true})
		else:
			var p: Vector3 = (res as Dictionary).position
			var coord = p.x if abs(dir.x) > 0.5 else p.z
			hits.append({"s": snappedf(s, 0.1), "miss": false, "coord": coord, "pos": p})
		s += 0.5
	# summarize
	var coords: Array[float] = []
	for hinfo in hits:
		if not hinfo.miss:
			coords.append(snappedf(float(hinfo.coord), 0.05))
	var main_plane_str := "none"
	var plane_ranges: Array = []
	var openings: Array = []
	var obstructions: Array = []
	if coords.size() > 0:
		# most common coord
		var counts := {}
		for c in coords:
			var k = "%.2f" % c
			counts[k] = counts.get(k, 0) + 1
		var best_k = ""; var best_n = -1
		for k in counts.keys():
			if int(counts[k]) > best_n:
				best_n = int(counts[k]); best_k = k
		main_plane_str = best_k
		var main_c = float(best_k)
		# ranges where flat wall exists (hit near main plane)
		var in_plane = false; var ps = 0.0
		for hinfo in hits:
			var is_plane = (not hinfo.miss and abs(float(hinfo.coord) - main_c) <= 0.1)
			if is_plane and not in_plane:
				in_plane = true; ps = float(hinfo.s)
			if (not is_plane) and in_plane:
				in_plane = false; plane_ranges.append([ps, float(hinfo.s) - 0.5])
			if (not hinfo.miss) and abs(float(hinfo.coord) - main_c) > 0.1:
				obstructions.append({"s": hinfo.s, "coord": snappedf(float(hinfo.coord), 0.05)})
		if in_plane:
			plane_ranges.append([ps, float(hits[hits.size()-1].s)])
	# openings (MISS ranges)
	var in_miss = false; var ms = 0.0
	for hinfo in hits:
		if hinfo.miss and not in_miss:
			in_miss = true; ms = float(hinfo.s)
		if (not hinfo.miss) and in_miss:
			in_miss = false
			var me = float(hinfo.s) - 0.5
			openings.append({"from": ms, "to": me, "width": abs(me-ms)})
	if in_miss:
		var me = float(hits[hits.size()-1].s)
		openings.append({"from": ms, "to": me, "width": abs(me-ms)})
	_log("STRAIGHT room=%s dir=%s y=%.1f main_plane_world=%s plane_ranges=%s openings=%s obstructions=%s" % [room, dname, h, main_plane_str, str(plane_ranges), str(openings), str(obstructions)])

func _save() -> void:
	var fa = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if fa == null:
		push_error("Failed to write %s" % OUT_PATH)
		_log("ERROR: Failed to write %s" % OUT_PATH)
		return
	fa.store_string("\n".join(_lines) + "\n")
	fa.close()
