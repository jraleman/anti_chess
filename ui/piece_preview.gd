extends Control

## Still store portraits use the match's geometry and finishes, not separate artwork.

const ChessMesh = preload("res://games/anti_chess/board/chess_mesh.gd")
const State = preload("res://games/anti_chess/board/chess_state.gd")
const Options = preload("res://games/anti_chess/anti_chess_options.gd")

var _viewport: SubViewport
var _models: Array[MeshInstance3D] = []
var _finish_id := Options.FINISH_CLASSIC


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() == "headless":
		return
	_build_stage()
	_update_models()


## Accepts Store.describe() before or after entering the tree.
func configure(item: Dictionary) -> void:
	_finish_id = str(item.get("id", Options.FINISH_CLASSIC))
	_update_models()


## Portraits do not animate, including when reduced motion is disabled.
func set_preview_running(_running: bool) -> void:
	_redraw()


func _update_models() -> void:
	for side in _models.size():
		_models[side].mesh = ChessMesh.piece(
			State.KING if side == State.WHITE else State.KNIGHT,
			side, ChessMesh.BRASS, _finish_id
		)
		_models[side].material_override = ChessMesh.piece_material(_finish_id)
	_redraw()


func _redraw() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _build_stage() -> void:
	var container := SubViewportContainer.new()
	container.name = "Stage"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.name = "Portrait"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)
	_viewport.size_changed.connect(_redraw)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c7d4e5")
	environment.ambient_light_energy = 0.4
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_color = Color("ffe7c7")
	key.light_energy = 0.9
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-36, 145, 0)
	fill.light_color = Color("bacfed")
	fill.light_energy = 0.4
	_viewport.add_child(fill)

	for side in 2:
		var model := MeshInstance3D.new()
		model.name = "WhiteKing" if side == State.WHITE else "BlackKnight"
		model.position.x = -0.39 if side == State.WHITE else 0.39
		_viewport.add_child(model)
		_models.append(model)
	var camera := Camera3D.new()
	camera.name = "Lens"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.95
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(1.3, 1.8, 4.2)).looking_at(
		Vector3(0, 0.76, 0)
	)
	camera.current = true
	_viewport.add_child(camera)
