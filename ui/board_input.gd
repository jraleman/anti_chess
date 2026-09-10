extends Control

## Native-resolution hints and a focusable input surface over the real 3D board.

signal square_pressed(square: int)
signal square_hovered(square: int)
signal camera_dragged(relative: Vector2)
signal camera_zoomed(steps: float)
signal key_input(event: InputEvent)

const State = preload("res://games/anti_chess/board/chess_state.gd")
const BoardView = preload("res://games/anti_chess/board/board_view.gd")
const LETTERS := ["", "P", "N", "B", "R", "Q", "K"]
const GOLD := Color("f3ce87")
const CREAM := Color("fff0d3")

var _view: BoardView
var _state: State
var _selected := -1
var _cursor := 12
var _hovered := -1
var _keyboard_cursor := false
var _hints := true
var _piece_labels := true
var _moves: Array[Dictionary] = []
var _dragging := false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	accessibility_name = "Chessboard"
	mouse_exited.connect(_clear_hover)
	focus_exited.connect(_stop_dragging)
	get_window().focus_exited.connect(_stop_dragging)


## Keeps hit testing and projected markings on the same camera.
func bind_view(view: BoardView) -> void:
	_view = view
	_view.presentation_changed.connect(_clear_hover)


## Presentation receives legal moves from the controller, never invents them.
func present(
	state: State, selected: int, cursor: int, moves: Array[Dictionary],
	hints: bool, piece_labels: bool, keyboard_cursor: bool
) -> void:
	_state = state
	_selected = selected
	_cursor = cursor
	_moves = moves
	_hints = hints
	_piece_labels = piece_labels
	_keyboard_cursor = keyboard_cursor
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _view == null:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion:
		if _dragging and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			camera_dragged.emit(event.relative)
			accept_event()
			return
		_stop_dragging()
		var square := _pick_square(event.position)
		if square != _hovered:
			_hovered = square
			square_hovered.emit(square)
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			grab_focus()
			_dragging = event.pressed
			mouse_default_cursor_shape = Control.CURSOR_DRAG if _dragging else Control.CURSOR_POINTING_HAND
			_clear_hover()
			accept_event()
		elif event.pressed and event.button_index in [
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
		]:
			camera_zoomed.emit(event.factor * (
				1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
			))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) == 0:
				_stop_dragging()
				grab_focus()
				square_pressed.emit(_pick_square(event.position))
			accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		grab_focus()
		square_pressed.emit(_pick_square(event.position))
		accept_event()
	elif event is InputEventKey:
		key_input.emit(event)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if not event.pressed:
			_stop_dragging()


func _stop_dragging() -> void:
	_dragging = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _pick_square(point: Vector2) -> int:
	var piece := _view.piece_at(point)
	return piece if piece >= 0 else _view.square_at(point)


func _draw() -> void:
	if _view == null or _state == null:
		return
	var a := _view.project(BoardView.square_position(0))
	var b := _view.project(BoardView.square_position(1))
	var tile_width := a.distance_to(b)
	var pixel_scale := maxf(get_screen_transform().get_scale().x, 0.01)
	var font_size := roundi(clampf(tile_width * 0.24, 10.0 / pixel_scale, 16.0 / pixel_scale))
	var line_width := maxf(1.6 / pixel_scale, tile_width * 0.035)
	if not _state.last_move.is_empty():
		for key in ["from", "to"]:
			_outline(int(_state.last_move[key]), Color(GOLD, 0.42), line_width)
	if _hints:
		var marked := {}
		for move in _moves:
			var source := int(move["from"])
			var target := int(move["to"])
			var capture := int(move["capture"]) >= 0
			if _selected < 0 and capture and not marked.has(source):
				marked[source] = true
				_outline(source, Color("f3b092"), line_width)
			elif source == _selected and not marked.has(target):
				marked[target] = true
				var at := _view.project(BoardView.square_position(target))
				if capture:
					_outline(target, Color("f3b092"), line_width * 1.5)
					_center_text("x", at + Vector2(tile_width * 0.28, 0),
						font_size, CREAM)
				else:
					draw_circle(at, tile_width * 0.115, Color("132d2b"))
					draw_circle(at, tile_width * 0.07, CREAM)
	if _selected >= 0:
		_outline(_selected, GOLD, line_width * 1.5)
	if _keyboard_cursor:
		_outline(_cursor, CREAM, line_width, 0.13)
	elif _hovered >= 0:
		_outline(_hovered, Color(CREAM, 0.65), line_width, 0.09)

	for file in 8:
		var at := Vector3(float(file) - 3.5, BoardView.BOARD_Y, 4.20)
		_center_text(String.chr(97 + file), _view.project(at), font_size, GOLD)
	for rank in 8:
		var at := Vector3(-4.22, BoardView.BOARD_Y, 3.5 - float(rank))
		_center_text(str(rank + 1), _view.project(at), font_size, GOLD)
	if not _piece_labels:
		return
	for square in 64:
		var piece := _state.board[square]
		if piece == State.EMPTY:
			continue
		var point := _view.piece_position(square)
		point += _view.camera.badge_offset()
		var at := _view.project(point)
		var white := piece > 0
		draw_circle(at, font_size * 0.62,
			Color("efdfc5") if white else Color("302637"))
		_center_text(LETTERS[absi(piece)], at, font_size,
			Color("172b29") if white else CREAM)


func _outline(square: int, color: Color, width: float, inset := 0.025) -> void:
	var center := BoardView.square_position(square)
	var radius := 0.5 - inset
	var points := PackedVector2Array()
	for offset in [
		Vector3(-radius, 0.012, -radius), Vector3(radius, 0.012, -radius),
		Vector3(radius, 0.012, radius), Vector3(-radius, 0.012, radius),
		Vector3(-radius, 0.012, -radius),
	]:
		points.append(_view.project(center + offset))
	draw_polyline(points, color, width, true)


func _center_text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, at + Vector2(-width * 0.5, font_size * 0.34),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _clear_hover() -> void:
	_hovered = -1
	square_hovered.emit(-1)
	queue_redraw()
