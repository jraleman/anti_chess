extends RefCounted

## Turned chessmen, bevelled carvings and an inlaid table, each in one surface.

const State = preload("res://games/anti_chess/board/chess_state.gd")
const Options = preload("res://games/anti_chess/anti_chess_options.gd")
const IVORY := Color("d6c7ad")
const INK := Color("51415e")
const BRASS := Color("bd9154")
const WALNUT := Color("2b2027")
const JADE := Color("385b54")
const PIECE_HEIGHTS := [0.0, 1.00, 1.33, 1.40, 1.19, 1.34, 1.50]

var _surface := SurfaceTool.new()
var _faceted := false
var _radial_segments := 40


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


## Each silhouette has its own crown; colour is not needed to identify a piece.
static func piece(
	kind: int, side: int, accent: Color, finish_id := Options.FINISH_CLASSIC
) -> ArrayMesh:
	var maker := new()
	var finish := _finish_definition(finish_id)
	maker._faceted = bool(finish.get("faceted", false))
	maker._radial_segments = 12 if maker._faceted else 40
	var body := finish_color(finish_id, side)
	var identity := IVORY if side == State.WHITE else INK
	maker._lathe(PackedVector2Array([
		Vector2(0.28, 0.02), Vector2(0.32, 0.035), Vector2(0.35, 0.065),
		Vector2(0.355, 0.10), Vector2(0.35, 0.14), Vector2(0.32, 0.165),
		Vector2(0.29, 0.18), Vector2(0.28, 0.205), Vector2(0.28, 0.225),
		Vector2(0.25, 0.25), Vector2(0.23, 0.27),
	]), body)
	maker._cylinder(0.354, 0.354, 0.022, Vector3(0, 0.112, 0), accent)
	maker._cylinder(0.321, 0.34, 0.022, Vector3(0, 0.043, 0), identity)
	if side == State.BLACK:
		maker._cylinder(0.285, 0.285, 0.025, Vector3(0, 0.21, 0), accent)
	match kind:
		State.PAWN:
			maker._lathe(PackedVector2Array([
				Vector2(0.23, 0.27), Vector2(0.19, 0.31),
				Vector2(0.145, 0.40), Vector2(0.115, 0.50),
				Vector2(0.11, 0.55), Vector2(0.145, 0.585),
				Vector2(0.195, 0.605), Vector2(0.20, 0.63),
				Vector2(0.17, 0.66), Vector2(0.10, 0.675),
			]), body)
			maker._sphere(0.19, Vector3(0, 0.795, 0), body)
		State.ROOK:
			maker._lathe(PackedVector2Array([
				Vector2(0.23, 0.27), Vector2(0.195, 0.34),
				Vector2(0.18, 0.43), Vector2(0.18, 0.72),
				Vector2(0.20, 0.81), Vector2(0.235, 0.83),
				Vector2(0.245, 0.855), Vector2(0.24, 0.875),
				Vector2(0.29, 0.92), Vector2(0.295, 0.975),
			]), body)
			maker._cylinder(0.205, 0.205, 0.008,
				Vector3(0, 0.98, 0), body.darkened(0.42))
			for index in 6:
				var angle := TAU * float(index) / 6.0
				maker._box(Vector3(0.145, 0.19, 0.15),
					Vector3(cos(angle) * 0.222, 1.07, sin(angle) * 0.222),
					body, Basis(Vector3.UP, -angle))
		State.KNIGHT:
			maker._lathe(PackedVector2Array([
				Vector2(0.23, 0.27), Vector2(0.19, 0.34),
				Vector2(0.185, 0.40), Vector2(0.235, 0.435),
				Vector2(0.245, 0.465), Vector2(0.215, 0.50),
			]), body)
			maker._horse_head(body)
		State.BISHOP:
			maker._stem(body, 0.83)
			maker._bevelled_profile(PackedVector2Array([
				Vector2(-0.13, 0.86), Vector2(0.13, 0.86),
				Vector2(0.225, 0.97), Vector2(0.185, 1.115),
				Vector2(0.045, 1.015), Vector2(0.005, 1.065),
				Vector2(0.155, 1.19), Vector2(0, 1.34),
				Vector2(-0.155, 1.14), Vector2(-0.225, 0.98),
			]), 0.17, body, Vector2(0, 1.03))
			maker._sphere(0.036, Vector3(0, 1.345, 0), body)
		State.QUEEN:
			maker._stem(body, 0.87)
			maker._lathe(PackedVector2Array([
				Vector2(0.14, 0.88), Vector2(0.16, 0.94),
				Vector2(0.235, 1.04), Vector2(0.27, 1.075),
				Vector2(0.275, 1.10), Vector2(0.235, 1.12),
			]), body)
			for index in 8:
				var angle := TAU * float(index) / 8.0
				var at := Vector3(cos(angle) * 0.235, 1.175, sin(angle) * 0.235)
				maker._cylinder(0.027, 0.055, 0.16, at, body)
				maker._sphere(0.04, at + Vector3.UP * 0.08, body)
			maker._sphere(0.085, Vector3(0, 1.20, 0), body)
			maker._sphere(0.035, Vector3(0, 1.295, 0), body)
		State.KING:
			maker._stem(body, 0.92)
			maker._sphere(0.17, Vector3(0, 1.035, 0), body)
			maker._cylinder(0.125, 0.16, 0.045, Vector3(0, 1.13, 0), body)
			maker._bevelled_profile(PackedVector2Array([
				Vector2(-0.05, 1.15), Vector2(0.05, 1.15),
				Vector2(0.05, 1.285), Vector2(0.165, 1.285),
				Vector2(0.165, 1.38), Vector2(0.05, 1.38),
				Vector2(0.05, 1.475), Vector2(-0.05, 1.475),
				Vector2(-0.05, 1.38), Vector2(-0.165, 1.38),
				Vector2(-0.165, 1.285), Vector2(-0.05, 1.285),
			]), 0.06, body, Vector2(0, 1.33))
	return maker._finish()


