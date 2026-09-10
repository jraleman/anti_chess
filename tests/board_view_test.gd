extends SceneTree

## Real Compatibility-renderer coverage for framing, picking, modal UI and branding.

const State = preload("res://games/anti_chess/board/chess_state.gd")
const Options = preload("res://games/anti_chess/anti_chess_options.gd")
const GAME := "res://games/anti_chess/gameplay.tscn"
const FIXTURE := "res://games/anti_chess/tests/match_fixture.gd"

var _failures := PackedStringArray()
var _capture_dir := ""
var _game: Node
var _peak_draw_calls := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("board_view_test requires a graphics window, not --headless.")
		quit(1)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--anti-chess-capture-dir="):
			_capture_dir = argument.trim_prefix("--anti-chess-capture-dir=")
	if not _capture_dir.is_empty():
		if DirAccess.make_dir_recursive_absolute(_capture_dir) != OK:
			printerr("Could not create the requested Anti-Chess capture directory.")
			quit(1)
			return
	var settings := get_root().get_node("Settings")
	var original_values := (settings.get("_values") as Dictionary).duplicate(true)
	var timer := settings.get("_save_timer") as Timer
	var timer_mode := timer.process_mode
	timer.process_mode = Node.PROCESS_MODE_DISABLED
	var original_game := GameCatalog.current_id()
	var original_size := get_root().size
	var original_theme := get_root().theme
	settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	settings.call("set_value", "ui/scale", 1.0)
	settings.call("set_value", Options.SHOW_HINTS_KEY, true)
	settings.call("set_value", Options.PIECE_LABELS_KEY, true)
	get_root().get_node("GameSession").call("configure_multiplayer", 0)
	GameCatalog.select(Options.GAME_ID)
	get_root().theme = GameCatalog.theme().restyle(ThemeDB.get_project_theme())
	_game = (load(GAME) as PackedScene).instantiate()
	_game.set_script(load(FIXTURE) as Script)
	get_root().add_child(_game)
	_game.set_process(false)
	for size in [Vector2i(1280, 720), Vector2i(390, 844), Vector2i(1920, 800)]:
		(_game.get_node("%PauseButton") as Control).visible = size.y > size.x
		get_root().size = size
		await _render_frames()
		_test_board_geometry()
		_test_panel_bounds()
		await _capture("board-%dx%d" % [size.x, size.y])
	var view := _game.get("_view") as Node
	_game.call("_flip_board")
	await _render_frames()
	_test_board_geometry()
	_game.call("_flip_board")
	get_root().size = Vector2i(1280, 720)
	await _render_frames()
	for side in [State.WHITE, State.BLACK]:
		settings.call("set_value", Options.PLAYER_SIDE_KEY, side)
		get_root().get_node("GameSession").call("configure_single_player")
		_game.call("_on_play_again_pressed")
		await _render_frames()
		_test_board_geometry()
		_test_panel_bounds()
		await _capture("solo-white" if side == State.WHITE else "solo-black")
		view.call("drag_camera", Vector2(80, 12))
		view.call("zoom_camera", 1.0)
		await _render_frames()
		_test_board_geometry()
		await _capture("solo-white-orbit" if side == State.WHITE else "solo-black-orbit")
	get_root().get_node("GameSession").call("configure_multiplayer", 0)
	_game.call("_on_play_again_pressed")
	view.call("move_camera", Vector2(1, -1), 0.1)
	view.call("zoom_camera", 2.0)
	await _render_frames()
	var camera := view.get("camera") as Camera3D
	_expect(camera.basis.z.is_equal_approx(Vector3.UP),
		"Panning and zooming must keep a real overhead local view.")
	_test_board_geometry()
	await _capture("local-panned")
	view.call("reset_camera")
	await _render_frames()
	_play(12, 28)
	_play(51, 35)
	_game.call("_on_square_pressed", 28)
	await _render_frames()
	await _capture("mandatory-capture")
	_position({48: State.PAWN, 63: -State.ROOK}, State.WHITE)
	_game.call("_on_square_pressed", 48)
	_game.call("_on_square_pressed", 56)
	await _render_frames()
	await _capture("promotion")
	get_root().size = Vector2i(390, 844)
	await _render_frames()
	var decision := _game.get("_dialog") as Control
	var decision_panel := decision.get("_panel") as Control
	_expect(Rect2(Vector2.ZERO, decision.size).encloses(decision_panel.get_rect()),
		"The five promotion choices must fit a portrait screen.")
	await _capture("promotion-portrait")
	settings.call("set_value", "ui/scale", 1.5)
	await _render_frames()
	_expect(Rect2(Vector2.ZERO, decision.size).encloses(decision_panel.get_rect()),
		"Promotion must remain on-screen at the largest interface-size setting.")
	_test_panel_bounds()
	await _capture("promotion-large-ui")
	settings.call("set_value", "ui/scale", 1.0)
	get_root().size = Vector2i(1280, 720)
	await _render_frames()
	_game.call("_cancel_selection")
	_position({0: State.KING, 8: -State.ROOK, 63: -State.KNIGHT}, State.BLACK)
	_play(8, 0)
	_game.call("_complete_match")
	await _render_frames()
	await _capture("results")
	_game.call("_on_see_score_pressed")
	for frame in 12:
		await process_frame
	_expect((_game.get_node("%ShareCardPreview") as TextureRect).texture != null,
		"The shared score screen must render this game's themed, two-sided scorecard.")
	await _capture("scorecard")
	_expect(_peak_draw_calls > 0 and _peak_draw_calls <= 100,
		"The full chess world must use 1-100 draw calls including shadows, got %d." % _peak_draw_calls)
	_expect(view.get("camera") is Camera3D, "The world must use a real Camera3D.")
	print("Anti-Chess peak 3D draw calls including shadows: %d" % _peak_draw_calls)
	_game.queue_free()
	await process_frame
	GameCatalog.restrict_to(Options.GAME_ID)
	get_root().theme = GameCatalog.theme().restyle(ThemeDB.get_project_theme())
	await _test_setup_views(settings)
	var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	await _render_frames()
	await _capture("standalone-title")
	menu.queue_free()
	await process_frame
	get_root().theme = original_theme
	get_root().size = original_size
	var values := settings.get("_values") as Dictionary
	values.clear()
	values.merge(original_values, true)
	timer.stop()
	timer.process_mode = timer_mode
	GameCatalog.clear_restriction()
	GameCatalog.select(original_game)
	# The shared SFX pool outlives gameplay; let the final short cue mix out.
	await create_timer(0.85).timeout
	if _failures.is_empty():
		print("Anti-Chess rendered view tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _render_frames() -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw


func _test_setup_views(settings: Node) -> void:
	var menu := (load("res://scenes/menus/mode_select.tscn") as PackedScene).instantiate()
	get_root().add_child(menu)
	menu.call("_on_single_player_pressed")
	for size in [Vector2i(1280, 720), Vector2i(390, 844)]:
		get_root().size = size
		await _render_frames()
		var choices := menu.get_node("%SoloSetupChoices") as Control
		var screen := get_root().get_visible_rect()
		_expect(choices.is_visible_in_tree() and screen.encloses(choices.get_global_rect()),
			"The solo colour choice must fit the actual screen in both orientations.")
		for option: Dictionary in menu.get("_solo_setup_options"):
			for button: Button in option["buttons"]:
				var pixel_scale := float(get_root().size.x) / screen.size.x
				_expect(button.get_theme_font_size("font_size") * pixel_scale >= 18.0
					and button.size.y * pixel_scale >= 43.0,
					"Solo colour choices must be readable, finger-sized controls, not just contained.")
		await _capture("solo-setup-%dx%d" % [size.x, size.y])
	settings.call("set_value", "ui/scale", 1.5)
	await _render_frames()
	var choice_box := menu.get_node("%SoloSetupChoices") as Control
	var screen := get_root().get_visible_rect()
	_expect(screen.encloses(choice_box.get_global_rect()),
		"The complete colour choice must remain on-screen at maximum interface scale.")
	for option: Dictionary in menu.get("_solo_setup_options"):
		for button: Button in option["buttons"]:
			var pixel_scale := float(get_root().size.x) / screen.size.x
			_expect(button.get_theme_font_size("font_size") * pixel_scale >= 18.0,
				"Maximum interface size must not shrink the actual colour-button text.")
			var scroll := choice_box.get_parent().get_parent() as ScrollContainer
			_expect(scroll.get_global_rect().grow(1.0).encloses(button.get_global_rect()),
				"The colour buttons must actually be visible inside the scroll viewport.")
	for button_name in ["%PreviousButton", "%ConfirmButton"]:
		_expect(screen.encloses((menu.get_node(button_name) as Control).get_global_rect()),
			"Setup actions must fit at maximum interface scale.")
	await _capture("solo-setup-large-ui")
	menu.call("_on_multiplayer_pressed")
	await _render_frames()
	_expect(not (menu.get_node("%SoloSetupChoices") as Control).visible
		and not (menu.get_node("%OpponentSelector") as Control).visible,
		"Local setup must not display colour or CPU choices.")
	await _capture("local-setup-portrait")
	menu.queue_free()
	await process_frame
	settings.call("set_value", "ui/scale", 1.0)
	get_root().size = Vector2i(1280, 720)
	await _render_frames()


func _test_board_geometry() -> void:
	var view := _game.get("_view") as Node
	var input := _game.get("_board_input") as Control
	var frame := Rect2(Vector2.ZERO, input.size)
	for square in 64:
		var point: Vector3 = view.call("square_position", square)
		var projected: Vector2 = view.call("project", point)
		_expect(frame.has_point(projected),
			"Square %s must fit the board at %s." % [State.square_name(square), input.size])
		_expect(int(view.call("square_at", projected)) == square,
			"Projected square %s must pick itself, including after flipping." % State.square_name(square))
		var state: State = _game.get("_state")
		if state.board[square] != State.EMPTY:
			var crown: Vector2 = view.call("project", point + Vector3.UP * 0.75)
			_expect(int(view.call("piece_at", crown)) == square,
				"Clicking a piece's body must select it rather than the tile behind it.")
	var count := 0
	for batch: MultiMesh in view.get("_batches"):
		count += batch.visible_instance_count
	_expect(count == 32, "The initial board must render all 32 original chessmen.")
	var viewport := _game.get("_board_viewport") as SubViewport
	var calls := viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
	)
	calls += viewport.get_render_info(
		Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME
	)
	_peak_draw_calls = maxi(_peak_draw_calls, calls)


