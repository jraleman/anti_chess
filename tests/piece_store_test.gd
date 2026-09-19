extends SceneTree

## Real Store persistence plus chess-specific seat, replay and winner-based payout rules.

const Options = preload("res://games/anti_chess/anti_chess_options.gd")
const State = preload("res://games/anti_chess/board/chess_state.gd")
const GAME := "res://games/anti_chess/gameplay.tscn"
const FIXTURE := "res://games/anti_chess/tests/match_fixture.gd"

var _failures := PackedStringArray()
var _store: Node
var _settings: Node
var _session: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_store = get_root().get_node("Store")
	_settings = get_root().get_node("Settings")
	_session = get_root().get_node("GameSession")
	var had_save := FileAccess.file_exists(Store.SAVE_PATH)
	var saved_bytes := FileAccess.get_file_as_bytes(Store.SAVE_PATH) if had_save else PackedByteArray()
	var saved_store := {}
	for key in ["_points", "_owned", "_equipped"]:
		saved_store[key] = (_store.get(key) as Dictionary).duplicate(true)
	var saved_values := (_settings.get("_values") as Dictionary).duplicate(true)
	var timer := _settings.get("_save_timer") as Timer
	var timer_mode := timer.process_mode
	timer.process_mode = Node.PROCESS_MODE_DISABLED
	var saved_session := {}
	for key in ["game_mode", "player_two_controller", "cpu_difficulty",
		"_controllers_assigned", "_gamepad_available", "_controller_devices"]:
		var value: Variant = _session.get(key)
		saved_session[key] = value.duplicate() if value is Array else value
	var saved_game := GameCatalog.current_id()
	GameCatalog.select(Options.GAME_ID)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.WHITE)
	(_store.get("_points") as Dictionary)[Options.GAME_ID] = 0
	(_store.get("_owned") as Dictionary)[Options.GAME_ID] = {}
	(_store.get("_equipped") as Dictionary)[Options.GAME_ID] = {}
	_store.call("register_game", GameCatalog.current())
	_test_catalog_and_purchases()
	await _test_seats_and_payouts()
	await _test_store_screen()
	for key: String in saved_store:
		_store.set(key, saved_store[key])
	if had_save:
		var file := FileAccess.open(Store.SAVE_PATH, FileAccess.WRITE)
		_expect(file != null, "The original store save must be restorable.")
		if file != null:
			file.store_buffer(saved_bytes)
			file.close()
	else:
		_expect(DirAccess.remove_absolute(Store.SAVE_PATH) == OK,
			"The test-created store save must be removed.")
	_settings.set("_values", saved_values)
	timer.stop()
	timer.process_mode = timer_mode
	for key: String in saved_session:
		_session.set(key, saved_session[key])
	GameCatalog.select(saved_game)
	await create_timer(0.3).timeout
	if _failures.is_empty():
		print("Anti-Chess piece store tests passed.")
		quit(0)
	else:
		for failure in _failures:
			printerr(failure)
		quit(1)


