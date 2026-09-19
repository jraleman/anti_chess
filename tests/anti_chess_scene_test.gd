extends SceneTree

## Real-shell input, CPU turns, match endings, pause/replay races and live options.

const State = preload("res://games/anti_chess/board/chess_state.gd")
const Options = preload("res://games/anti_chess/anti_chess_options.gd")
const ChessCamera = preload("res://games/anti_chess/board/chess_camera.gd")
const GAME := "res://games/anti_chess/gameplay.tscn"
const FIXTURE := "res://games/anti_chess/tests/match_fixture.gd"

var _failures := PackedStringArray()
var _settings: Node
var _session: Node
var _saved_values: Dictionary
var _saved_session: Dictionary
var _saved_game := ""
var _save_mode := Node.PROCESS_MODE_INHERIT


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = get_root().get_node("Settings")
	_session = get_root().get_node("GameSession")
	_saved_values = (_settings.get("_values") as Dictionary).duplicate(true)
	_saved_game = GameCatalog.current_id()
	_saved_session = {
		"game_mode": _session.get("game_mode"),
		"player_two_controller": _session.get("player_two_controller"),
		"cpu_difficulty": _session.get("cpu_difficulty"),
	}
	var save_timer := _settings.get("_save_timer") as Timer
	_save_mode = save_timer.process_mode
	save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	GameCatalog.select(Options.GAME_ID)
	for binding in Options.CONTROL_BINDINGS:
		_settings.call("set_value", binding["key"], binding["default"])
	_settings.call("set_value", Settings.ROUND_MODE_KEY, Settings.RoundMode.LIVES)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	_settings.call("set_value", Options.CPU_DIFFICULTY_KEY, Options.DEFAULT_CPU_DIFFICULTY)
	_settings.call("set_value", Options.SHOW_HINTS_KEY, true)
	_settings.call("set_value", Options.PIECE_LABELS_KEY, true)
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.WHITE)
	_test_legacy_arrow_bindings()
	await _test_local_input_and_viewport()
	await _test_camera_controls()
	await _test_touch_input()
	await _test_cpu_and_pause()
	await _test_black_opening_and_replay()
	await _test_black_outcomes()
	await _test_promotion_and_en_passant()
	await _test_terminal_rules_and_replay()
	await _test_live_settings()
	await _test_resign_and_abandon()
	for binding in Options.CONTROL_BINDINGS:
		var key := str(binding["key"])
		_settings.call("set_value", key, _saved_values.get(key, binding["default"]))
	var values := _settings.get("_values") as Dictionary
	values.clear()
	values.merge(_saved_values, true)
	save_timer.stop()
	save_timer.process_mode = _save_mode
	for key: String in _saved_session:
		_session.set(key, _saved_session[key])
	GameCatalog.select(_saved_game)
	if _failures.is_empty():
		print("Anti-Chess scene tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _new_game(cpu := false) -> Node:
	if cpu:
		_session.call("configure_single_player")
	else:
		_session.call("configure_multiplayer", 0)
	var packed := load(GAME) as PackedScene
	var fixture := load(FIXTURE) as Script
	if packed == null or fixture == null or not fixture.can_instantiate():
		printerr("The Anti-Chess gameplay scene and fixture must compile.")
		quit(1)
		return null
	var game := packed.instantiate()
	game.set_script(fixture)
	get_root().add_child(game)
	game.set_process(false)
	await process_frame
	await process_frame
	return game


func _free_game(game: Node) -> void:
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _action(game: Node, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game.call("_handle_gameplay_input", event)


func _click(game: Node, square: int) -> void:
	var view := game.get("_view") as Node
	var position: Vector3 = view.call("square_position", square)
	var point: Vector2 = view.call("project", position)
	var picked := int((game.get("_board_input") as Control).call("_pick_square", point))
	_expect(picked == square, "Pointer aimed at %s picked %s." % [
		State.square_name(square), State.square_name(picked),
	])
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	(game.get("_board_input") as Control).call("_gui_input", event)


func _position(game: Node, pieces: Dictionary, turn := State.WHITE, ep := -1) -> State:
	var board := PackedInt32Array()
	board.resize(64)
	for square: int in pieces:
		board[square] = int(pieces[square])
	var state: State = game.get("_state")
	_expect(state.set_position(board, turn, ep), "The scene fixture position must be valid.")
	game.set("_legal", state.legal_moves())
	game.set("_selected", -1)
	game.set("_cpu_scheduled", false)
	(game.get("_cpu") as RefCounted).call("cancel")
	var colors: Array[Color] = game.call("_side_colors")
	(game.get("_view") as Node).call("reset", state, colors, game.call("_side_finishes"))
	game.call("_sync_match_scores")
	game.call("_present_position")
	game.call("_update_scores")
	return state


func _test_legacy_arrow_bindings() -> void:
	var values := _settings.get("_values") as Dictionary
	var before := values.duplicate(true)
	var keys := PackedStringArray()
	for binding in Options.CONTROL_BINDINGS:
		keys.append(str(binding["key"]))
	for index in 4:
		_settings.call("set_value", keys[index], [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT][index])
	_expect(bool(_settings.call("_repair_control_values")),
		"The host's scoped conflict repair must recognize a saved arrow-cursor profile.")
	for binding in Options.CONTROL_BINDINGS:
		_expect(values[binding["key"]] == binding["default"],
			"Legacy arrows must migrate to unambiguous WASD/camera defaults.")
	for key: String in before:
		if not keys.has(key):
			_expect(values[key] == before[key], "Binding repair cannot change another setting: " + key)
	_settings.call("apply_controls")


func _hold_camera(game: Node, action: StringName) -> void:
	Input.action_press(action)
	game.call("_update_camera_input", 0.1)
	Input.action_release(action)


func _test_camera_controls() -> void:
	var game := await _new_game()
	var input := game.get("_board_input") as Control
	var view := game.get("_view") as Node
	var camera := view.get("camera") as ChessCamera
	var state: State = game.get("_state")
	var original_board := state.board.duplicate()
	_expect(camera.top_down and camera.basis.z.is_equal_approx(Vector3.UP),
		"Local multiplayer must start exactly overhead, without a degenerate camera basis.")
	_hold_camera(game, Options.CAMERA_UP_ACTION)
	_expect(camera.pan_offset.y < 0.0 and camera.basis.z.is_equal_approx(Vector3.UP),
		"Held camera arrows must pan locally without tilting or moving a chess square.")
	_expect(int(game.get("_cursor")) == 12 and int(game.get("_selected")) == -1,
		"Camera arrows must not navigate or select board squares.")
	var before_pan := camera.pan_offset
	(game.get("_match_panel").get("_resign") as Button).grab_focus()
	_hold_camera(game, Options.CAMERA_RIGHT_ACTION)
	_expect(camera.pan_offset == before_pan, "Arrow-key menu navigation must not move the board.")
	input.grab_focus()
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	input.call("_gui_input", right)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(36, -18)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	input.call("_gui_input", motion)
	right.pressed = false
	input.call("_gui_input", right)
	_expect(camera.pan_offset != before_pan and not bool(input.get("_dragging")),
		"A right drag must pan, and its release must end the gesture.")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	input.call("_gui_input", wheel)
	_expect(camera.zoom_factor > 1.0, "The wheel must zoom over the board.")
	var moved_pan := camera.pan_offset
	var moved_zoom := camera.zoom_factor
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	view.call("resize_view", Vector2(420, 840))
	_expect(camera.pan_offset == moved_pan and camera.zoom_factor == moved_zoom,
		"Resize and reduced motion must preserve user pan and zoom.")
	_hold_camera(game, Options.CAMERA_RIGHT_ACTION)
	_expect(camera.pan_offset != moved_pan,
		"Reduced motion must retain essential user camera controls.")
	game.call("_request_resignation")
	var modal_pose := camera.transform
	game.call("_drag_camera", Vector2(120, 80))
	game.call("_zoom_camera", 1.0)
	_hold_camera(game, Options.CAMERA_RIGHT_ACTION)
	_expect(camera.transform.is_equal_approx(modal_pose) and camera.zoom_factor == moved_zoom,
		"Camera controls must not operate behind a decision dialog.")
	game.call("_cancel_selection")
	view.call("drag_camera", Vector2(1000000, -1000000))
	_expect(absf(camera.pan_offset.x) <= ChessCamera.MAX_PAN
		and absf(camera.pan_offset.y) <= ChessCamera.MAX_PAN,
		"Long drags must not lose the board beyond the bounded pan area.")
	for step in 3:
		view.call("zoom_camera", 1000.0)
	_expect(is_equal_approx(camera.zoom_factor, ChessCamera.MAX_ZOOM), "Zoom in must be bounded.")
	for step in 3:
		view.call("zoom_camera", -1000.0)
	_expect(is_equal_approx(camera.zoom_factor, ChessCamera.MIN_ZOOM), "Zoom out must be bounded.")
	_action(game, Options.CAMERA_RESET_ACTION)
	_expect(camera.pan_offset == Vector2.ZERO and camera.zoom_factor == 1.0
		and camera.basis.z.is_equal_approx(Vector3.UP),
		"Home must restore the full, centred overhead view.")
	_action(game, Options.FLIP_ACTION)
	_expect(camera.basis.z.is_equal_approx(Vector3.UP),
		"Flipping a local board must preserve its overhead lock.")
	_action(game, Options.CAMERA_RESET_ACTION)
	_expect(state.board == original_board and state.ply_count == 0,
		"No camera gesture may mutate the chess position.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	await _free_game(game)


func _test_local_input_and_viewport() -> void:
	var game := await _new_game()
	var state: State = game.get("_state")
	var container := game.get("_board_container") as SubViewportContainer
	var viewport := game.get("_board_viewport") as SubViewport
	_expect(container.stretch and container.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"The renderer must not intercept the parent board's input.")
	_expect(viewport.own_world_3d and viewport.gui_disable_input and viewport.transparent_bg,
		"Chess must live in an isolated, non-interactive 3D SubViewport.")
	_expect((game.get_node("%RoundTimer") as Timer).is_stopped()
		and not bool(game.get("_lives_mode")), "Saved Lives must not time or eliminate chess players.")
	game.call("_lose_life", 0, 100)
	_expect(bool(game.get("_round_active")), "Arcade mistakes must not end an untimed match.")
	_action(game, Options.SELECT_ACTION)
	_expect(int(game.get("_selected")) == 12, "Keyboard selection must start on e2.")
	_action(game, Options.CURSOR_UP_ACTION)
	var selection := game.get("_match_panel").get("_selection") as Label
	_expect(selection.text.contains("Selected e2") and not selection.text.contains("Empty square"),
		"Moving the destination cursor must not rename the selected pawn as an empty square.")
	_action(game, Options.CURSOR_UP_ACTION)
	_action(game, Options.SELECT_ACTION)
	_expect(state.board[28] == State.PAWN and state.turn == State.BLACK,
		"The rebindable keyboard path must play e2-e4.")
	_click(game, 52)
	_click(game, 36)
	_expect(state.board[36] == -State.PAWN and state.turn == State.WHITE,
		"The second local player must use the same board and pointer path.")
	_expect(state.ply_count == 2 and (game.get("_ledger") as PackedStringArray).size() == 1,
		"The ledger must group both players' turns under one move number.")
	var echo := InputEventKey.new()
	echo.physical_keycode = KEY_ENTER
	echo.pressed = true
	echo.echo = true
	game.call("_handle_gameplay_input", echo)
	_expect(int(game.get("_selected")) == -1, "OS key repeats must not select or play again.")
	await _free_game(game)


func _test_cpu_and_pause() -> void:
	var game := await _new_game(true)
	var state: State = game.get("_state")
	_expect(bool(game.get("_cpu_enabled")) and (game.get_node("%PlayerTwoCard") as Control).visible,
		"A single-player entry must seat and show Black's CPU.")
	_click(game, 12)
	_click(game, 28)
	_expect(state.ply_count == 1, "The CPU fixture's human opening must execute (plies %d, selected %d)." % [
		state.ply_count, int(game.get("_selected")),
	])
	_click(game, 52)
	_expect(int(game.get("_selected")) == -1 and state.ply_count == 1,
		"Human input cannot play the CPU's turn.")
	game.call("_update_round", 0.1, 0.0)
	game.set_process(true)
	game.call("open_pause_menu")
	await process_frame
	_expect(paused, "The shared pause overlay must pause the chess scene.")
	await create_timer(0.12).timeout
	_expect(state.ply_count == 1, "CPU computation and its move delay must stop on pause.")
	(game.get("_pause_menu") as Node).call("resume")
	await process_frame
	game.set_process(false)
	for step in 180:
		if state.ply_count != 1:
			break
		game.call("_update_round", 0.05, 0.0)
	_expect(state.ply_count == 2 and state.turn == State.WHITE,
		"The incremental CPU must complete one legal reply, then return control.")
	_expect(not bool(game.get("_cpu_scheduled")), "A completed CPU reply must clear its job.")
	await _free_game(game)


func _test_black_opening_and_replay() -> void:
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.BLACK)
	var game := await _new_game(true)
	var state: State = game.get("_state")
	var view := game.get("_view") as Node
	var camera := view.get("camera") as ChessCamera
	_expect(int(game.get("_human_side")) == State.BLACK
		and int(game.get("_cpu_side")) == State.WHITE and state.turn == State.WHITE,
		"Choosing Black must assign the human to Black without changing White's first move.")
	_expect(not camera.top_down and camera.position.z < 0.0
		and camera.elevation < PI * 0.5 and int(game.get("_cursor")) == 52,
		"Solo Black must face its own army from the front, with its cursor on e7.")
	_expect((game.get("_player_one_caption") as Label).text.contains("BLACK")
		and (game.get("_player_two_caption") as Label).text.contains("CPU / WHITE"),
		"The HUD must label the chosen human seat and the White CPU.")
	game.call("_on_square_pressed", 52)
	_expect(int(game.get("_selected")) == -1 and state.ply_count == 0,
		"The human cannot move before the White CPU opening.")
	var initial_angle := camera.azimuth
	_hold_camera(game, Options.CAMERA_RIGHT_ACTION)
	_expect(not is_equal_approx(camera.azimuth, initial_angle) and state.ply_count == 0,
		"The player must be able to orbit while waiting for the CPU.")
	view.call("drag_camera", Vector2(0, 1000000))
	_expect(is_equal_approx(camera.elevation, ChessCamera.MAX_ELEVATION),
		"Solo orbit must stop before going overhead or upside down.")
	view.call("drag_camera", Vector2(0, -1000000))
	_expect(is_equal_approx(camera.elevation, ChessCamera.MIN_ELEVATION),
		"Solo orbit must keep enough elevation to see the board.")
	camera.azimuth = PI * 0.5
	_expect(view.call("square_direction", Vector2i.UP) == Vector2i.RIGHT,
		"Square directions must rotate by the nearest board axis, not just flip at 180 degrees.")
	game.call("_reset_camera")
	for step in 180:
		if state.ply_count > 0:
			break
		game.call("_update_round", 0.05, 0.0)
	_expect(state.ply_count == 1 and state.turn == State.BLACK
		and bool(game.call("_human_can_move")),
		"The CPU must make exactly one legal White opening, then hand control to Black.")
	_click(game, 52)
	_click(game, 36)
	_expect(state.ply_count == 2 and state.turn == State.WHITE,
		"The chosen Black human must be able to reply through normal board input.")
	var old_white_mesh: Mesh = (view.get("_batches") as Array)[0].mesh
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.WHITE)
	_expect(int(game.get("_human_side")) == State.BLACK and camera.position.z < 0.0,
		"Changing colour in settings must take effect next match, not switch the live players.")
	game.call("_on_play_again_pressed")
	_expect(int(game.get("_human_side")) == State.WHITE and camera.position.z > 0.0
		and (view.get("_batches") as Array)[0].mesh != old_white_mesh,
		"Replay must adopt White's perspective and rebuild the player-colour base rings.")
	_expect((game.call("_side_colors") as Array)[State.WHITE] == game.get("player_one_color"),
		"White must inherit P1's colour when the human changes sides.")
	await _free_game(game)
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.BLACK)
	game = await _new_game()
	_expect(not bool(game.get("_cpu_enabled")) and int(game.get("_human_side")) == State.WHITE
		and bool((game.get("_view").get("camera") as ChessCamera).top_down),
		"Local humans must ignore the saved solo colour and use White P1 / Black P2 overhead.")
	await _free_game(game)
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.WHITE)


