extends RefCounted

## Drives the development-only Anti-Chess tutorial capture.
##
## The shared recorder loads this script at runtime, so it does not preload the
## gameplay scene or any autoload instances. Every live move still runs through
## the real gameplay APIs; only clearly-labelled practice cuts install fixtures.

signal keycap_requested(text: String)

const State = preload("res://games/anti_chess/board/chess_state.gd")
const Options = preload("res://games/anti_chess/anti_chess_options.gd")

const SOLO := "solo"
const LOCAL := "local"
const CAPTURE_INSET := 260.0
const SOLO_DURATION := 35.0
const LOCAL_DURATION := 32.5

const PLAYER_SIDE_KEY := Options.PLAYER_SIDE_KEY
const SHOW_HINTS_KEY := Options.SHOW_HINTS_KEY
const PIECE_LABELS_KEY := Options.PIECE_LABELS_KEY
const CPU_DIFFICULTY_KEY := Options.CPU_DIFFICULTY_KEY
const CPU_THOUGHTFUL := Options.CPU_THOUGHTFUL

const CURSOR_UP_ACTION := Options.CURSOR_UP_ACTION
const CURSOR_DOWN_ACTION := Options.CURSOR_DOWN_ACTION
const SELECT_ACTION := Options.SELECT_ACTION
const CANCEL_ACTION := Options.CANCEL_ACTION
const FLIP_ACTION := Options.FLIP_ACTION
const CAMERA_UP_ACTION := Options.CAMERA_UP_ACTION
const CAMERA_RIGHT_ACTION := Options.CAMERA_RIGHT_ACTION
const CAMERA_RESET_ACTION := Options.CAMERA_RESET_ACTION

const SOLO_STEPS: Array[Dictionary] = [
	{
		"time": 0.0,
		"title": "White always opens",
		"body": (
			"In solo you choose White or Black before the match. "
			+ "Here the human chose Black, so the White CPU makes the first move."
		),
	},
	{
		"time": 5.4,
		"title": "Orbit, zoom and flip the board",
		"body": (
			"Right drag or the camera arrows orbit in solo. "
			+ "The wheel zooms, F flips the board, and Home resets the view."
		),
	},
	{
		"time": 11.0,
		"title": "Move the shared cursor",
		"body": (
			"WASD moves by square. Enter selects a piece or destination, "
			+ "and Backspace cancels the current choice."
		),
	},
	{
		"time": 16.2,
		"title": "Practice position: captures are compulsory",
		"body": (
			"If any capture exists, every quiet move is illegal. "
			+ "Kings are ordinary pieces too: no check and no castling."
		),
	},
	{
		"time": 22.4,
		"title": "Practice position: promotion can make a king",
		"body": (
			"Reaching the back rank pauses for a choice. "
			+ "A pawn may promote to a queen, rook, bishop, knight or king."
		),
	},
	{
		"time": 28.6,
		"title": "Practice position: lose your last piece to win",
		"body": (
			"Anti-Chess ends when you give away every piece, "
			+ "or when your side has no legal move."
		),
	},
]

const LOCAL_STEPS: Array[Dictionary] = [
	{
		"time": 0.0,
		"title": "White starts local play",
		"body": (
			"Local multiplayer is always Player 1 White versus "
			+ "Player 2 Black on one shared board."
		),
	},
	{
		"time": 5.2,
		"title": "Keep the overhead board readable",
		"body": (
			"Right drag or the camera arrows pan locally. "
			+ "The wheel zooms, F flips sides without tilting, and Home recentres."
		),
	},
	{
		"time": 10.8,
		"title": "One cursor, both players",
		"body": (
			"WASD moves by square. Enter selects a piece or destination "
			+ "for the side whose turn it is."
		),
	},
	{
		"time": 16.8,
		"title": "Practice position: captures are compulsory",
		"body": (
			"If the side to move has a capture, that player must take it. "
			+ "Quiet alternatives are not legal."
		),
	},
	{
		"time": 23.2,
		"title": "Practice position: no legal move also wins",
		"body": (
			"Here White gives away the knight, Black is forced to capture it, "
			+ "and the stuck White pawn wins the match."
		),
	},
]

var _variant := SOLO
var _done: Dictionary = {}
var _next_input_at := 0.0


