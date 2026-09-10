extends Node3D

## Read-only chess theatre. The model owns squares; animation never feeds rules.

signal presentation_changed

const State = preload("res://games/anti_chess/board/chess_state.gd")
const ChessMesh = preload("res://games/anti_chess/board/chess_mesh.gd")
const ChessCamera = preload("res://games/anti_chess/board/chess_camera.gd")
const BOARD_Y := 0.205
const MOVE_SECONDS := 0.28

var camera: ChessCamera
var flipped: bool:
	get:
		return camera != null and cos(camera.azimuth) < 0.0
var _reduced_motion := false
var _pieces: Array[Dictionary] = []
var _batches: Array[MultiMesh] = []
var _piece_faces: Array[PackedVector3Array] = []
var _piece_colors: Array[Color] = []
var _given: Array[int] = [0, 0]
var _move_clock := MOVE_SECONDS
var _built := false
var _material: StandardMaterial3D


func _ready() -> void:
	_build_world()


func _process(delta: float) -> void:
	var changed := false
	if _move_clock < MOVE_SECONDS:
		_move_clock = minf(_move_clock + delta, MOVE_SECONDS)
		var progress := _move_clock / MOVE_SECONDS
		var eased := smoothstep(0.0, 1.0, progress)
		for piece in _pieces:
			var start: Vector3 = piece["from"]
			var target: Vector3 = piece["to"]
			piece["position"] = start.lerp(target, eased)
			if not start.is_equal_approx(target):
				piece["position"] += Vector3.UP * sin(progress * PI) * 0.28
			piece["scale"] = lerpf(float(piece["from_scale"]), float(piece["to_scale"]), eased)
		_upload_pieces()
		changed = true
	if changed:
		presentation_changed.emit()


## Reuses meshes between matches and removes every previous capture/animation.
func reset(state: State, colors: Array[Color]) -> void:
	if not _built:
		_build_world()
	_rebuild_piece_meshes(colors)
	_pieces.clear()
	_given = [0, 0]
	_move_clock = MOVE_SECONDS
	camera.reset_view()
	for square in 64:
		var value := state.board[square]
		if value == State.EMPTY:
			continue
		var at := square_position(square)
		_pieces.append({
			"square": square, "type": absi(value), "side": State.side_of(value),
			"position": at, "from": at, "to": at,
			"scale": 1.0, "from_scale": 1.0, "to_scale": 1.0,
		})
	_upload_pieces()
	presentation_changed.emit()


## Camera mode is a match property; changing turns never moves it automatically.
func configure_camera(top_down: bool, home_side: int) -> void:
	if not _built:
		_build_world()
	camera.configure(top_down, home_side)


## Held keys move independently of turns and the CPU's incremental search.
func move_camera(direction: Vector2, delta: float) -> void:
	camera.move_camera(direction, delta)


## Pointer deltas use the same pixel space as board picking.
func drag_camera(relative: Vector2) -> void:
	camera.drag_camera(relative)


## Zoom never changes the rules or the camera mode.
func zoom_camera(steps: float) -> void:
	camera.zoom_camera(steps)


## Home framing restores the match's chosen side, zoom and pan.
func reset_camera() -> void:
	camera.reset_view()


## Cursor steps track the board axis nearest the requested screen direction.
func square_direction(direction: Vector2i) -> Vector2i:
	return camera.square_direction(direction)


## Captured pieces retire to their own tray, making giving them away visible.
func present_move(move: Dictionary, state: State) -> void:
	_settle_pieces()
	var source := int(move["from"])
	var target := int(move["to"])
	var captured := int(move["capture"])
	for piece in _pieces:
		piece["from"] = piece["position"]
		piece["from_scale"] = piece["scale"]
		if captured >= 0 and int(piece["square"]) == captured:
			var side := int(piece["side"])
			piece["square"] = -1
			piece["to"] = _tray_position(side, _given[side])
			piece["to_scale"] = 0.42
			_given[side] += 1
		elif int(piece["square"]) == source:
			piece["square"] = target
			piece["type"] = absi(state.board[target])
			piece["to"] = square_position(target)
	_move_clock = 0.0
	if _reduced_motion:
		_settle_pieces()
	_upload_pieces()
	presentation_changed.emit()


## Manual reorientation never swaps player identities or mutates the position.
func flip_board() -> void:
	camera.flip_view(_reduced_motion)


## Switching accessibility on finishes spatial transitions without rewinding them.
func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	if value:
		_settle_pieces()
		if _built:
			_upload_pieces()
			camera.finish_transition()
	presentation_changed.emit()


## The stretching container owns the actual viewport size.
func resize_view(size: Vector2) -> void:
	if camera != null:
		camera.resize_view(size)


## A plane intersection is exact for every orientation and needs no physics bodies.
func square_at(screen_position: Vector2) -> int:
	if camera == null:
		return -1
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, BOARD_Y).intersects_ray(origin, direction)
	if hit == null:
		return -1
	var point: Vector3 = hit
	var file := floori(point.x + 4.0)
	var rank := floori(4.0 - point.z)
	if file < 0 or file > 7 or rank < 0 or rank > 7:
		return -1
	return file + rank * 8