func _test_black_outcomes() -> void:
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.BLACK)
	var game := await _new_game(true)
	var state := _position(game, {7: State.ROOK, 16: State.KNIGHT, 15: -State.KING})
	game.set("_moves_made", [3, 7] as Array[int])
	game.set("_captures_taken", [1, 2] as Array[int])
	game.set("_promotions", [2, 4] as Array[int])
	game.call("_commit_move", state.legal_moves()[0])
	game.call("_complete_match")
	var payload: Dictionary = game.call("_share_payload")
	var human: Dictionary = game.call("_player_stats", 0)
	var cpu: Dictionary = game.call("_player_stats", 1)
	_expect(state.winner == State.BLACK and payload["score_values"] == [16, 14]
		and payload["pieces_left"] == [2, 0],
		"Black's human score must come first, while share artwork keeps canonical White/Black counts.")
	_expect(str(payload["score_caption"]) == "BLACK - WHITE GIVEN AWAY"
		and int(human["hits"]) == 7 and int(cpu["hits"]) == 4
		and int(human["streak"]) == 4 and int(cpu["streak"]) == 2,
		"Every result/stat/share label must follow player seats, not assume White is P1.")
	var outcome: Dictionary = game.call("_describe_round_outcome", 16, 14)
	_expect(outcome["color"] == game.get("player_one_color"),
		"A Black human win must use P1's result colour.")
	var achievements: PackedStringArray = game.get("observed_achievements")
	_expect(achievements.has("anti_chess_giveaway") and achievements.has("anti_chess_outsmarted")
		and achievements.has("anti_chess_royal_exit"),
		"Black humans must earn giveaway, CPU-win and king-giveaway achievements.")
	game.call("_on_play_again_pressed")
	state = _position(game, {0: State.KING, 8: -State.ROOK, 63: -State.KNIGHT}, State.BLACK)
	game.call("_commit_move", state.legal_moves()[0])
	game.call("_complete_match")
	outcome = game.call("_describe_round_outcome", 14, 16)
	_expect(state.winner == State.WHITE and str(outcome["result"]).contains("CPU (WHITE)")
		and outcome["color"] == game.get("player_two_color")
		and game.get("observed_achievements") == PackedStringArray(["anti_chess_first_match"]),
		"A White CPU win or lost king cannot award the Black human's achievements.")
	game.call("_on_play_again_pressed")
	game.call("_request_resignation")
	_expect(int(game.get("_resigning_side")) == State.BLACK,
		"Solo resignation must target the chosen human, even during the CPU's opening turn.")
	(game.get("_dialog") as Control).call("_confirm_resignation")
	_expect((game.get("_state") as State).winner == State.WHITE,
		"A Black resignation must award White's CPU.")
	await _free_game(game)
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.WHITE)