func _test_catalog_and_purchases() -> void:
	_expect(GameCatalog.current().has_store(), "The manifest must enable the scaffold store.")
	_expect((_store.call("slots", Options.GAME_ID) as Array).size() == 2,
		"Each player must have an independent finish slot.")
	for item in Options.STORE_ITEMS:
		var id := str(item["id"])
		var owned := bool(_store.call("is_owned", Options.GAME_ID, id))
		_expect(owned == bool(item.get("default", false)),
			"Only starter colours should be owned initially: " + id)
		if not owned:
			_expect(not bool(_store.call("equip", Options.GAME_ID, id, Options.FINISH_SLOTS[0])),
				"An unpurchased finish must not be equipable: " + id)
	_expect(not bool(_store.call("purchase", Options.GAME_ID, Options.FINISH_BRONZE)),
		"An empty wallet cannot buy bronze.")
	_store.call("add_points", Options.GAME_ID, 59)
	_expect(not bool(_store.call("purchase", Options.GAME_ID, Options.FINISH_BRONZE)),
		"Bronze must cost exactly 60 Coins, not 59.")
	_store.call("add_points", Options.GAME_ID, 1)
	_expect(bool(_store.call("purchase", Options.GAME_ID, Options.FINISH_BRONZE))
		and int(_store.call("points", Options.GAME_ID)) == 0,
		"Buying bronze must deduct exactly its price.")
	_store.call("add_points", Options.GAME_ID, 2000)
	for id in [Options.FINISH_SILVER, Options.FINISH_GOLD,
		Options.FINISH_PLATINUM, Options.FINISH_DIAMOND]:
		_expect(bool(_store.call("purchase", Options.GAME_ID, id)),
			"Every advertised precious finish must be purchasable: " + id)
	_equip(Options.FINISH_BRONZE, 0)
	_equip(Options.FINISH_SILVER, 1)
	var balance := int(_store.call("points", Options.GAME_ID))
	_store.call("purchase", Options.GAME_ID, Options.FINISH_GOLD)
	_expect(int(_store.call("points", Options.GAME_ID)) == balance,
		"Buying an already-owned finish must never charge twice.")
	(_store.get("_points") as Dictionary)[Options.GAME_ID] = 0
	(_store.get("_owned") as Dictionary)[Options.GAME_ID] = {}
	(_store.get("_equipped") as Dictionary)[Options.GAME_ID] = {}
	_store.call("register_game", GameCatalog.current())
	_store.call("_load_state")
	_expect(int(_store.call("points", Options.GAME_ID)) == balance,
		"The wallet must survive a Store reload.")
	for id in [Options.FINISH_BRONZE, Options.FINISH_SILVER, Options.FINISH_GOLD,
		Options.FINISH_PLATINUM, Options.FINISH_DIAMOND]:
		_expect(bool(_store.call("is_owned", Options.GAME_ID, id)),
			"Purchased finishes must survive a Store reload: " + id)
	_expect(str(_store.call("equipped_id", Options.GAME_ID, Options.FINISH_SLOTS[0]))
		== Options.FINISH_BRONZE
		and str(_store.call("equipped_id", Options.GAME_ID, Options.FINISH_SLOTS[1]))
		== Options.FINISH_SILVER, "Both equipped slots must persist independently.")


func _test_seats_and_payouts() -> void:
	_session.call("configure_multiplayer", 0)
	var game := (load(GAME) as PackedScene).instantiate()
	game.set_script(load(FIXTURE))
	get_root().add_child(game)
	game.set_process(false)
	await process_frame
	var view := game.get("_view") as Node
	_expect(game.call("_side_finishes") == [Options.FINISH_BRONZE, Options.FINISH_SILVER],
		"Local P1 must dress White and local P2 must dress Black.")
	_expect(view.get("_piece_finishes") == game.call("_side_finishes"),
		"Selected finishes must reach the real board meshes.")
	var batches: Array = view.get("_batches")
	var old_mesh := (batches[0] as MultiMesh).mesh
	_expect(is_equal_approx(
		(old_mesh.surface_get_material(0) as StandardMaterial3D).metallic, 0.65),
		"The real board must use bronze's metallic material.")
	_equip(Options.FINISH_GOLD, 0)
	_expect((batches[0] as MultiMesh).mesh == old_mesh
		and (game.call("_side_finishes") as Array)[State.WHITE] == Options.FINISH_BRONZE,
		"Shopping while paused must not change the current match's pieces.")
	game.call("_on_play_again_pressed")
	_expect(view.get("_piece_finishes") == [Options.FINISH_GOLD, Options.FINISH_SILVER]
		and (batches[0] as MultiMesh).mesh != old_mesh,
		"Replay must rebuild cached meshes for newly equipped finishes.")
	var reused_mesh := (batches[0] as MultiMesh).mesh
	game.call("_on_play_again_pressed")
	_expect((batches[0] as MultiMesh).mesh == reused_mesh,
		"An unchanged finish must reuse meshes on replay.")
	_test_promotions_and_trays(game)
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, State.BLACK)
	_session.call("configure_single_player")
	game.call("_on_play_again_pressed")
	_expect(view.get("_piece_finishes") == [Options.FINISH_SILVER, Options.FINISH_GOLD],
		"A Black human must keep P1's finish, with P2's finish on the White CPU.")
	var state: State = game.get("_state")
	_expect(int(game.call("_round_points_earned", 12, 8)) == 0,
		"An unfinished or abandoned position cannot pay coins.")
	state.finished = true
	state.winner = State.BLACK
	state.result_reason = "no_moves"
	_expect(int(game.call("_round_points_earned", 3, 12)) == 31,
		"A blocked human win must pay 10 + 6 + 15, despite the CPU's higher score.")
	_expect(int(game.call("_round_points_earned", 16, 0)) == 57,
		"Giving away the full set and beating the CPU must pay exactly 57 Coins.")
	state.winner = State.WHITE
	state.result_reason = "resignation"
	_expect(int(game.call("_round_points_earned", 3, 12)) == 16,
		"Resigning must pay completion and human giveaways, never the CPU-win bonus.")
	state.winner = -1
	_expect(int(game.call("_round_points_earned", 4, 12)) == 18,
		"A draw must pay completion and human giveaways without a win bonus.")
	_session.call("configure_multiplayer", 0)
	game.call("_on_play_again_pressed")
	state = game.get("_state")
	state.finished = true
	state.winner = State.BLACK
	state.result_reason = "no_moves"
	_expect(int(game.call("_round_points_earned", 3, 12)) == 34,
		"Local play must reward the higher giveaway score, without a CPU-win bonus.")
	var scores: Array[int] = [3, 12]
	game.set("_scores", scores)
	game.set("bank_store_rewards", true)
	var balance := int(_store.call("points", Options.GAME_ID))
	game.call("_end_round")
	game.call("_end_round")
	_expect(int(game.get("observed_coins")) == 34
		and int(_store.call("points", Options.GAME_ID)) == balance + 34,
		"The shell completion path must pay a completed match exactly once.")
	_expect((game.get_node("%RoundHighlight") as Label).text.contains("+34 Coins earned"),
		"The real shell must report the coins it banked on the results screen.")
	game.call("_on_play_again_pressed")
	game.call("_abandon_match")
	game.call("_complete_match")
	_expect(int(game.get("observed_coins")) == 0
		and int(_store.call("points", Options.GAME_ID)) == balance + 34,
		"Abandoning must not bank a completion bonus.")
	game.queue_free()
	await process_frame


