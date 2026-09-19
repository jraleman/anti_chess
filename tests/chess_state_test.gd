extends SceneTree

## Pure losing-chess regressions; no class cache, scenes, or autoload instances.

const ChessState = preload("res://games/anti_chess/board/chess_state.gd")

var _failures := PackedStringArray()
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_opening_and_helpers()
	_test_compulsory_captures()
	_test_piece_geometry()
	_test_ordinary_kings()
	_test_pawns()
	_test_en_passant()
	_test_promotions()
	_test_atomic_rejection()
	_test_wins()
	_test_resignation()
	_test_draws_and_counters()
	_test_repetition_keys()
	_test_fixtures()
	_test_copies_and_reset()
	if _failures.is_empty():
		print("Anti-chess rules tests passed (%d checks)." % _checks)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_opening_and_helpers() -> void:
	var state := ChessState.new()
	_expect(state.board.size() == 64, "The board must have 64 signed squares.")
	_expect(state.turn == ChessState.WHITE, "White must move first.")
	_expect(
		state.piece_count(ChessState.WHITE) == 16
		and state.piece_count(ChessState.BLACK) == 16,
		"Both sides must start with sixteen pieces."
	)
	var back_rank: Array[int] = [
		ChessState.ROOK, ChessState.KNIGHT, ChessState.BISHOP, ChessState.QUEEN,
		ChessState.KING, ChessState.BISHOP, ChessState.KNIGHT, ChessState.ROOK,
	]
	for file in range(8):
		_expect(
			state.board[file] == back_rank[file]
			and state.board[file + 8] == ChessState.PAWN
			and state.board[file + 48] == -ChessState.PAWN
			and state.board[file + 56] == -back_rank[file],
			"Opening file %d must use the ordinary chess arrangement." % file
		)
	for square in range(16, 48):
		_expect(state.board[square] == ChessState.EMPTY, "Opening center is empty.")
	var moves := state.legal_moves()
	_expect(moves.size() == 20, "The opening must have exactly twenty legal moves.")
	for move: Dictionary in moves:
		_expect(move.size() == 4, "Canonical moves must have all four fields.")
		for key: String in ["from", "to", "promotion", "capture"]:
			_expect(typeof(move.get(key)) == TYPE_INT, "Move fields must be integers.")
		_expect(
			int(move["promotion"]) == ChessState.EMPTY and int(move["capture"]) == -1,
			"Opening moves are neither captures nor promotions."
		)
	_expect_targets(state, "b1", ["a3", "c3"], "The opening knight must jump.")
	_expect_targets(state, "e2", ["e3", "e4"], "Opening pawns get both advances.")
	_expect(state.moves_from(_square("e7")).is_empty(), "Only the current side moves.")
	_expect(state.moves_from(-1).is_empty(), "Negative source squares are invalid.")
	_expect(state.moves_from(64).is_empty(), "Off-board source squares are invalid.")
	_expect(not state.captures_required(), "The opening has no compulsory capture.")
	_expect(
		not state.finished and state.winner == -1 and state.result_reason.is_empty()
		and state.ply_count == 0 and state.halfmove_clock == 0
		and state.last_move.is_empty(),
		"The opening must have fresh counters and no result."
	)
	_expect(
		ChessState.side_of(ChessState.KING) == ChessState.WHITE
		and ChessState.side_of(-ChessState.PAWN) == ChessState.BLACK
		and ChessState.side_of(ChessState.EMPTY) == -1,
		"Signed pieces must map to their side; EMPTY has none."
	)
	_expect(state.piece_count(-1) == 0, "EMPTY is not a third side.")
	_expect(
		ChessState.square_name(0) == "a1" and ChessState.square_name(63) == "h8"
		and ChessState.square_name(-1).is_empty()
		and ChessState.square_name(64).is_empty(),
		"Square names must respect the a1=0 orientation and bounds."
	)
	var names: Array[String] = ["Empty", "Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]
	for piece_type in range(7):
		_expect(
			ChessState.piece_name(piece_type) == names[piece_type]
			and ChessState.piece_name(-piece_type) == names[piece_type],
			"Piece names must work for either sign."
		)
	_expect(ChessState.piece_name(7).is_empty(), "Unknown piece types have no name.")
	moves[0]["to"] = 99
	moves.clear()
	_expect(state.legal_moves().size() == 20, "Returned moves must not mutate the model.")
	_expect(
		state.play_move({"from": _square("e2"), "to": _square("e4")}),
		"EMPTY may be omitted on an ordinary non-promotion move."
	)
	_expect(state.legal_moves().size() == 20, "Black also gets twenty opening replies.")


func _test_compulsory_captures() -> void:
	var state := _position({
		"a1": ChessState.ROOK, "g1": ChessState.KNIGHT,
		"a4": -ChessState.PAWN, "e2": -ChessState.PAWN, "h8": -ChessState.KING,
	})
	_expect(state.captures_required(), "A capture anywhere makes captures compulsory.")
	_expect(state.legal_moves().size() == 2, "Players may choose between captures.")
	_expect_targets(state, "a1", ["a4"], "A rook must ignore its quiet alternatives.")
	_expect_targets(state, "g1", ["e2"], "A different capturing piece remains selectable.")
	var before := _snapshot(state)
	_expect(not state.play_move(_move("g1", "h3")), "A quiet knight cannot evade a capture.")
	_expect(_snapshot(state) == before, "Rejecting a compulsory-capture violation is atomic.")
	var request := _move("a1", "a4")
	request["capture"] = _square("g1")
	_expect(state.play_move(request), "Capture metadata must be derived from the legal move.")
	request["to"] = _square("h8")
	_expect(
		state.board[_square("g1")] == ChessState.KNIGHT
		and state.board[_square("a4")] == ChessState.ROOK
		and state.board[_square("a1")] == ChessState.EMPTY
		and int(state.last_move["capture"]) == _square("a4")
		and int(state.last_move["to"]) == _square("a4"),
		"The caller cannot forge the captured square or mutate last_move afterwards."
	)


func _test_piece_geometry() -> void:
	var counts: Dictionary[int, int] = {
		ChessState.KNIGHT: 8, ChessState.BISHOP: 13, ChessState.ROOK: 14,
		ChessState.QUEEN: 27, ChessState.KING: 8,
	}
	for piece_type: int in counts:
		var state := _position({"d4": piece_type, "a8": -ChessState.KING})
		_expect(
			state.moves_from(_square("d4")).size() == counts[piece_type],
			"%s must have its normal unobstructed geometry." % ChessState.piece_name(piece_type)
		)
	_expect_targets(
		_position({"d4": ChessState.KNIGHT, "a8": -ChessState.KING}), "d4",
		["b3", "b5", "c2", "c6", "e2", "e6", "f3", "f5"],
		"Knights must use all eight L-shaped jumps."
	)
	_expect_targets(
		_position({"d4": ChessState.KING, "a8": -ChessState.KING}), "d4",
		["c3", "c4", "c5", "d3", "d5", "e3", "e4", "e5"],
		"Kings move one square, not along entire rays."
	)
	_expect_targets(
		_position({"a1": ChessState.KNIGHT, "h8": -ChessState.KING}), "a1",
		["b3", "c2"], "Knight moves must not wrap across board edges."
	)
	_expect_targets(
		_position({"h1": ChessState.KING, "a8": -ChessState.KING}), "h1",
		["g1", "g2", "h2"], "King moves must not wrap across board edges."
	)
	var rook := _position({
		"d4": ChessState.ROOK, "b4": ChessState.PAWN, "d6": ChessState.PAWN,
		"d2": -ChessState.KNIGHT, "d1": -ChessState.BISHOP,
		"f4": -ChessState.KNIGHT, "g4": -ChessState.BISHOP,
	})
	_expect_targets(rook, "d4", ["d2", "f4"], "Rooks stop at either side's first blocker.")
	var bishop := _position({
		"d4": ChessState.BISHOP, "e5": ChessState.PAWN,
		"f6": -ChessState.KNIGHT, "b6": -ChessState.KNIGHT,
		"a7": -ChessState.ROOK, "f2": -ChessState.KNIGHT, "g1": -ChessState.ROOK,
	})
	_expect_targets(
		bishop, "d4", ["b6", "f2"], "Bishops neither cross blockers nor capture through them."
	)
	var queen := _position({
		"d4": ChessState.QUEEN, "d6": ChessState.PAWN, "e5": ChessState.PAWN,
		"b4": -ChessState.KNIGHT, "b2": -ChessState.KNIGHT,
		"d7": -ChessState.ROOK, "f6": -ChessState.ROOK,
	})
	_expect_targets(queen, "d4", ["b2", "b4"], "Queens combine both blocked ray families.")
	var knight := _position({
		"d4": ChessState.KNIGHT, "d5": ChessState.PAWN, "e4": ChessState.PAWN,
		"e6": ChessState.PAWN, "b3": -ChessState.ROOK, "f5": -ChessState.ROOK,
	})
	_expect_targets(knight, "d4", ["b3", "f5"], "Knights jump blockers but not onto allies.")
	var black := _position(
		{"d4": -ChessState.QUEEN, "a8": ChessState.KING}, ChessState.BLACK
	)
	_expect(
		black.moves_from(_square("d4")).size() == 27,
		"Non-pawn geometry must be identical for Black."
	)


func _test_ordinary_kings() -> void:
	var state := _position({
		"e1": ChessState.KING, "a1": ChessState.ROOK, "h1": ChessState.ROOK,
		"e8": -ChessState.ROOK, "b8": -ChessState.KING,
	})
	_expect(_find_move(state, "e1", "g1").is_empty(), "Kingside castling does not exist.")
	_expect(_find_move(state, "e1", "c1").is_empty(), "Queenside castling does not exist.")
	_expect(not state.play_move(_move("e1", "g1")), "A castling request must be rejected.")
	_expect(state.play_move(_move("e1", "e2")), "A king may move into or remain in attack.")
	_expect(state.play_move(_move("e8", "e2")), "An exposed king is an ordinary capture.")
	_expect(
		state.piece_count(ChessState.WHITE) == 2 and not state.finished,
		"Losing a king must not end a side that still has mobile pieces."
	)
	var adjacent := _position({
		"d4": ChessState.KING, "e5": -ChessState.KING, "h7": -ChessState.PAWN,
	})
	_expect_targets(adjacent, "d4", ["e5"], "Adjacent kings must capture each other.")
	_expect(adjacent.play_move(_move("d4", "e5")), "Kings may capture enemy kings.")
	_expect(not adjacent.finished, "The opponent's remaining pawn keeps the game active.")


func _test_pawns() -> void:
	_expect_targets(
		_position({"e2": ChessState.PAWN, "h7": -ChessState.PAWN}),
		"e2", ["e3", "e4"], "A starting pawn may advance one or two clear squares."
	)
	_expect_targets(
		_position({
			"e2": ChessState.PAWN, "e3": ChessState.KNIGHT, "h7": -ChessState.PAWN,
		}),
		"e2", [], "An adjacent friendly blocker prevents both pawn advances."
	)
	_expect_targets(
		_position({"e2": ChessState.PAWN, "e4": -ChessState.PAWN}),
		"e2", ["e3"], "A blocked double-step destination still allows a single step."
	)
	_expect_targets(
		_position({"e3": ChessState.PAWN, "h7": -ChessState.PAWN}),
		"e3", ["e4"], "A pawn cannot double-step after leaving its starting rank."
	)
	_expect_targets(
		_position({"e7": -ChessState.PAWN, "a2": ChessState.PAWN}, ChessState.BLACK),
		"e7", ["e5", "e6"], "Black advances toward decreasing ranks."
	)
	_expect_targets(
		_position({"e6": -ChessState.PAWN, "a2": ChessState.PAWN}, ChessState.BLACK),
		"e6", ["e5"], "A moved Black pawn cannot double-step."
	)
	_expect_targets(
		_position({
			"e7": -ChessState.PAWN, "e6": -ChessState.KNIGHT, "a2": ChessState.PAWN,
		}, ChessState.BLACK),
		"e7", [], "Black also cannot jump an adjacent pawn blocker."
	)
	_expect_targets(
		_position({"e4": -ChessState.PAWN, "d3": ChessState.PAWN, "f3": ChessState.PAWN},
			ChessState.BLACK),
		"e4", ["d3", "f3"], "Black captures diagonally downward with either choice."
	)
	_expect_targets(
		_position({"a4": ChessState.PAWN, "h4": -ChessState.PAWN}),
		"a4", ["a5"], "A-file pawns cannot wrap left when capturing."
	)
	_expect_targets(
		_position({"h4": ChessState.PAWN, "a6": -ChessState.PAWN}),
		"h4", ["h5"], "H-file pawns cannot wrap right when capturing."
	)
	_expect_targets(
		_position({"a5": -ChessState.PAWN, "h3": ChessState.PAWN}, ChessState.BLACK),
		"a5", ["a4"], "Black's A-file captures must not wrap."
	)
	_expect_targets(
		_position({"h5": -ChessState.PAWN, "a5": ChessState.PAWN}, ChessState.BLACK),
		"h5", ["h4"], "Black's H-file captures must not wrap."
	)


func _test_en_passant() -> void:
	var state := _position({
		"e5": ChessState.PAWN, "b1": ChessState.KNIGHT,
		"d7": -ChessState.PAWN, "h8": -ChessState.KING,
	}, ChessState.BLACK, -1, 99)
	_expect(state.play_move(_move("d7", "d5")), "Black's double step must create EP rights.")
	_expect(state.halfmove_clock == 0, "A double step resets the reversible clock.")
	_expect_targets(state, "e5", ["d6"], "An available EP capture is compulsory.")
	_expect(state.legal_moves().size() == 1, "EP also suppresses unrelated quiet moves.")
	var before := _snapshot(state)
	_expect(not state.play_move(_move("b1", "a3")), "A knight cannot ignore mandatory EP.")
	_expect(_snapshot(state) == before, "A rejected move must not expire EP rights.")
	var ep := _find_move(state, "e5", "d6")
	_expect(not ep.is_empty(), "The EP move must be exposed canonically.")
	if not ep.is_empty():
		_expect(int(ep["capture"]) == _square("d5"), "EP records the victim, not the landing.")
		ep["capture"] = _square("h8")
		_expect(state.play_move(ep), "The model must apply its own canonical EP capture.")
		_expect(
			state.board[_square("d5")] == ChessState.EMPTY
			and state.board[_square("d6")] == ChessState.PAWN
			and state.board[_square("h8")] == -ChessState.KING
			and state.halfmove_clock == 0 and state.ply_count == 2,
			"EP removes exactly the bypassed pawn and resets the clock."
		)
	var black := _position({
		"e2": ChessState.PAWN, "a1": ChessState.KING, "d4": -ChessState.PAWN,
	})
	_expect(black.play_move(_move("e2", "e4")), "White's double step must create Black EP.")
	_expect_targets(black, "d4", ["e3"], "Black's EP landing square points down the board.")
	_expect(black.play_move(_move("d4", "e3")), "Black must be able to execute EP.")
	_expect(
		black.board[_square("e4")] == ChessState.EMPTY
		and black.board[_square("e3")] == -ChessState.PAWN,
		"Black EP removes the White pawn from the correct square."
	)
	var expires := _position({
		"e5": ChessState.PAWN, "a1": ChessState.ROOK,
		"d5": -ChessState.PAWN, "a3": -ChessState.PAWN, "h8": -ChessState.KING,
	}, ChessState.WHITE, _square("d6"))
	_expect(expires.legal_moves().size() == 2, "EP may compete with an ordinary capture.")
	_expect(expires.play_move(_move("a1", "a3")), "Another compulsory capture may be chosen.")
	_expect(expires.play_move(_move("h8", "h7")), "The opponent can make a quiet reply.")
	_expect_targets(expires, "e5", ["e6"], "Unused EP rights expire after one reply.")
	_expect(not expires.play_move(_move("e5", "d6")), "Expired EP cannot be revived.")


func _test_promotions() -> void:
	var choices: Array[int] = [
		ChessState.QUEEN, ChessState.ROOK, ChessState.BISHOP,
		ChessState.KNIGHT, ChessState.KING,
	]
	var state := _position({"a7": ChessState.PAWN, "h6": -ChessState.KING})
	_expect(state.legal_moves().size() == 5, "Quiet promotion must expose five explicit choices.")
	for promotion: int in choices:
		var promoted := _position(
			{"a7": ChessState.PAWN, "h6": -ChessState.KING}, ChessState.WHITE, -1, 73
		)
		_expect(
			promoted.play_move(_move("a7", "a8", promotion)),
			"White may promote to %s." % ChessState.piece_name(promotion)
		)
		_expect(
			promoted.board[_square("a8")] == promotion
			and promoted.halfmove_clock == 0
			and int(promoted.last_move["promotion"]) == promotion,
			"Promotion must install the chosen piece and reset the pawn clock."
		)
		var black := _position(
			{"h2": -ChessState.PAWN, "a3": ChessState.KING}, ChessState.BLACK
		)
		_expect(black.legal_moves().size() == 5, "Black also receives five promotion choices.")
		_expect(
			black.play_move(_move("h2", "h1", promotion))
			and black.board[_square("h1")] == -promotion,
			"Black's chosen promotion must preserve its signed side."
		)
	var capture := _position({
		"b7": ChessState.PAWN, "a8": -ChessState.ROOK,
		"c8": -ChessState.ROOK, "h6": -ChessState.KING,
	})
	_expect(
		capture.captures_required() and capture.legal_moves().size() == 10,
		"Two promotion captures expose all ten choices and suppress quiet promotion."
	)
	for promotion: int in choices:
		for destination: String in ["a8", "c8"]:
			var move := _find_move(capture, "b7", destination, promotion)
			_expect(
				not move.is_empty() and int(move.get("capture", -1)) == _square(destination),
				"Every capture-promotion must carry its captured square."
			)
	_expect(_find_move(capture, "b7", "b8", ChessState.QUEEN).is_empty(),
		"A quiet promotion cannot evade a promotion capture.")
	var black_capture := _position({
		"b2": -ChessState.PAWN, "a1": ChessState.KNIGHT,
		"c1": ChessState.BISHOP, "h3": ChessState.KING,
	}, ChessState.BLACK)
	_expect(black_capture.legal_moves().size() == 10, "Black capture-promotions have ten choices.")
	_expect(
		black_capture.play_move(_move("b2", "a1", ChessState.KING))
		and black_capture.board[_square("a1")] == -ChessState.KING,
		"A capture may promote Black to an ordinary king."
	)


func _test_atomic_rejection() -> void:
	var state := _position({"a7": ChessState.PAWN, "h6": -ChessState.KING})
	var invalid: Array[Dictionary] = [
		{}, {"from": _square("a7")}, {"to": _square("a8")},
		{"from": _square("a7"), "to": _square("a8")},
		_move("a7", "a8"), _move("a7", "a8", ChessState.PAWN),
		_move("a7", "a8", -ChessState.QUEEN), _move("a7", "a8", 99),
		{"from": "a7", "to": _square("a8"), "promotion": ChessState.QUEEN},
		{"from": 48.0, "to": _square("a8"), "promotion": ChessState.QUEEN},
		{"from": _square("a7"), "to": true, "promotion": ChessState.QUEEN},
		{"from": _square("a7"), "to": 64, "promotion": ChessState.QUEEN},
		{"from": _square("a7"), "to": _square("a8"), "promotion": 5.0},
		{"from": _square("a7"), "to": _square("a8"), "promotion": "5"},
		{"from": _square("a7"), "to": _square("a8"), "promotion": true},
		{"from": -1, "to": _square("a8"), "promotion": ChessState.QUEEN},
		_move("h6", "h5"), _move("b1", "c3"), _move("a7", "a7"),
	]
	var before := _snapshot(state)
	for request: Dictionary in invalid:
		_expect(not state.play_move(request), "An invalid or implicit promotion must be rejected.")
		_expect(_snapshot(state) == before, "Invalid requests must preserve all state and history.")
	var opening := ChessState.new()
	before = _snapshot(opening)
	_expect(not opening.play_move(_move("e2", "e4", ChessState.QUEEN)),
		"A pawn cannot promote before the last rank.")
	_expect(_snapshot(opening) == before, "Premature promotion rejection must be atomic.")


func _test_wins() -> void:
	var no_white := _position({"h8": -ChessState.ROOK})
	_expect_result(no_white, ChessState.WHITE, "no_pieces")
	_expect(no_white.legal_moves().is_empty(), "A finished side has no legal moves.")
	_expect(not no_white.captures_required(), "Finished positions require no capture.")
	var before := _snapshot(no_white)
	_expect(not no_white.play_move(_move("h8", "h7")), "A finished game rejects moves.")
	_expect(_snapshot(no_white) == before, "Post-result rejections must be atomic.")
	var no_black := _position({"a1": ChessState.KING}, ChessState.WHITE, -1, 100)
	_expect_result(no_black, ChessState.BLACK, "no_pieces")
	var last_piece := _position({"a1": ChessState.ROOK, "a2": -ChessState.KNIGHT})
	_expect(last_piece.play_move(_move("a1", "a2")), "Capturing the last enemy piece is legal.")
	_expect_result(last_piece, ChessState.BLACK, "no_pieces")
	var blocked := _position({"a7": ChessState.PAWN, "a8": -ChessState.ROOK})
	_expect_result(blocked, ChessState.WHITE, "no_moves")
	var black_blocked := _position(
		{"h2": -ChessState.PAWN, "h1": ChessState.ROOK}, ChessState.BLACK
	)
	_expect_result(black_blocked, ChessState.BLACK, "no_moves")
	var not_yet := _position(
		{"a7": ChessState.PAWN, "a8": -ChessState.ROOK}, ChessState.BLACK
	)
	_expect(not not_yet.finished, "A blocked side wins only when its own turn arrives.")
	var precedence := _position(
		{"a7": ChessState.PAWN, "a8": -ChessState.ROOK}, ChessState.WHITE, -1, 100
	)
	_expect_result(precedence, ChessState.WHITE, "no_moves")
	var quiet_win := _position(
		{"b1": ChessState.ROOK, "a2": -ChessState.PAWN}, ChessState.WHITE, -1, 99
	)
	_expect(quiet_win.play_move(_move("b1", "a1")), "A quiet move may block the next side.")
	_expect(quiet_win.halfmove_clock == 100, "The terminal move reaches the draw threshold.")
	_expect_result(quiet_win, ChessState.BLACK, "no_moves")


func _test_resignation() -> void:
	var state := ChessState.new()
	var before := _snapshot(state)
	for invalid_side: int in [-1, 2]:
		_expect(not state.resign(invalid_side), "Only White or Black may resign.")
		_expect(_snapshot(state) == before, "An invalid resignation must be atomic.")
	for side: int in [ChessState.WHITE, ChessState.BLACK]:
		for next_turn: int in [ChessState.WHITE, ChessState.BLACK]:
			state.reset()
			if next_turn == ChessState.BLACK:
				_expect(state.play_move(_move("e2", "e4")), "The Black-turn fixture must load.")
			var legal_before := state.legal_moves()[0]
			before = _snapshot(state)
			_expect(state.resign(side), "Either side may resign, including off turn.")
			_expect_result(state, 1 - side, "resignation")
			_expect_result(state.copy_state(), 1 - side, "resignation")
			before["finished"] = true
			before["winner"] = 1 - side
			before["reason"] = "resignation"
			_expect(_snapshot(state) == before,
				"Resignation changes only the outcome, not the board, turn, clocks, or history.")
			_expect(not state.resign(side) and not state.resign(1 - side),
				"Neither repeated nor opposite-side resignation may overwrite a result.")
			_expect(not state.play_move(legal_before),
				"A previously legal move is rejected after resignation.")
			_expect(state.moves_from(int(legal_before["from"])).is_empty()
				and not state.captures_required(),
				"Resignation must clear every legal-move query.")
			_expect(_snapshot(state) == before, "Post-resignation probes must be atomic.")
	var ended := _position({"h8": -ChessState.KING})
	before = _snapshot(ended)
	_expect(not ended.resign(ChessState.WHITE), "A natural terminal result cannot be resigned.")
	_expect(_snapshot(ended) == before, "Resignation cannot replace an existing terminal outcome.")


func _test_draws_and_counters() -> void:
	var kings := _position({"a1": ChessState.KING, "h8": -ChessState.KING})
	_expect(not kings.finished, "Ordinary kings do not cause an insufficient-material draw.")
	_play_cycle(kings)
	_expect(not kings.finished, "The second occurrence is not yet a draw.")
	_expect(kings.halfmove_clock == 4 and kings.ply_count == 4, "Every quiet ply increments clocks.")
	_play_cycle(kings)
	_expect_result(kings, -1, "repetition")
	_expect(kings.ply_count == 8, "The third occurrence ends the game on the exact returning ply.")
	var fifty := _position(
		{"a1": ChessState.KING, "h8": -ChessState.KING}, ChessState.WHITE, -1, 99
	)
	_expect(not fifty.finished, "Ninety-nine reversible halfmoves must not draw.")
	_expect(fifty.play_move(_move("a1", "b1")), "The hundredth quiet halfmove can be played.")
	_expect_result(fifty, -1, "fifty_moves")
	_expect(fifty.halfmove_clock == 100, "The fifty-move rule counts halfmoves, not turns.")
	var pawn := _position({
		"a2": ChessState.PAWN, "b1": ChessState.KING, "h8": -ChessState.KING,
	}, ChessState.WHITE, -1, 99)
	_expect(pawn.play_move(_move("a2", "a3")), "A pawn move can break a ninety-nine-ply run.")
	_expect(pawn.halfmove_clock == 0 and not pawn.finished, "Pawn movement resets the draw clock.")
	var capture := _position({
		"a1": ChessState.ROOK, "a3": -ChessState.PAWN, "h8": -ChessState.KING,
	}, ChessState.WHITE, -1, 99)
	_expect(capture.play_move(_move("a1", "a3")), "A capture can break a ninety-nine-ply run.")
	_expect(capture.halfmove_clock == 0 and not capture.finished, "Captures reset the draw clock.")


func _test_repetition_keys() -> void:
	var pieces := _board({"a1": ChessState.KING, "h8": -ChessState.KING, "d5": -ChessState.PAWN})
	var with_irrelevant := ChessState.new()
	var without := ChessState.new()
	_expect(with_irrelevant.set_position(pieces, ChessState.WHITE, _square("d6")),
		"An EP right without a capturing pawn is a valid fixture.")
	_expect(without.set_position(pieces), "The equivalent no-EP fixture must load.")
	_expect(with_irrelevant._position_key() == without._position_key(),
		"Unusable EP rights must not distinguish repeated positions.")
	_play_cycle(with_irrelevant)
	_play_cycle(with_irrelevant)
	_expect_result(with_irrelevant, -1, "repetition")
	pieces[_square("e5")] = ChessState.PAWN
	var with_relevant := ChessState.new()
	_expect(with_relevant.set_position(pieces, ChessState.WHITE, _square("d6")),
		"A genuine EP capture must load.")
	_expect(without.set_position(pieces), "The matching board without rights must load.")
	_expect(with_relevant._position_key() != without._position_key(),
		"A genuinely available EP capture must be represented in the position key.")
	var changed_turn := ChessState.new()
	_expect(changed_turn.set_position(pieces, ChessState.BLACK), "The other turn must load.")
	_expect(without._position_key() != changed_turn._position_key(),
		"Side to move is part of repetition identity.")
	var different_clock := ChessState.new()
	_expect(different_clock.set_position(pieces, ChessState.WHITE, -1, 75),
		"A different reversible clock must load.")
	_expect(without._position_key() == different_clock._position_key(),
		"Move counters do not distinguish repeated positions.")
	var black_right := _position({
		"a1": ChessState.KING, "h8": -ChessState.KING,
		"e4": ChessState.PAWN, "d4": -ChessState.PAWN,
	}, ChessState.BLACK, _square("e3"))
	var black_without := ChessState.new()
	_expect(black_without.set_position(black_right.board, ChessState.BLACK),
		"Black's key fixture loads.")
	_expect(black_right._position_key() != black_without._position_key(),
		"Black's available EP rights must also distinguish the key.")


func _test_fixtures() -> void:
	var state := ChessState.new()
	var pieces := state.board.duplicate()
	_expect_invalid_position(state, PackedInt32Array([ChessState.KING]), "Short boards are rejected.")
	var long_board := pieces.duplicate()
	long_board.append(ChessState.EMPTY)
	_expect_invalid_position(state, long_board, "Long boards are rejected.")
	var empty := PackedInt32Array()
	empty.resize(64)
	_expect_invalid_position(state, empty, "Both sides empty is an invalid starting fixture.")
	var bad_piece := pieces.duplicate()
	bad_piece[16] = 7
	_expect_invalid_position(state, bad_piece, "Unknown positive piece types are rejected.")
	bad_piece[16] = -7
	_expect_invalid_position(state, bad_piece, "Unknown negative piece types are rejected.")
	bad_piece = pieces.duplicate()
	bad_piece[0] = -ChessState.PAWN
	_expect_invalid_position(state, bad_piece, "An unpromoted pawn cannot occupy rank one.")
	bad_piece = pieces.duplicate()
	bad_piece[63] = ChessState.PAWN
	_expect_invalid_position(state, bad_piece, "An unpromoted pawn cannot occupy rank eight.")
	_expect_invalid_position(state, pieces, "Unknown sides are rejected.", 2)
	_expect_invalid_position(state, pieces, "Negative sides are rejected.", -1)
	_expect_invalid_position(state, pieces, "Negative clocks are rejected.", ChessState.WHITE, -1, -1)
	_expect_invalid_position(state, pieces, "Negative EP targets are rejected.", ChessState.WHITE, -2)
	_expect_invalid_position(state, pieces, "Off-board EP targets are rejected.",
		ChessState.WHITE, 64)
	var ep_board := _board({
		"a1": ChessState.KING, "h8": -ChessState.KING,
		"e5": ChessState.PAWN, "d5": -ChessState.PAWN,
	})
	_expect_invalid_position(state, ep_board, "EP must target the correct rank.",
		ChessState.WHITE, _square("d4"))
	_expect_invalid_position(state, ep_board, "EP cannot follow a reversible move.",
		ChessState.WHITE, _square("d6"), 1)
	for invalid_victim: int in [ChessState.EMPTY, ChessState.PAWN, -ChessState.KNIGHT]:
		var invalid_ep := ep_board.duplicate()
		invalid_ep[_square("d5")] = invalid_victim
		_expect_invalid_position(state, invalid_ep, "EP must have the opponent's bypassed pawn.",
			ChessState.WHITE, _square("d6"))
	var occupied_target := ep_board.duplicate()
	occupied_target[_square("d6")] = ChessState.KNIGHT
	_expect_invalid_position(state, occupied_target, "EP must land on an empty square.",
		ChessState.WHITE, _square("d6"))
	var occupied_origin := ep_board.duplicate()
	occupied_origin[_square("d7")] = -ChessState.PAWN
	_expect_invalid_position(state, occupied_origin, "The double-step origin must now be empty.",
		ChessState.WHITE, _square("d6"))
	_expect(state.set_position(ep_board, ChessState.WHITE, _square("d6")),
		"A complete valid EP fixture must be accepted.")
	ep_board[_square("e5")] = ChessState.QUEEN
	_expect(state.board[_square("e5")] == ChessState.PAWN, "Fixture boards must be copied.")
	_expect(state.set_position(_board({
		"a1": ChessState.KING, "c1": ChessState.KING, "h8": -ChessState.KING,
	})), "Promoted extra kings are valid; royalty counts are not constrained.")


func _test_copies_and_reset() -> void:
	var state := _position({"a1": ChessState.KING, "h8": -ChessState.KING})
	_play_cycle(state)
	var before := _snapshot(state)
	var copied := state.copy_state()
	_expect(_snapshot(copied) == before, "Copies must start with every field and history intact.")
	_play_cycle(copied)
	_expect_result(copied, -1, "repetition")
	_expect(_snapshot(state) == before, "Searching a copy cannot change live history or board.")
	_play_cycle(state)
	_expect_result(state, -1, "repetition")
	var finished_copy := state.copy_state()
	_expect_result(finished_copy, -1, "repetition")
	finished_copy.last_move["to"] = -1
	finished_copy.board[0] = ChessState.QUEEN
	_expect(int(state.last_move["to"]) == _square("h8")
		and state.board[0] == ChessState.KING,
		"Copied move dictionaries and packed boards must not share mutations.")
	state.reset()
	_expect(_snapshot(state) == _snapshot(ChessState.new()),
		"Reset must restore the exact fresh state.")
	var fixture := _board({"a1": ChessState.KING, "h8": -ChessState.KING})
	_expect(state.set_position(fixture), "A fixture may replace a previously played game.")
	_play_cycle(state)
	_expect(state.set_position(fixture), "Setting the same fixture starts new repetition history.")
	_expect(state.ply_count == 0 and state.halfmove_clock == 0 and state.last_move.is_empty(),
		"Fixture installation resets counters and last_move.")
	_play_cycle(state)
	_expect(not state.finished, "A previous fixture's occurrences must not leak.")
	_play_cycle(state)
	_expect_result(state, -1, "repetition")
	var ep := _position({
		"e5": ChessState.PAWN, "d5": -ChessState.PAWN, "h8": -ChessState.KING,
	}, ChessState.WHITE, _square("d6"))
	var ep_copy := ep.copy_state()
	_expect(ep_copy.play_move(_move("e5", "d6")), "Copies retain usable EP rights.")
	_expect(not _find_move(ep, "e5", "d6").is_empty(), "Playing copied EP must preserve live EP.")
	var clock := _position(
		{"a1": ChessState.KING, "h8": -ChessState.KING}, ChessState.WHITE, -1, 99
	)
	var clock_copy := clock.copy_state()
	_expect(clock_copy.play_move(_move("a1", "b1")), "Copies retain the reversible clock.")
	_expect_result(clock_copy, -1, "fifty_moves")
	_expect(not clock.finished and clock.halfmove_clock == 99,
		"Copied draws cannot finish the source.")


func _square(name: String) -> int:
	return name.unicode_at(0) - 97 + (name.unicode_at(1) - 49) * 8


func _board(pieces: Dictionary) -> PackedInt32Array:
	var board := PackedInt32Array()
	board.resize(64)
	for name: String in pieces:
		board[_square(name)] = int(pieces[name])
	return board


func _position(
	pieces: Dictionary,
	turn: int = ChessState.WHITE,
	ep_square: int = -1,
	clock: int = 0
) -> ChessState:
	var state := ChessState.new()
	_expect(state.set_position(_board(pieces), turn, ep_square, clock), "Test fixture must be valid.")
	return state


func _move(from: String, to: String, promotion: int = ChessState.EMPTY) -> Dictionary:
	return {"from": _square(from), "to": _square(to), "promotion": promotion}


func _find_move(
	state: ChessState, from: String, to: String, promotion: int = ChessState.EMPTY
) -> Dictionary:
	for move: Dictionary in state.moves_from(_square(from)):
		if int(move["to"]) == _square(to) and int(move["promotion"]) == promotion:
			return move
	return {}


func _expect_targets(
	state: ChessState, from: String, expected: Array[String], message: String
) -> void:
	var actual: Array[String] = []
	for move: Dictionary in state.moves_from(_square(from)):
		actual.append(ChessState.square_name(int(move["to"])))
	actual.sort()
	expected.sort()
	_expect(actual == expected, "%s Expected %s, got %s." % [message, expected, actual])


func _expect_result(state: ChessState, winner: int, reason: String) -> void:
	_expect(
		state.finished and state.winner == winner and state.result_reason == reason
		and state.legal_moves().is_empty(),
		"Expected terminal winner %d / %s, got %d / %s."
			% [winner, reason, state.winner, state.result_reason]
	)


func _expect_invalid_position(
	state: ChessState,
	pieces: PackedInt32Array,
	message: String,
	turn: int = ChessState.WHITE,
	ep_square: int = -1,
	clock: int = 0
) -> void:
	var before := _snapshot(state)
	_expect(not state.set_position(pieces, turn, ep_square, clock), message)
	_expect(_snapshot(state) == before, "Invalid fixture rejection must be atomic: " + message)


func _play_cycle(state: ChessState) -> void:
	for text: String in ["a1b1", "h8g8", "b1a1", "g8h8"]:
		_expect(state.play_move(_move(text.substr(0, 2), text.substr(2, 2))),
			"The quiet repetition cycle must accept " + text + ".")


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