func _test_touch_input() -> void:
	var game := await _new_game()
	var input := game.get("_board_input") as Control
	var view := game.get("_view") as Node
	var at: Vector3 = view.call("square_position", 12)
	var point: Vector2 = view.call("project", at)
	var emulated := InputEventMouseButton.new()
	emulated.position = point
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	input.call("_gui_input", emulated)
	_expect(int(game.get("_selected")) == -1,
		"A touch-generated mouse event must not duplicate a tap.")
	for square in [12, 28]:
		at = view.call("square_position", square)
		var touch := InputEventScreenTouch.new()
		touch.position = view.call("project", at)
		touch.pressed = true
		input.call("_gui_input", touch)
		touch.pressed = false
		input.call("_gui_input", touch)
	var state: State = game.get("_state")
	_expect(state.ply_count == 1 and state.board[28] == State.PAWN,
		"Two taps must select and move once, without requiring a mouse.")
	await _free_game(game)


func _test_promotion_and_en_passant() -> void:
	var game := await _new_game()
	var state := _position(game, {48: State.PAWN, 63: -State.ROOK})
	_click(game, 48)
	_click(game, 56)
	var dialog := game.get("_dialog") as Control
	_expect(dialog.visible and state.board[48] == State.PAWN and state.ply_count == 0,
		"Promotion must wait for an explicit choice without moving the pawn early.")
	_expect((dialog.get("_choices") as GridContainer).get_child_count() == 5,
		"Promotion must offer Queen, Rook, Bishop, Knight and King.")
	game.call("_cancel_selection")
	_expect(not dialog.visible and state.ply_count == 0, "Cancelling promotion leaves the board intact.")
	_click(game, 48)
	_click(game, 56)
	dialog.call("_choose", State.KING)
	_expect(state.board[56] == State.KING and state.turn == State.BLACK,
		"The chooser must commit the chosen king promotion, not default to a queen.")
	state = _position(game, {0: State.KING, 36: State.PAWN,
		51: -State.PAWN, 63: -State.KING}, State.BLACK)
	_click(game, 51)
	_click(game, 35)
	_expect(bool(game.call("_capture_required")), "An available en passant must be compulsory.")
	_click(game, 36)
	_click(game, 43)
	_expect(state.board[35] == State.EMPTY and state.board[43] == State.PAWN,
		"Pointer input must remove the bypassed pawn during en passant.")
	_expect(str(game.get("_last_move_text")).contains("e.p."),
		"The ledger must explain why an en-passant capture removed another square.")
	await _free_game(game)


