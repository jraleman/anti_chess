extends SceneTree

## Pure, deterministic CPU regressions, including adversarial tactics and
## operation-count bounds rather than machine-dependent timing assertions.

const ChessState = preload("res://games/anti_chess/board/chess_state.gd")
const CpuPlayer = preload("res://games/anti_chess/board/cpu_player.gd")

var _failures := PackedStringArray()
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_legality_and_determinism()
	_test_forced_choices_and_promotions()
	_test_winning_sacrifices()
	_test_adversarial_reply()
	_test_incremental_bounds()
	_test_completed_depth_survives_cutoff()
	_test_snapshots_and_cancellation()
	_test_terminal_states()
	if _failures.is_empty():
		print("Anti-chess CPU tests passed (%d checks)." % _checks)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_legality_and_determinism() -> void:
	var state := ChessState.new()
	var original := _snapshot(state)
	var legal := state.legal_moves()
	for level in range(3):
		for seed_value: int in [1, 17]:
			var synchronous := CpuPlayer.new(level, seed_value)
			var first := synchronous.choose_move(state)
			_expect(synchronous.completed, "Synchronous choice must finish at every level.")
			_expect(legal.has(first), "Every CPU level must choose a canonical legal move.")
			var incremental := CpuPlayer.new(level, seed_value)
			incremental.begin_turn(state)
			_drain(incremental, 7)
			_expect(
				incremental.chosen_move == first,
				"Identical seeds and states must agree across different think batch sizes."
			)
			_expect(_snapshot(state) == original, "CPU search must not mutate any live state.")
			_expect(
				synchronous._nodes_searched <= CpuPlayer._NODE_LIMITS[level],
				"Every difficulty must respect its hard total node budget."
			)
			if level > 0:
				_expect(synchronous._completed_depth >= 2,
					"Thoughtful and Cunning must complete actual adversarial lookahead.")
			if seed_value == 1:
				_expect(synchronous.choose_move(state) == first,
					"Reusing a CPU must reproduce the same seed/state choice.")
			first["to"] = -1
			_expect(legal.has(synchronous.chosen_move),
				"Mutating the synchronous return value must not alter the CPU's choice.")
	var easy_choices: Dictionary[String, bool] = {}
	for seed_value in range(1, 9):
		var easy := CpuPlayer.new(0, seed_value)
		var move := easy.choose_move(state)
		easy_choices[str(move)] = true
	_expect(easy_choices.size() > 1, "Easy must use its seeded RNG rather than always move first.")
	var black := state.copy_state()
	_expect(black.play_move(_move("e2", "e4")), "The Black-turn fixture must start normally.")
	for level in range(3):
		var cpu := CpuPlayer.new(level, 29)
		_expect(black.legal_moves().has(cpu.choose_move(black)),
			"All levels must also play Black legally.")


func _test_forced_choices_and_promotions() -> void:
	var forced := _position({
		"a1": ChessState.ROOK, "a3": -ChessState.PAWN, "h8": -ChessState.KING,
	})
	var en_passant := _position({
		"e5": ChessState.PAWN, "b1": ChessState.KNIGHT,
		"d5": -ChessState.PAWN, "h8": -ChessState.KING,
	}, ChessState.WHITE, _square("d6"))
	var promotion := _position({"a7": ChessState.PAWN, "h6": -ChessState.KING})
	for level in range(3):
		var cpu := CpuPlayer.new(level, 7)
		cpu.begin_turn(forced)
		_expect(cpu.completed and forced.legal_moves().has(cpu.chosen_move),
			"A sole legal capture needs no search at any difficulty.")
		_expect(int(cpu.chosen_move.get("to", -1)) == _square("a3"),
			"A CPU cannot choose a quiet alternative to a compulsory capture.")
		var ep := cpu.choose_move(en_passant)
		_expect(en_passant.legal_moves().has(ep), "Every CPU level must respect mandatory EP.")
		_expect(int(ep.get("capture", -1)) == _square("d5"),
			"CPU EP retains canonical off-destination capture metadata.")
		var selected := cpu.choose_move(promotion)
		_expect(promotion.legal_moves().has(selected), "CPU promotions must be canonical legal choices.")
		_expect(int(selected.get("promotion", 0)) >= ChessState.KNIGHT,
			"The CPU must explicitly select a promotion, never EMPTY or PAWN.")
		var applied := promotion.copy_state()
		_expect(applied.play_move(selected), "The selected CPU promotion must execute directly.")
	var captures := _position({
		"a1": ChessState.ROOK, "g1": ChessState.KNIGHT,
		"a4": -ChessState.PAWN, "e2": -ChessState.PAWN, "h8": -ChessState.KING,
	})
	for level in range(3):
		var cpu := CpuPlayer.new(level, 73)
		var move := cpu.choose_move(captures)
		_expect(captures.legal_moves().has(move) and int(move.get("capture", -1)) >= 0,
			"The CPU must choose legally among captures across the board.")