## Validates the requested clip variant and resets any previous recorder state.
func configure(variant: String) -> bool:
	var normalized := variant.strip_edges().to_lower()
	if normalized not in [SOLO, LOCAL]:
		return false
	_variant = normalized
	_done.clear()
	_next_input_at = 0.0
	return true


## Returns the caption timeline for the active tutorial variant.
func steps() -> Array[Dictionary]:
	return SOLO_STEPS if _variant == SOLO else LOCAL_STEPS


## Returns the full capture length in seconds for the active tutorial variant.
func duration() -> float:
	return SOLO_DURATION if _variant == SOLO else LOCAL_DURATION


## Pins non-persistent chess settings so the take matches the written lesson.
func settings_overrides() -> Dictionary:
	var overrides := {
		SHOW_HINTS_KEY: true,
		PIECE_LABELS_KEY: true,
		CPU_DIFFICULTY_KEY: CPU_THOUGHTFUL,
	}
	overrides[PLAYER_SIDE_KEY] = State.BLACK if _variant == SOLO else State.WHITE
	return overrides


## Requests extra lower-screen space so captions do not cover board actions.
func capture_inset() -> float:
	return CAPTURE_INSET


## Chooses the live session mode before the gameplay scene is instantiated.
func configure_session(session: Node) -> void:
	if _variant == SOLO:
		session.call("configure_single_player")
	else:
		session.call("configure_multiplayer", 0)


## Gives the gameplay scene initial focus so scripted board input is accepted.
func start(scene: Node) -> void:
	_done.clear()
	_next_input_at = 0.0
	if _variant == SOLO:
		_freeze_scene(scene)
	_focus_board(scene)


## Advances the active tutorial by time, mixing live play with practice cuts.
func update(scene: Node, time: float, delta: float) -> void:
	if not _round_active(scene):
		return
	_focus_board(scene)
	if _variant == SOLO:
		_update_solo(scene, time, delta)
	else:
		_update_local(scene, time, delta)


func _update_solo(scene: Node, time: float, delta: float) -> void:
	if _take_once("solo-cpu-opening", time >= 1.5):
		scene.set_process(true)
	_run_solo_camera(scene, time, delta)
	_run_solo_opening(scene, time)
	if _take_once("solo-king-fixture", time >= 16.2):
		_install_practice_position(
			scene,
			"Practice position: White must capture with the king.",
			{"d4": State.KING, "e5": -State.KING, "h7": -State.PAWN},
			State.WHITE,
			false,
			State.BLACK,
			_square("d4")
		)
	if _take_input(
		"solo-king-capture",
		time,
		time >= 17.0 and _current_turn(scene) == State.WHITE and not _view_moving(scene)
	):
		_commit_named_move(scene, "d4", "e5")
	if _take_input(
		"solo-king-proof",
		time,
		time >= 18.0 and _current_turn(scene) == State.BLACK and not _view_moving(scene)
	):
		_commit_named_move(scene, "h7", "h6")
	if _take_once("solo-promotion-fixture", time >= 22.4):
		_install_practice_position(
			scene,
			"Practice position: Black is about to promote on h1.",
			{"a1": State.KING, "h2": -State.PAWN},
			State.BLACK,
			false,
			State.BLACK,
			_square("h2")
		)
	if _take_input(
		"solo-promotion-select",
		time,
		time >= 23.0 and _human_turn(scene, State.BLACK) and not _view_moving(scene)
	):
		_select_square(scene, "h2")
	if _take_input(
		"solo-promotion-target",
		time,
		time >= 23.35 and _human_turn(scene, State.BLACK) and _selected_square(scene) >= 0
	):
		_select_square(scene, "h1")
	if _take_input("solo-promotion-choose", time, time >= 24.0 and _dialog_visible(scene)):
		keycap_requested.emit("King")
		(scene.get("_dialog") as Control).call("_choose", State.KING)
		var state := scene.get("_state") as State
		if state.board[_square("h1")] != -State.KING or _dialog_visible(scene):
			_fail(scene, "The tutorial promotion did not close the real chooser with a king.")
		_focus_board(scene)
	if _take_once("solo-finish-fixture", time >= 28.6):
		_install_practice_position(
			scene,
			"Practice position: Black wins by giving away the last piece.",
			{"a1": State.ROOK, "h1": State.KING, "c6": -State.KNIGHT},
			State.BLACK,
			false,
			State.BLACK,
			_square("c6")
		)
	if _take_input(
		"solo-finish-offer",
		time,
		time >= 29.4 and _current_turn(scene) == State.BLACK and not _view_moving(scene)
	):
		_commit_named_move(scene, "c6", "a5")
	if _take_input(
		"solo-finish-capture",
		time,
		time >= 30.2 and _current_turn(scene) == State.WHITE and not _view_moving(scene)
	):
		_commit_named_move(scene, "a1", "a5")