## The board and store portraits share the very same opaque Compatibility material.
static func piece_material(finish_id := Options.FINISH_CLASSIC) -> StandardMaterial3D:
	var finish := _finish_definition(finish_id)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = float(finish.get("roughness", 0.38))
	material.metallic = float(finish.get("metallic", 0.0))
	return material


## Classic follows chess sides; every other finish follows the equipped player.
static func finish_color(finish_id: String, side: int) -> Color:
	var finish := _finish_definition(finish_id)
	if str(finish["id"]) == Options.FINISH_CLASSIC:
		return IVORY if side == State.WHITE else INK
	return finish["color"]


static func _finish_definition(finish_id: String) -> Dictionary:
	for item in Options.STORE_ITEMS:
		if str(item["id"]) == finish_id:
			return item
	if not finish_id.is_empty():
		push_warning("Unknown chess finish '%s'; using Classic." % finish_id)
	return Options.STORE_ITEMS[0]


## Static scenery uses one surface, including the two trays for pieces given away.
static func table() -> ArrayMesh:
	var maker := new()
	maker._box(Vector3(9.8, 0.30, 12.0), Vector3(0, -0.28, 0), WALNUT)
	maker._box(Vector3(9.55, 0.14, 11.75), Vector3(0, -0.06, 0), JADE)
	maker._box(Vector3(8.95, 0.22, 8.95), Vector3(0, 0.04, 0), WALNUT)
	maker._box(Vector3(8.1, 0.06, 8.1), Vector3(0, 0.105, 0), BRASS)
	for side in [-1.0, 1.0]:
		maker._box(Vector3(0.025, 0.015, 8.7),
			Vector3(side * 4.34, 0.157, 0), BRASS)
		maker._box(Vector3(8.7, 0.015, 0.025),
			Vector3(0, 0.157, side * 4.34), BRASS)
		maker._box(Vector3(8.75, 0.10, 1.1),
			Vector3(0, 0.04, side * 5.20), WALNUT)
		maker._box(Vector3(8.55, 0.03, 0.91),
			Vector3(0, 0.105, side * 5.20), Color("1c3030"))
		maker._box(Vector3(8.6, 0.025, 0.025),
			Vector3(0, 0.13, side * 5.68), BRASS)
		for x in [-4.65, 4.65]:
			maker._sphere(0.055, Vector3(x, 0.04, side * 5.70), BRASS)
			maker._cylinder(0.20, 0.14, 0.28,
				Vector3(x, -0.54, side * 5.40), WALNUT)
	return maker._finish()


func _stem(color: Color, height: float) -> void:
	_lathe(PackedVector2Array([
		Vector2(0.23, 0.27), Vector2(0.195, 0.32),
		Vector2(0.16, 0.40), Vector2(0.13, 0.50),
		Vector2(0.105, height - 0.19), Vector2(0.11, height - 0.13),
		Vector2(0.14, height - 0.09), Vector2(0.20, height - 0.055),
		Vector2(0.215, height - 0.025), Vector2(0.205, height),
		Vector2(0.14, height + 0.025),
	]), color)


func _lathe(profile: PackedVector2Array, color: Color) -> void:
	for index in range(profile.size() - 1):
		var a := profile[index]
		var b := profile[index + 1]
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = a.x
		mesh.top_radius = b.x
		mesh.height = b.y - a.y
		mesh.radial_segments = _radial_segments
		mesh.rings = 1
		mesh.cap_bottom = index == 0
		mesh.cap_top = index == profile.size() - 2
		_append(mesh, Vector3(0, (a.y + b.y) * 0.5, 0), color)


