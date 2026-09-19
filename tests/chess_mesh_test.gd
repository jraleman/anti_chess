extends SceneTree

## Node-free geometry coverage for every finish, picking envelope and side marking.

const State = preload("res://games/anti_chess/board/chess_state.gd")
const ChessMesh = preload("res://games/anti_chess/board/chess_mesh.gd")
const Options = preload("res://games/anti_chess/anti_chess_options.gd")

var _failures := PackedStringArray()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for item in Options.STORE_ITEMS:
		var id := str(item["id"])
		var material := ChessMesh.piece_material(id)
		_expect(material.vertex_color_use_as_albedo
			and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
			"%s must remain opaque and vertex-coloured." % id)
		_expect(is_equal_approx(material.metallic, float(item.get("metallic", 0.0)))
			and is_equal_approx(material.roughness, float(item.get("roughness", 0.38))),
			"%s must use its declared finish, not just its swatch colour." % id)
		for side in 2:
			for kind in range(State.PAWN, State.KING + 1):
				var mesh := ChessMesh.piece(kind, side, Color.CORNFLOWER_BLUE, id)
				_test_mesh(mesh, kind, "%s / %d / %d" % [id, side, kind])
				var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
				if not bool(item.get("faceted", false)):
					_expect(colors.has(ChessMesh.finish_color(id, side))
						and colors.has(Color.CORNFLOWER_BLUE),
						"Whole bodies must wear %s without losing the player-colour ring." % id)
	var white := ChessMesh.piece(State.PAWN, State.WHITE, Color.RED, Options.FINISH_GOLD)
	var black := ChessMesh.piece(State.PAWN, State.BLACK, Color.RED, Options.FINISH_GOLD)
	_expect(black.get_faces().size() > white.get_faces().size(),
		"Black must retain its second physical base ring even when both finishes match.")
	var diamond := ChessMesh.piece(State.PAWN, State.WHITE, Color.RED, Options.FINISH_DIAMOND)
	_expect(diamond.get_faces().size() < white.get_faces().size(),
		"Diamond must have real gem-cut facets rather than merely a blue swatch.")
	var bishop := ChessMesh.piece(State.BISHOP, State.WHITE, Color.RED)
	_expect(not _ray_hits(bishop, Vector3(0.105, 1.10, 0.6), Vector3.FORWARD),
		"The bishop's diagonal mitre slot must be open geometry, not a painted line.")
	_expect(_ray_hits(bishop, Vector3(-0.08, 1.10, 0.6), Vector3.FORWARD),
		"The solid side of the bishop's mitre must remain pickable.")
	_expect(ChessMesh.finish_color(Options.FINISH_CLASSIC, State.WHITE) == ChessMesh.IVORY
		and ChessMesh.finish_color(Options.FINISH_CLASSIC, State.BLACK) == ChessMesh.INK,
		"Classic must preserve the original light/dark sides.")
	if _failures.is_empty():
		print("Anti-Chess mesh tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_mesh(mesh: ArrayMesh, kind: int, label: String) -> void:
	_expect(mesh.get_surface_count() == 1, label + " must use one batched surface.")
	var faces := mesh.get_faces()
	_expect(faces.size() > 300 and faces.size() < 30000,
		label + " must be detailed but stay below 10,000 triangles.")
	var bounds := mesh.get_aabb()
	_expect(bounds.position.y >= 0.0 and bounds.end.y <= ChessMesh.PIECE_HEIGHTS[kind],
		label + " must fit its picking height.")
	_expect(bounds.position.x >= -0.4 and bounds.end.x <= 0.4
		and bounds.position.z >= -0.4 and bounds.end.z <= 0.4,
		label + " must fit its square and broad-phase picking box.")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	_expect(vertices.size() == normals.size(), label + " must have complete normals.")
	for index in vertices.size():
		if not vertices[index].is_finite() or not normals[index].is_finite():
			_expect(false, label + " has invalid geometry.")
			break


func _ray_hits(mesh: ArrayMesh, origin: Vector3, direction: Vector3) -> bool:
	var faces := mesh.get_faces()
	for index in range(0, faces.size(), 3):
		if Geometry3D.ray_intersects_triangle(
			origin, direction, faces[index], faces[index + 1], faces[index + 2]
		) != null:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