func _test_terminal_rules_and_replay() -> void:
	var game := await _new_game(true)
	var state := _position(game, {0: State.KING, 8: -State.ROOK, 63: -State.KNIGHT}, State.BLACK)
	game.call("_commit_move", state.legal_moves()[0])
	_expect(state.finished and state.winner == State.WHITE, "Giving away the last king must win.")
	_expect(bool(game.get("_completion_pending")), "Results must wait for the final piece to settle.")
	game.call("open_pause_menu")
	await create_timer(0.15).timeout
	_expect(not (game.get_node("%RoundOver") as Control).visible,
		"The pausable completion hold cannot finish under the pause overlay.")
	(game.get("_pause_menu") as Node).call("resume")
	await create_timer(0.45).timeout
	_expect((game.get_node("%RoundOver") as Control).visible
		and str((game.get_node("%ResultLabel") as Label).text).contains("WHITE"),
		"A terminal position must reach the shared results with the model's winner.")
	var achievements: PackedStringArray = game.get("observed_achievements")
	_expect(achievements.has("anti_chess_first_match")
		and achievements.has("anti_chess_giveaway")
		and achievements.has("anti_chess_outsmarted")
		and achievements.has("anti_chess_royal_exit"),
		"Completed human giveaway wins must award the game-native achievements.")
	var payload: Dictionary = game.call("_share_payload")
	_expect(payload["pieces_left"] == [0, 2] and int(payload["ply_count"]) == 1,
		"Share data must carry both sides' remaining pieces and the same move count.")
	_expect(payload["score_values"] == [16, 14] and str(payload["score"]) == "16 - 14",
		"A solo CPU match must share both sides' scores, just like its results panel.")
	game.call("_end_round")
	_expect((game.get("observed_achievements") as PackedStringArray).size() == achievements.size(),
		"Completion must be idempotent.")
	game.call("_on_play_again_pressed")
	state = game.get("_state")
	_expect(state.ply_count == 0 and state.piece_count(0) == 16
		and not bool(game.get("_completion_pending")), "Replay must clear the board, ledger and pending end.")
	state = _position(game, {8: State.PAWN, 24: -State.PAWN}, State.BLACK)
	game.call("_commit_move", state.legal_moves()[0])
	_expect(state.finished and state.winner == State.WHITE and state.result_reason == "no_moves",
		"No legal moves is a win even when both sides have the same material.")
	game.call("_on_play_again_pressed")
	await create_timer(0.45).timeout
	_expect(bool(game.get("_round_active")) and not (game.get_node("%RoundOver") as Control).visible,
		"A previous match's delayed completion must not end the replay.")
	await _free_game(game)