func _run_solo_camera(scene: Node, time: float, delta: float) -> void:
	if time >= 5.7 and time < 6.7:
		if _take_once("solo-orbit-drag-keycap", true):
			keycap_requested.emit("RMB")
		scene.call("_drag_camera", Vector2(380.0, -108.0) * delta)
	if time >= 6.95 and time < 7.55:
		if _take_once("solo-orbit-arrow-keycap", true):
			keycap_requested.emit("→")
		_hold_camera_action(scene, CAMERA_RIGHT_ACTION, delta)
	if _take_input("solo-zoom", time, time >= 7.9):
		keycap_requested.emit("Wheel")
		scene.call("_zoom_camera", 1.8)
	if _take_input("solo-flip", time, time >= 8.45 and not _view_moving(scene)):
		_press_gameplay_action(scene, FLIP_ACTION, "F")
	if _take_input("solo-reset", time, time >= 9.15 and not _view_moving(scene)):
		_press_gameplay_action(scene, CAMERA_RESET_ACTION, "Home")


func _run_solo_opening(scene: Node, time: float) -> void:
	if time < 11.0 or _done.has("solo-opening-frozen") or _current_turn(scene) != State.BLACK:
		return
	if _take_input(
		"solo-open-select",
		time,
		time >= 11.15 and _selected_square(scene) < 0 and not _view_moving(scene)
	):
		_press_gameplay_action(scene, SELECT_ACTION, "Enter")
	if _take_input(
		"solo-open-cancel",
		time,
		time >= 11.5 and _selected_square(scene) >= 0 and not _view_moving(scene)
	):
		_press_gameplay_action(scene, CANCEL_ACTION, "Bksp")
	if _take_input(
		"solo-open-reselect",
		time,
		time >= 11.9 and _selected_square(scene) < 0 and not _view_moving(scene)
	):
		_press_gameplay_action(scene, SELECT_ACTION, "Enter")
	if _take_input(
		"solo-open-step",
		time,
		time >= 12.25 and _selected_square(scene) >= 0 and _cursor_square(scene) == _square("e7")
	):
		_press_gameplay_action(scene, CURSOR_UP_ACTION, "W")
	if _take_input(
		"solo-open-commit",
		time,
		time >= 12.6 and _selected_square(scene) >= 0 and _cursor_square(scene) == _square("e6")
	):
		_press_gameplay_action(scene, SELECT_ACTION, "Enter")
		_freeze_scene(scene)
		_done["solo-opening-frozen"] = true


func _update_local(scene: Node, time: float, delta: float) -> void:
	_run_local_opening(scene, time)
	_run_local_camera(scene, time, delta)
	_run_local_reply(scene, time)
	if _take_once("local-finish-fixture", time >= 16.8):
		_install_practice_position(
			scene,
			"Practice position: White offers the knight and Black must take it.",
			{
				"a2": State.PAWN, "c3": State.KNIGHT,
				"a3": -State.PAWN, "a8": -State.ROOK,
			},
			State.WHITE,
			true,
			State.WHITE,
			_square("c3")
		)
	if _take_input(
		"local-finish-offer",
		time,
		time >= 17.6 and _current_turn(scene) == State.WHITE and not _view_moving(scene)
	):
		_commit_named_move(scene, "c3", "a4")
	if _take_input(
		"local-finish-capture",
		time,
		time >= 25.2 and _current_turn(scene) == State.BLACK and not _view_moving(scene)
	):
		_commit_named_move(scene, "a8", "a4")


