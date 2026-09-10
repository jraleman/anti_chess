extends RefCounted

## Original lathed chessmen and a brass-inlaid table, batched into single surfaces.

const State = preload("res://games/anti_chess/board/chess_state.gd")
const IVORY := Color("d6c7ad")
const INK := Color("51415e")
const BRASS := Color("bd9154")
const WALNUT := Color("2b2027")
const JADE := Color("385b54")
const PIECE_HEIGHTS := [0.0, 0.99, 1.23, 1.35, 1.12, 1.31, 1.44]

var _surface := SurfaceTool.new()


func _init() -> void:
	_surface.begin(Mesh.PRIMITIVE_TRIANGLES)


## Each silhouette has its own crown; colour is not needed to identify a piece.
static func piece(kind: int, side: int, accent: Color) -> ArrayMesh:
	var maker := new()
	var body := IVORY if side == State.WHITE else INK
	maker._lathe(PackedVector2Array([
		Vector2(0.29, 0.02), Vector2(0.34, 0.06), Vector2(0.34, 0.12),
		Vector2(0.27, 0.18), Vector2(0.24, 0.23),
	]), body)
	maker._cylinder(0.345, 0.345, 0.035, Vector3(0, 0.115, 0), accent)
	match kind:
		State.PAWN:
			maker._lathe(PackedVector2Array([
				Vector2(0.23, 0.23), Vector2(0.13, 0.43),
				Vector2(0.11, 0.58), Vector2(0.21, 0.63),
			]), body)
			maker._sphere(0.195, Vector3(0, 0.78, 0), body)
		State.ROOK:
			maker._lathe(PackedVector2Array([
				Vector2(0.23, 0.23), Vector2(0.18, 0.40),
				Vector2(0.20, 0.80), Vector2(0.29, 0.87),
				Vector2(0.29, 0.96),
			]), body)
			for index in 6:
				var angle := TAU * float(index) / 6.0
				maker._box(Vector3(0.15, 0.16, 0.15),
					Vector3(cos(angle) * 0.215, 1.025, sin(angle) * 0.215),
					body, Basis(Vector3.UP, -angle))
		State.KNIGHT:
			maker._lathe(PackedVector2Array([
				Vector2(0.23, 0.23), Vector2(0.19, 0.39),
				Vector2(0.24, 0.52), Vector2(0.22, 0.58),
			]), body)
			maker._horse_head(body)
		State.BISHOP:
			maker._stem(body, 0.76)
			maker._lathe(PackedVector2Array([
				Vector2(0.13, 0.78), Vector2(0.23, 0.95),
				Vector2(0.17, 1.12), Vector2(0.025, 1.28),
			]), body)
			maker._box(Vector3(0.045, 0.25, 0.026),
				Vector3(0.04, 1.075, 0.188), WALNUT, Basis(Vector3.FORWARD, 0.48))
			maker._sphere(0.045, Vector3(0, 1.295, 0), BRASS)
		State.QUEEN:
			maker._stem(body, 0.88)
			maker._cylinder(0.25, 0.15, 0.17, Vector3(0, 0.99, 0), body)
			for index in 7:
				var angle := TAU * float(index) / 7.0
				var at := Vector3(cos(angle) * 0.215, 1.145, sin(angle) * 0.215)
				maker._cylinder(0.035, 0.06, 0.16, at, body)
				maker._sphere(0.06, at + Vector3.UP * 0.09, BRASS)
			maker._sphere(0.09, Vector3(0, 1.15, 0), body)
		State.KING:
			maker._stem(body, 0.9)
			maker._sphere(0.18, Vector3(0, 1.035, 0), body)
			maker._box(Vector3(0.095, 0.32, 0.095), Vector3(0, 1.27, 0), body)
			maker._box(Vector3(0.30, 0.09, 0.095), Vector3(0, 1.30, 0), body)
			maker._box(Vector3(0.11, 0.07, 0.11), Vector3(0, 1.17, 0), BRASS)
	return maker._finish()


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
		Vector2(0.23, 0.23), Vector2(0.16, 0.40),
		Vector2(0.105, height - 0.16), Vector2(0.19, height - 0.07),
		Vector2(0.20, height), Vector2(0.13, height + 0.025),
	]), color)


func _lathe(profile: PackedVector2Array, color: Color) -> void:
	for index in range(profile.size() - 1):
		var a := profile[index]
		var b := profile[index + 1]
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = a.x
		mesh.top_radius = b.x
		mesh.height = b.y - a.y
		mesh.radial_segments = 20
		mesh.rings = 1
		mesh.cap_bottom = index == 0
		mesh.cap_top = index == profile.size() - 2
		_append(mesh, Vector3(0, (a.y + b.y) * 0.5, 0), color)


func _horse_head(color: Color) -> void:
	var profile := PackedVector2Array([
		Vector2(-0.20, 0.53), Vector2(0.12, 0.53), Vector2(0.04, 0.80),
		Vector2(0.29, 0.78), Vector2(0.36, 0.91), Vector2(0.20, 1.08),
		Vector2(0.04, 1.16), Vector2(-0.05, 1.08), Vector2(-0.12, 1.20),
		Vector2(-0.22, 1.08), Vector2(-0.25, 0.76),
	])
	var indices := Geometry2D.triangulate_polygon(profile)
	for index in range(0, indices.size(), 3):
		var a := profile[indices[index]]
		var b := profile[indices[index + 1]]
		var c := profile[indices[index + 2]]
		_triangle(Vector3(a.x, a.y, 0.12), Vector3(b.x, b.y, 0.12),
			Vector3(c.x, c.y, 0.12), color)
		_triangle(Vector3(c.x, c.y, -0.12), Vector3(b.x, b.y, -0.12),
			Vector3(a.x, a.y, -0.12), color)
	for index in profile.size():
		var a := profile[index]
		var b := profile[(index + 1) % profile.size()]
		var p := Vector3(a.x, a.y, -0.12)
		var q := Vector3(b.x, b.y, -0.12)
		var r := Vector3(b.x, b.y, 0.12)
		var s := Vector3(a.x, a.y, 0.12)
		_triangle(p, q, r, color)
		_triangle(p, r, s, color)
	for side in [-1.0, 1.0]:
		_sphere(0.028, Vector3(0.13, 1.025, side * 0.125), BRASS)
	for index in 4:
		_box(Vector3(0.055, 0.08, 0.255),
			Vector3(-0.225, 0.75 + index * 0.09, 0), color.darkened(0.25))


func _box(size: Vector3, at: Vector3, color: Color, basis := Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_append(mesh, at, color, basis)


func _cylinder(top: float, bottom: float, height: float, at: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	_append(mesh, at, color)


func _sphere(radius: float, at: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	_append(mesh, at, color)


func _append(
	mesh: PrimitiveMesh, at: Vector3, color: Color, basis := Basis.IDENTITY
) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		_surface.set_color(color)
		_surface.set_normal(basis * normals[index])
		_surface.add_vertex(at + basis * vertices[index])


func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point in [a, c, b]:
		_surface.set_color(color)
		_surface.set_normal(normal)
		_surface.add_vertex(point)


func _finish() -> ArrayMesh:
	_surface.index()
	return _surface.commit()