func _test_panel_bounds() -> void:
	var panel := _game.get("_match_panel") as Control
	var bounds: Rect2 = _game.call("_playfield_bounds")
	var top_bar := (_game.get_node("%PlayerOneCard") as Control).get_parent() as Control
	var screen := get_root().get_visible_rect()
	_expect(screen.grow(1.0).encloses(top_bar.get_global_rect()),
		"The turn header, both players and touch pause must fit on-screen.")
	_expect(bounds.grow(1.0).encloses(panel.get_rect()),
		"The move ledger and action buttons must fit within the HUD-safe playfield.")
	var board := _game.get("_board_input") as Control
	_expect(not board.get_rect().intersects(panel.get_rect()),
		"The information panel must never cover a playable square.")
	for property in ["_resign", "_flip", "_reset_camera"]:
		var action := panel.get(property) as Control
		_expect(panel.get_global_rect().grow(1.0).encloses(action.get_global_rect()),
			"Every board action must remain visible while the ledger content scrolls: " + property)
	_expect(absf(panel.get_rect().end.y - bounds.end.y) < 2.0,
		"The ledger must reach the current playfield bottom after the HUD reflows.")
	if get_root().size.y > get_root().size.x:
		_expect(board.size.y >= minf(bounds.size.y * 0.55, bounds.size.x),
			"A portrait board must use the available width, not retain a stale short layout.")


func _play(source: int, target: int) -> void:
	var state: State = _game.get("_state")
	for move in state.legal_moves():
		if int(move["from"]) == source and int(move["to"]) == target:
			_game.call("_commit_move", move)
			return
	_expect(false, "The rendered walkthrough requested an illegal move.")


func _position(pieces: Dictionary, turn: int) -> void:
	var state: State = _game.get("_state")
	var board := PackedInt32Array()
	board.resize(64)
	for square: int in pieces:
		board[square] = pieces[square]
	_expect(state.set_position(board, turn), "The rendered fixture position must be legal input.")
	_game.set("_legal", state.legal_moves())
	_game.set("_selected", -1)
	var colors: Array[Color] = _game.call("_side_colors")
	(_game.get("_view") as Node).call("reset", state, colors)
	_game.call("_sync_match_scores")
	_game.call("_present_position")


func _capture(name: String) -> void:
	if _capture_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	_expect(image != null and not image.is_empty(), "The graphics window must produce a frame.")
	if image != null and not image.is_empty():
		_expect(image.save_png(_capture_dir.path_join(name + ".png")) == OK,
			"Requested screenshot '%s' must save." % name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