func _run_local_opening(scene: Node, time: float) -> void:
	if time < 1.6 or _done.has("local-white-opened") or _current_turn(scene) != State.WHITE:
		return
	if _take_input(
		"local-white-select",
		time,
		_selected_square(scene) < 0 and not _view_moving(scene)
	):
		_press_gameplay_action(scene, SELECT_ACTION, "Enter")
	if _take_input(
		"local-white-step-one",
		time,
		time >= 1.95 and _selected_square(scene) >= 0 and _cursor_square(scene) == _square("e2")
	):
		_press_gameplay_action(scene, CURSOR_UP_ACTION, "W")
	if _take_input(
		"local-white-step-two",
		time,
		time >= 2.25 and _selected_square(scene) >= 0 and _cursor_square(scene) == _square("e3")
	):
		_press_gameplay_action(scene, CURSOR_UP_ACTION, "W")
	if _take_input(
		"local-white-commit",
		time,
		time >= 2.55 and _selected_square(scene) >= 0 and _cursor_square(scene) == _square("e4")
	):
		_press_gameplay_action(scene, SELECT_ACTION, "Enter")
		_done["local-white-opened"] = true


func _run_local_camera(scene: Node, time: float, delta: float) -> void:
	if time >= 5.45 and time < 6.45:
		if _take_once("local-pan-drag-keycap", true):
			keycap_requested.emit("RMB")
		scene.call("_drag_camera", Vector2(470.0, -156.0) * delta)
	if time >= 6.75 and time < 7.35:
		if _take_once("local-pan-arrow-keycap", true):
			keycap_requested.emit("↑")
		_hold_camera_action(scene, CAMERA_UP_ACTION, delta)
	if _take_input("local-zoom", time, time >= 7.75):
		keycap_requested.emit("Wheel")
		scene.call("_zoom_camera", 1.8)
	if _take_input("local-flip", time, time >= 8.3 and not _view_moving(scene)):
		_press_gameplay_action(scene, FLIP_ACTION, "F")
	if _take_input("local-reset", time, time >= 9.0 and not _view_moving(scene)):
		_press_gameplay_action(scene, CAMERA_RESET_ACTION, "Home")


func _run_local_reply(scene: Node, time: float) -> void:
	if time < 10.8 or _done.has("local-black-opened") or _current_turn(scene) != State.BLACK:
		return
	if _take_input(
		"local-black-select",
		time,
		_selected_square(scene) < 0 and not _view_moving(scene)
	):
		_press_gameplay_action(scene, SELECT_ACTION, "Enter")
	if _take_input(
		"local-black-step",
		time,
		time >= 11.25 and _selected_square(scene) >= 0 and _cursor_square(scene) == _square("e7")
	):
		_press_gameplay_action(scene, CURSOR_DOWN_ACTION, "S")
	if _take_input(
		"local-black-commit",
		time,
		time >= 11.6 and _selected_square(scene) >= 0 and _cursor_square(scene) == _square("e6")
	):
		_press_gameplay_action(scene, SELECT_ACTION, "Enter")
		_freeze_scene(scene)
		_done["local-black-opened"] = true


func _take_once(id: String, condition: bool) -> bool:
	if not condition or _done.get(id, false):
		return false
	_done[id] = true
	return true


func _take_input(id: String, time: float, condition: bool, gap: float = 0.28) -> bool:
	if not condition or _done.get(id, false) or time < _next_input_at:
		return false
	_done[id] = true
	_next_input_at = time + gap
	return true


func _round_active(scene: Node) -> bool:
	return bool(scene.get("_round_active"))


func _current_turn(scene: Node) -> int:
	var state := scene.get("_state") as State
	return state.turn if state != null else -1


func _human_turn(scene: Node, side: int) -> bool:
	return (
		_current_turn(scene) == side
		and int(scene.get("_human_side")) == side
		and not _dialog_visible(scene)
	)


func _selected_square(scene: Node) -> int:
	return int(scene.get("_selected"))


func _cursor_square(scene: Node) -> int:
	return int(scene.get("_cursor"))


func _dialog_visible(scene: Node) -> bool:
	var dialog := scene.get("_dialog") as CanvasItem
	return dialog != null and dialog.visible


func _view_moving(scene: Node) -> bool:
	var view := scene.get("_view") as Node
	return bool(view.call("camera_is_moving")) if view != null else false


func _focus_board(scene: Node) -> void:
	var board_input := scene.get("_board_input") as Control
	if board_input != null and not _dialog_visible(scene):
		board_input.grab_focus()