func _test_live_settings() -> void:
	var game := await _new_game()
	_settings.call("set_value", Options.SHOW_HINTS_KEY, false)
	_settings.call("set_value", Options.PIECE_LABELS_KEY, false)
	_expect(not bool((game.get("_board_input") as Control).get("_hints"))
		and not bool((game.get("_board_input") as Control).get("_piece_labels")),
		"Legal-move and piece-letter options must update the live board.")
	var old_difficulty := int(game.get("_difficulty"))
	_settings.call("set_value", Options.CPU_DIFFICULTY_KEY, 2)
	_expect(int(game.get("_difficulty")) == old_difficulty,
		"CPU difficulty must remain fixed until the next match.")
	var up_key := str(Options.CONTROL_BINDINGS[0]["key"])
	_settings.call("set_binding_key", up_key, KEY_Q, Options.GAME_ID)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.pressed = true
	game.call("_handle_gameplay_input", event)
	_expect(int(game.get("_cursor")) == 20, "A rebound physical key must move the cursor immediately.")
	var panel := game.get("_match_panel") as Control
	_expect((panel.get("_keys") as Label).text.contains("Q"), "The live key hint must reflect a rebind.")
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	game.call("_flip_board")
	var view := game.get("_view") as Node
	_expect(bool(view.get("flipped")) and not bool(view.call("camera_is_moving")),
		"Reduced motion must make a manual camera flip instant.")
	game.call("_on_play_again_pressed")
	_expect(int(game.get("_difficulty")) == 2 and not bool(view.get("flipped")),
		"A replay must adopt new options and restore White's board orientation.")
	_settings.call("set_value", up_key, KEY_W)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, false)
	await _free_game(game)


func _test_resign_and_abandon() -> void:
	var game := await _new_game(true)
	var state: State = game.get("_state")
	game.call("_request_resignation")
	_expect((game.get("_dialog") as Control).visible and not state.finished,
		"Resign must ask for confirmation before awarding the match.")
	game.call("_cancel_selection")
	_expect(not state.finished, "Keeping playing must leave the match intact.")
	game.call("_request_resignation")
	(game.get("_dialog") as Control).call("_confirm_resignation")
	_expect(state.finished and state.winner == State.BLACK and state.result_reason == "resignation",
		"Confirmed solo resignation must award Black, never count as giving away pieces.")
	await create_timer(0.45).timeout
	var achievements: PackedStringArray = game.get("observed_achievements")
	_expect(achievements == PackedStringArray(["anti_chess_first_match"]),
		"A resigned match cannot earn a giveaway or CPU-win achievement.")
	game.call("_on_play_again_pressed")
	game.call("_abandon_match")
	game.call("_complete_match")
	_expect(not bool(game.get("_round_active"))
		and (game.get("observed_achievements") as PackedStringArray).is_empty(),
		"Abandoning a live match must cancel CPU and completion without awarding results.")
	await _free_game(game)