## Picking a crown must select its owner, not the tile behind its projected head.
func piece_at(screen_position: Vector2) -> int:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var closest := INF
	var square := -1
	for piece in _pieces:
		if int(piece["square"]) < 0:
			continue
		var at: Vector3 = piece["position"]
		var height: float = ChessMesh.PIECE_HEIGHTS[int(piece["type"])]
		var bounds := AABB(at + Vector3(-0.40, 0, -0.40), Vector3(0.80, height, 0.80))
		var hit: Variant = bounds.intersects_ray(origin, direction)
		if hit == null:
			continue
		# A crown's empty bounding-box corners must not steal a pawn behind it.
		var kind := int(piece["type"])
		var side := int(piece["side"])
		var inverse := _piece_basis(kind, side, float(piece["scale"])).inverse()
		var local_origin := inverse * (origin - at)
		var local_direction := (inverse * direction).normalized()
		var faces := _piece_faces[side * 6 + kind - 1]
		for index in range(0, faces.size(), 3):
			var intersection: Variant = Geometry3D.ray_intersects_triangle(
				local_origin, local_direction, faces[index], faces[index + 1], faces[index + 2]
			)
			if intersection == null:
				continue
			var distance := local_origin.distance_squared_to(intersection)
			if distance < closest:
				closest = distance
				square = int(piece["square"])
	return square


## Board and overlay use the same projection, including during camera movement.
func project(point: Vector3) -> Vector2:
	return camera.unproject_position(point) if camera != null else Vector2.ZERO


## World position of a square's top surface; a1 is on White's left.
static func square_position(square: int) -> Vector3:
	return Vector3(float(square % 8) - 3.5, BOARD_Y, 3.5 - float(square / 8))


## Native-resolution letter badges follow moving pieces rather than jumping ahead.
func piece_position(square: int) -> Vector3:
	for piece in _pieces:
		if int(piece["square"]) == square:
			return piece["position"]
	return square_position(square)


## Interaction waits for deliberate camera motion, not for a cosmetic piece hop.
func camera_is_moving() -> bool:
	return camera.is_transitioning()


func _settle_pieces() -> void:
	_move_clock = MOVE_SECONDS
	for piece in _pieces:
		piece["position"] = piece["to"]
		piece["from"] = piece["to"]
		piece["scale"] = piece["to_scale"]
		piece["from_scale"] = piece["to_scale"]


func _tray_position(side: int, index: int) -> Vector3:
	var z := 4.98 + float(index / 8) * 0.43
	return Vector3((float(index % 8) - 3.5) * 1.03, 0.13,
		z if side == State.WHITE else -z)


func _build_world() -> void:
	if _built:
		return
	_built = true
	_material = StandardMaterial3D.new()
	_material.vertex_color_use_as_albedo = true
	_material.vertex_color_is_srgb = true
	_material.roughness = 0.56
	var table := MeshInstance3D.new()
	table.name = "InlaidTable"
	table.mesh = ChessMesh.table()
	table.material_override = _material
	add_child(table)

	var tiles := MultiMeshInstance3D.new()
	tiles.name = "BoardSquares"
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(0.994, 0.065, 0.994)
	tile_mesh.material = _material
	var tile_batch := MultiMesh.new()
	tile_batch.transform_format = MultiMesh.TRANSFORM_3D
	tile_batch.use_colors = true
	tile_batch.mesh = tile_mesh
	tile_batch.instance_count = 64
	for square in 64:
		var at := square_position(square) - Vector3.UP * 0.0325
		tile_batch.set_instance_transform(square, Transform3D(Basis.IDENTITY, at))
		tile_batch.set_instance_color(square,
			Color("47716a") if (square % 8 + square / 8) % 2 == 0 else Color("e9dfca"))
	tiles.multimesh = tile_batch
	add_child(tiles)

	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(200, 200)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("172b29")
	felt.roughness = 1.0
	floor_mesh.material = felt
	var floor_node := MeshInstance3D.new()
	floor_node.name = "Felt"
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.71
	add_child(floor_node)

	for index in 12:
		var instance := MultiMeshInstance3D.new()
		instance.name = "Chessmen%d" % index
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.instance_count = 16
		batch.visible_instance_count = 0
		instance.multimesh = batch
		instance.material_override = _material
		_batches.append(batch)
		_piece_faces.append(PackedVector3Array())
		add_child(instance)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("152826")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c7d4e5")
	environment.ambient_light_energy = 0.25
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	add_child(environment_node)
	var key := DirectionalLight3D.new()
	key.name = "WarmKey"
	key.rotation_degrees = Vector3(-58, -28, 0)
	key.light_color = Color("ffe7c7")
	key.light_energy = 0.8
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 35.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "CoolFill"
	fill.rotation_degrees = Vector3(-36, 145, 0)
	fill.light_color = Color("bacfed")
	fill.light_energy = 0.2
	add_child(fill)
	camera = ChessCamera.new()
	camera.name = "BoardCamera"
	camera.view_changed.connect(func() -> void: presentation_changed.emit())
	add_child(camera)
	camera.current = true


func _rebuild_piece_meshes(colors: Array[Color]) -> void:
	for side in 2:
		for kind in range(State.PAWN, State.KING + 1):
			var batch := _batches[side * 6 + kind - 1]
			if batch.mesh == null or _piece_colors != colors:
				batch.mesh = ChessMesh.piece(kind, side, colors[side])
				_piece_faces[side * 6 + kind - 1] = batch.mesh.get_faces()
	_piece_colors = colors.duplicate()


func _upload_pieces() -> void:
	var counts: Array[int] = []
	counts.resize(12)
	counts.fill(0)
	for piece in _pieces:
		var side := int(piece["side"])
		var kind := int(piece["type"])
		var index := side * 6 + kind - 1
		var basis := _piece_basis(kind, side, float(piece["scale"]))
		_batches[index].set_instance_transform(counts[index],
			Transform3D(basis, piece["position"]))
		counts[index] += 1
	for index in 12:
		_batches[index].visible_instance_count = counts[index]


func _piece_basis(kind: int, side: int, scale_factor: float) -> Basis:
	var yaw := 0.0
	if kind == State.KNIGHT:
		yaw = PI * 0.5 if side == State.WHITE else -PI * 0.5
	return Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_factor)