func _test_winning_sacrifices() -> void:
	var last_knight := _position({
		"c3": ChessState.KNIGHT, "a8": -ChessState.ROOK, "h8": -ChessState.KING,
	})
	for level: int in [1, 2]:
		var cpu := CpuPlayer.new(level, 91)
		var move := cpu.choose_move(last_knight)
		_expect(
			int(move.get("to", -1)) in [_square("a2"), _square("a4")],
			"Lookahead must offer the last knight to the rook, not preserve material."
		)
		_expect(cpu._completed_depth >= 2, "The winning sacrifice must include the opponent's reply.")
		var line := last_knight.copy_state()
		_expect(line.play_move(move), "The selected sacrifice must be legal.")
		var replies := line.legal_moves()
		_expect(replies.size() == 1 and line.captures_required(),
			"The sacrifice must force the opponent to take the CPU's last piece.")
		if replies.size() == 1:
			_expect(line.play_move(replies[0]), "The forced recapture must execute.")
			_expect(line.finished and line.winner == ChessState.WHITE
				and line.result_reason == "no_pieces",
				"The sacrificed side, not the capturing side, must win.")
	var blockade := _position({
		"a2": ChessState.PAWN, "c3": ChessState.KNIGHT,
		"a3": -ChessState.PAWN, "a8": -ChessState.ROOK,
	})
	for level: int in [1, 2]:
		var cpu := CpuPlayer.new(level, 13)
		var move := cpu.choose_move(blockade)
		_expect(int(move.get("to", -1)) == _square("a4"),
			"The CPU must sacrifice its mobile knight to leave its pawn stalemated.")
		var line := blockade.copy_state()
		_expect(line.play_move(move), "The stalemate sacrifice must be legal.")
		var replies := line.legal_moves()
		_expect(replies.size() == 1, "The stalemate sacrifice must force exactly one recapture.")
		if replies.size() == 1:
			_expect(line.play_move(replies[0]), "The rook must be able to take the offered knight.")
			_expect(line.finished and line.winner == ChessState.WHITE
				and line.result_reason == "no_moves",
				"A no-moves win must outrank material heuristics.")
	var black_knight := _position({
		"c6": -ChessState.KNIGHT, "a1": ChessState.ROOK, "h1": ChessState.KING,
	}, ChessState.BLACK)
	for level: int in [1, 2]:
		var cpu := CpuPlayer.new(level, 91)
		var move := cpu.choose_move(black_knight)
		_expect(int(move.get("to", -1)) in [_square("a5"), _square("a7")],
			"The losing-chess score must work symmetrically when the CPU is Black.")
		var line := black_knight.copy_state()
		_expect(line.play_move(move), "Black's sacrifice must execute.")
		var replies := line.legal_moves()
		if replies.size() == 1:
			_expect(line.play_move(replies[0]), "White's forced capture must execute.")
			_expect(line.finished and line.winner == ChessState.BLACK,
				"Black must win by losing its last piece too.")
		else:
			_expect(false, "Black's last-piece sacrifice must force a single reply.")


func _test_adversarial_reply() -> void:
	var state := _position({
		"a1": ChessState.ROOK, "e1": ChessState.KNIGHT, "d4": -ChessState.KING,
	})
	var trap := state.copy_state()
	_expect(trap.play_move(_move("a1", "a4")), "The tempting rook move must be legal.")
	_expect(_opponent_can_force_win_in_reply(trap),
		"Black can reply Kc4 and force White to capture Black's last piece.")
	var cooperative := trap.copy_state()
	_expect(cooperative.play_move(_move("d4", "e5")),
		"The opponent also has a cooperative alternative in the trap fixture.")
	_expect(not cooperative.finished and not cooperative.captures_required(),
		"Not every opponent reply exposes the trap; the search must minimize, not cooperate.")
	for level: int in [1, 2]:
		var cpu := CpuPlayer.new(level, 37)
		var chosen := cpu.choose_move(state)
		var line := state.copy_state()
		_expect(line.play_move(chosen), "An adversarially selected move must be legal.")
		_expect(not _opponent_can_force_win_in_reply(line),
			"The CPU must avoid an opponent's forced win even when kinder replies exist.")
		_expect(cpu._completed_depth >= 3, "This trap needs a completed three-ply search.")