func _press_gameplay_action(scene: Node, action: StringName, label: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	keycap_requested.emit(label)
	scene.call("_handle_gameplay_input", event)


func _hold_camera_action(scene: Node, action: StringName, delta: float) -> void:
	Input.action_press(action)
	scene.call("_update_camera_input", delta)
	Input.action_release(action)


func _freeze_scene(scene: Node) -> void:
	scene.set_process(false)
	scene.set("_cpu_scheduled", false)
	scene.set("_cpu_wait", 0.0)
	var cpu := scene.get("_cpu") as RefCounted
	if cpu != null:
		cpu.call("cancel")


func _install_practice_position(
	scene: Node,
	note: String,
	pieces: Dictionary,
	turn: int,
	top_down: bool,
	home_side: int,
	cursor_square: int,
	ep_square: int = -1
) -> void:
	_freeze_scene(scene)
	scene.call("_cancel_selection")
	for property in ["_moves_made", "_captures_taken", "_promotions"]:
		scene.set(property, [0, 0] as Array[int])
	scene.set("_king_given", [false, false] as Array[bool])
	scene.set("_ledger", PackedStringArray())
	scene.set("_last_move_text", note)
	scene.set("_keyboard_cursor", true)
	scene.set("_cursor", cursor_square)
	var state := scene.get("_state") as State
	if state == null:
		_fail(scene, "Anti-Chess tutorial could not read the live ChessState.")
		return
	if not state.set_position(_board(pieces), turn, ep_square):
		_fail(scene, "Anti-Chess tutorial practice fixture is invalid.")
		return
	scene.set("_legal", state.legal_moves())
	var view := scene.get("_view") as Node
	if view == null:
		_fail(scene, "Anti-Chess tutorial could not read the live BoardView.")
		return
	view.call("configure_camera", top_down, home_side)
	view.call("reset", state, scene.call("_side_colors"))
	scene.call("_sync_match_scores")
	scene.call("_present_position")
	scene.call("_update_scores")
	scene.call("_update_streaks")
	_focus_board(scene)


func _commit_named_move(
	scene: Node,
	from_square: String,
	to_square: String,
	promotion: int = State.EMPTY
) -> void:
	var move := _find_move(scene, from_square, to_square, promotion)
	if move.is_empty():
		_fail(scene, "Missing Anti-Chess tutorial move %s-%s." % [from_square, to_square])
		return
	scene.call("_commit_move", move)


func _find_move(
	scene: Node,
	from_square: String,
	to_square: String,
	promotion: int = State.EMPTY
) -> Dictionary:
	var state := scene.get("_state") as State
	if state == null:
		return {}
	var from_index := _square(from_square)
	var to_index := _square(to_square)
	for move: Dictionary in state.legal_moves():
		if (
			int(move["from"]) == from_index
			and int(move["to"]) == to_index
			and int(move["promotion"]) == promotion
		):
			return move.duplicate(true)
	return {}


func _select_square(scene: Node, name: String) -> void:
	scene.call("_on_square_pressed", _square(name))


func _board(pieces: Dictionary) -> PackedInt32Array:
	var board := PackedInt32Array()
	board.resize(64)
	for square_name: String in pieces:
		board[_square(square_name)] = int(pieces[square_name])
	return board


func _square(name: String) -> int:
	var file := name.unicode_at(0) - 97
	var rank := name.substr(1).to_int() - 1
	return file + rank * 8


func _fail(scene: Node, message: String) -> void:
	printerr(message)
	push_error(message)
	scene.get_tree().quit(1)


## A recording is publishable only if the actual interaction path reached its ending.
func validate_finished(scene: Node) -> bool:
	var required := [
		"solo-opening-frozen", "solo-orbit-drag-keycap", "solo-orbit-arrow-keycap",
		"solo-zoom", "solo-flip", "solo-reset", "solo-king-capture", "solo-king-proof",
		"solo-promotion-choose", "solo-finish-offer", "solo-finish-capture",
	] if _variant == SOLO else [
		"local-white-opened", "local-black-opened",
		"local-pan-drag-keycap", "local-pan-arrow-keycap",
		"local-zoom", "local-flip", "local-reset", "local-finish-offer", "local-finish-capture",
	]
	for event: String in required:
		if not _done.has(event):
			push_error("Anti-Chess tutorial did not demonstrate '%s'." % event)
			return false
	var state := scene.get("_state") as State
	var expected_winner := State.BLACK if _variant == SOLO else State.WHITE
	var expected_reason := "no_pieces" if _variant == SOLO else "no_moves"
	return (
		state.finished and state.winner == expected_winner
		and state.result_reason == expected_reason and not _dialog_visible(scene)
	)