func _test_promotions_and_trays(game: Node) -> void:
	var board := PackedInt32Array()
	board.resize(64)
	board[49] = State.PAWN
	board[56] = -State.ROOK
	board[63] = -State.KNIGHT
	var state: State = game.get("_state")
	_expect(state.set_position(board, State.WHITE), "The promotion fixture must be valid.")
	var view := game.get("_view") as Node
	var colors: Array[Color] = game.call("_side_colors")
	var finishes: Array[String] = game.call("_side_finishes")
	view.call("reset", state, colors, finishes)
	var promoted := false
	for move in state.legal_moves():
		if int(move["to"]) == 56 and int(move["promotion"]) == State.QUEEN:
			game.call("_commit_move", move)
			promoted = true
			break
	_expect(promoted and state.board[56] == State.QUEEN,
		"The real move path must promote while capturing the opposing rook.")
	var batches: Array = view.get("_batches")
	var queen := batches[State.QUEEN - 1] as MultiMesh
	var rook := batches[6 + State.ROOK - 1] as MultiMesh
	_expect(queen.visible_instance_count == 1
		and is_equal_approx((queen.mesh.surface_get_material(0) as StandardMaterial3D).metallic, 0.78),
		"A promoted queen must inherit the player's gold finish.")
	var retired := false
	for piece: Dictionary in view.get("_pieces"):
		if int(piece["square"]) == -1 and int(piece["type"]) == State.ROOK:
			retired = is_equal_approx(float(piece["scale"]), 0.42)
	_expect(retired and rook.visible_instance_count == 1
		and is_equal_approx((rook.mesh.surface_get_material(0) as StandardMaterial3D).metallic, 0.75),
		"The captured rook must keep its silver finish in the opponent's tray.")


func _test_store_screen() -> void:
	var screen := (load("res://scenes/menus/store.tscn") as PackedScene).instantiate()
	screen.set("game_context_id", Options.GAME_ID)
	get_root().add_child(screen)
	await process_frame
	_expect((screen.get("_cards") as Array).size() == Options.STORE_ITEMS.size(),
		"The shared Store screen must render the whole chess catalogue.")
	_expect((screen.get_node("%Intro") as Label).text.contains("next match"),
		"The shelf must explain when equipping takes effect.")
	screen.queue_free()
	await process_frame


func _equip(id: String, player: int) -> void:
	_store.call("equip", Options.GAME_ID, id, Options.FINISH_SLOTS[player])
	_expect(str(_store.call("equipped_id", Options.GAME_ID, Options.FINISH_SLOTS[player])) == id,
		"An owned finish must be wearable by either player: " + id)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