func _test_incremental_bounds() -> void:
	var state := ChessState.new()
	var cpu := CpuPlayer.new(2, 5)
	_expect(cpu.think(), "An idle CPU is already complete.")
	cpu.begin_turn(state)
	_expect(not cpu.completed, "Cunning must schedule, rather than drain, its opening search.")
	var fallback := cpu.chosen_move.duplicate(true)
	_expect(state.legal_moves().has(fallback), "An unfinished search keeps a legal fallback.")
	_expect(not cpu.think(0) and not cpu.think(-10) and cpu._nodes_searched == 0,
		"Zero and negative budgets must perform no search work.")
	_expect(cpu.chosen_move == fallback, "A zero-budget call must not change the fallback.")
	var before := cpu._nodes_searched
	cpu.think(2147483647)
	_expect(cpu._nodes_searched - before <= CpuPlayer._MAX_BATCH_WORK,
		"An oversized caller budget must still have a bounded batch.")
	_expect(not cpu.completed, "An oversized batch cannot synchronously drain the opening tree.")
	var calls := 0
	while not cpu.completed and calls < 8500:
		before = cpu._nodes_searched
		var done := cpu.think(1)
		_expect(cpu._nodes_searched - before <= 1, "A one-node batch cannot hide recursive expansion.")
		_expect(done == cpu.completed, "think() must report the public completion state.")
		calls += 1
	_expect(cpu.completed, "Even one-step batches must reach the hard total bound.")
	_expect(cpu._nodes_searched <= 2800, "Cunning's search must never exceed 2,800 visited nodes.")
	_expect(cpu._completed_depth >= 2, "Incremental work must still finish an adversarial depth.")
	_expect(state.legal_moves().has(cpu.chosen_move), "A bounded final choice must be legal.")
	before = cpu._nodes_searched
	var chosen := cpu.chosen_move.duplicate(true)
	_expect(cpu.think(1) and cpu._nodes_searched == before and cpu.chosen_move == chosen,
		"Completed searches are idempotent.")
	_expect(CpuPlayer._DEPTH_LIMITS[2] > CpuPlayer._DEPTH_LIMITS[1]
		and CpuPlayer._NODE_LIMITS[2] > CpuPlayer._NODE_LIMITS[1],
		"Cunning must have greater depth and budget than Thoughtful.")


func _test_completed_depth_survives_cutoff() -> void:
	var state := ChessState.new()
	var cpu := CpuPlayer.new(2, 11)
	cpu.begin_turn(state)
	var calls := 0
	while cpu._completed_depth < 1 and not cpu.completed and calls < 500:
		cpu.think(1)
		calls += 1
	_expect(cpu._completed_depth == 1 and not cpu.completed,
		"Iterative deepening must commit depth one before starting deeper work.")
	var committed := cpu.chosen_move.duplicate(true)
	cpu._node_limit = cpu._nodes_searched + 2
	_drain(cpu)
	_expect(cpu._completed_depth == 1 and cpu.chosen_move == committed,
		"A hard cutoff must preserve the best completed depth, not a partially searched root.")
	_expect(cpu._nodes_searched <= cpu._node_limit, "A cutoff cannot overshoot the total node limit.")
	var tiny := CpuPlayer.new(2, 11)
	tiny.begin_turn(state)
	var fallback := tiny.chosen_move.duplicate(true)
	tiny._node_limit = 1
	_expect(tiny.think(1), "Reaching the node cap must complete in the same batch.")
	_expect(tiny._completed_depth == 0 and tiny.chosen_move == fallback,
		"A cutoff before any completed depth must retain the original legal fallback.")