func _horse_head(color: Color) -> void:
	var profile := PackedVector2Array([
		Vector2(-0.23, 0.48), Vector2(0.16, 0.48),
		Vector2(0.13, 0.64), Vector2(0.045, 0.82),
		Vector2(0.12, 0.91), Vector2(0.30, 0.855),
		Vector2(0.38, 0.91), Vector2(0.38, 1.015),
		Vector2(0.20, 1.135), Vector2(0.065, 1.20),
		Vector2(-0.045, 1.18), Vector2(-0.19, 1.04),
		Vector2(-0.25, 0.79), Vector2(-0.28, 0.59),
	])
	_bevelled_profile(profile, 0.155, color, Vector2(-0.02, 0.84))
	for side in [-1.0, 1.0]:
		_bevelled_profile(PackedVector2Array([
			Vector2(-0.085, 1.135), Vector2(0.035, 1.155),
			Vector2(-0.005, 1.30), Vector2(-0.065, 1.26),
		]), 0.035, color, Vector2(-0.03, 1.20), Vector3(0, 0, side * 0.09))
		_sphere(0.075, Vector3(0.015, 0.97, side * 0.115), color,
			Basis.from_scale(Vector3(0.9, 1.2, 0.65)))
		_sphere(0.025, Vector3(0.105, 1.105, side * 0.145), WALNUT)
		_sphere(0.009, Vector3(0.11, 1.113, side * 0.166), IVORY)
		_sphere(0.014, Vector3(0.33, 0.975, side * 0.142), color.darkened(0.65))
	for index in 6:
		var y := 0.66 + index * 0.072
		var x := -0.26 + maxf(y - 0.8, 0.0) * 0.35
		_box(Vector3(0.05, 0.052, 0.19), Vector3(x, y, 0),
			color.darkened(0.28), Basis(Vector3.FORWARD, -0.22))


func _bevelled_profile(
	profile: PackedVector2Array, depth: float, color: Color,
	center: Vector2, at := Vector3.ZERO
) -> void:
	var layers: Array[Vector2] = [Vector2(-depth, 0.82), Vector2(-depth * 0.55, 1.0),
		Vector2(depth * 0.55, 1.0), Vector2(depth, 0.82)]
	for layer in range(layers.size() - 1):
		for index in profile.size():
			var next := (index + 1) % profile.size()
			var a := center + (profile[index] - center) * layers[layer].y
			var b := center + (profile[next] - center) * layers[layer].y
			var c := center + (profile[next] - center) * layers[layer + 1].y
			var d := center + (profile[index] - center) * layers[layer + 1].y
			var p := at + Vector3(a.x, a.y, layers[layer].x)
			var q := at + Vector3(b.x, b.y, layers[layer].x)
			var r := at + Vector3(c.x, c.y, layers[layer + 1].x)
			var s := at + Vector3(d.x, d.y, layers[layer + 1].x)
			_triangle(p, q, r, color)
			_triangle(p, r, s, color)
	var indices := Geometry2D.triangulate_polygon(profile)
	for index in range(0, indices.size(), 3):
		var a := center + (profile[indices[index]] - center) * 0.82
		var b := center + (profile[indices[index + 1]] - center) * 0.82
		var c := center + (profile[indices[index + 2]] - center) * 0.82
		_triangle(at + Vector3(a.x, a.y, depth), at + Vector3(b.x, b.y, depth),
			at + Vector3(c.x, c.y, depth), color)
		_triangle(at + Vector3(c.x, c.y, -depth), at + Vector3(b.x, b.y, -depth),
			at + Vector3(a.x, a.y, -depth), color)


func _box(size: Vector3, at: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_append(mesh, at, color, basis)


func _cylinder(top: float, bottom: float, height: float, at: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12 if maxf(top, bottom) < 0.09 else _radial_segments
	mesh.rings = 1
	_append(mesh, at, color)


func _sphere(radius: float, at: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var small := radius < 0.06
	mesh.radial_segments = 12 if _faceted or small else 24
	mesh.rings = 6 if _faceted or small else 12
	_append(mesh, at, color, basis)


func _append(
	mesh: PrimitiveMesh, at: Vector3, color: Color, basis := Basis.IDENTITY
) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_basis := basis.inverse().transposed()
	for triangle in range(0, indices.size(), 3):
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		var face_normal := (c - a).cross(b - a).normalized()
		for corner in 3:
			var index := indices[triangle + corner]
			_surface.set_color(_facet_color(color, face_normal) if _faceted else color)
			_surface.set_normal((normal_basis * (
				face_normal if _faceted else normals[index]
			)).normalized())
			_surface.add_vertex(at + basis * vertices[index])


func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, c, b]:
		_surface.set_color(_facet_color(color, normal) if _faceted else color)
		_surface.set_normal(normal)
		_surface.add_vertex(point)


func _facet_color(color: Color, normal: Vector3) -> Color:
	return color.darkened(0.12 * absf(normal.x * normal.z) * 2.0)


func _finish() -> ArrayMesh:
	_surface.index()
	return _surface.commit()