func _test_snapshots_and_cancellation() -> void:
	var live := ChessState.new()
	var cpu := CpuPlayer.new(1, 17)
	var reference := CpuPlayer.new(1, 17)
	var expected := reference.choose_move(live.copy_state())
	cpu.begin_turn(live)
	_expect(live.play_move(_move("e2", "e4")),
		"The live board may advance independently after snapshotting.")
	var after_live_move := _snapshot(live)
	_drain(cpu)
	_expect(cpu.chosen_move == expected, "A pending CPU search must use its original snapshot.")
	_expect(_snapshot(live) == after_live_move,
		"Search cannot restore or alter a subsequently changed board.")
	cpu.begin_turn(live)
	cpu.think(1)
	_expect(not cpu.completed, "There must be pending work to cancel.")
	cpu.cancel()
	_expect(cpu.completed and cpu.chosen_move.is_empty(),
		"Cancellation must discard the pending choice.")
	_expect(cpu._stack.is_empty() and cpu._snapshot == null,
		"Cancellation releases search snapshots.")
	_expect(cpu.think() and cpu.chosen_move.is_empty(), "Cancelled work cannot resume accidentally.")
	_expect(_snapshot(live) == after_live_move, "Cancellation must leave the live board unchanged.")
	var restart := ChessState.new()
	cpu.begin_turn(restart)
	_drain(cpu)
	_expect(cpu.chosen_move == expected,
		"A cancelled CPU must be reusable with deterministic seeding.")
	cpu.begin_turn(restart)
	cpu.think(1)
	cpu.begin_turn(live)
	_drain(cpu)
	_expect(live.legal_moves().has(cpu.chosen_move),
		"begin_turn must replace an unfinished old search.")


func _test_terminal_states() -> void:
	var no_pieces := _position({"h8": -ChessState.KING})
	var no_moves := _position({"a7": ChessState.PAWN, "a8": -ChessState.ROOK})
	var draw := _position(
		{"a1": ChessState.KING, "h8": -ChessState.KING}, ChessState.WHITE, -1, 100
	)
	for level in range(3):
		var cpu := CpuPlayer.new(level, 3)
		for state: ChessState in [no_pieces, no_moves, draw]:
			_expect(state.finished, "The no-action CPU fixture must really be terminal.")
			var before := _snapshot(state)
			cpu.begin_turn(state)
			_expect(cpu.completed and cpu.chosen_move.is_empty() and cpu.think(),
				"Terminal wins and draws must finish immediately with no chosen move.")
			_expect(cpu.choose_move(state).is_empty(), "Synchronous terminal choices are empty too.")
			_expect(_snapshot(state) == before, "Terminal state probes are read-only.")
		cpu.begin_turn(null)
		_expect(cpu.completed and cpu.chosen_move.is_empty(), "An absent state has no pending move.")


func _opponent_can_force_win_in_reply(after_move: ChessState) -> bool:
	var opponent := after_move.turn
	if after_move.finished:
		return after_move.winner == opponent
	for reply: Dictionary in after_move.legal_moves():
		var replied := after_move.copy_state()
		_expect(replied.play_move(reply), "The adversarial oracle's reply must be legal.")
		if replied.finished:
			if replied.winner == opponent:
				return true
			continue
		var all_losing := true
		for response: Dictionary in replied.legal_moves():
			var ending := replied.copy_state()
			_expect(ending.play_move(response), "The adversarial oracle's response must be legal.")
			if not ending.finished or ending.winner != opponent:
				all_losing = false
				break
		if all_losing:
			return true
	return false


func _drain(cpu: CpuPlayer, budget: int = 64) -> void:
	var batches := 0
	while not cpu.completed and batches < 8500:
		var before := cpu._nodes_searched
		var done := cpu.think(budget)
		_expect(done == cpu.completed, "Incremental completion must agree with think's return value.")
		_expect(cpu._nodes_searched - before <= mini(budget, CpuPlayer._MAX_BATCH_WORK),
			"Each batch must stay within its requested and absolute work budget.")
		batches += 1
	_expect(cpu.completed, "A bounded search must terminate without wall-clock dependencies.")


func _square(name: String) -> int:
	return name.unicode_at(0) - 97 + (name.unicode_at(1) - 49) * 8


func _move(from: String, to: String, promotion: int = ChessState.EMPTY) -> Dictionary:
	return {"from": _square(from), "to": _square(to), "promotion": promotion}


func _position(
	pieces: Dictionary,
	turn: int = ChessState.WHITE,
	ep_square: int = -1,
	clock: int = 0
) -> ChessState:
	var board := PackedInt32Array()
	board.resize(64)
	for name: String in pieces:
		board[_square(name)] = int(pieces[name])
	var state := ChessState.new()
	_expect(state.set_position(board, turn, ep_square, clock), "The CPU fixture must be valid.")
	return state


func _snapshot(state: ChessState) -> Dictionary:
	return {
		"board": state.board.duplicate(), "turn": state.turn, "winner": state.winner,
		"finished": state.finished, "reason": state.result_reason, "ply": state.ply_count,
		"clock": state.halfmove_clock, "last": state.last_move.duplicate(true),
		"ep": state._ep_square, "history": state._repetitions.duplicate(),
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
