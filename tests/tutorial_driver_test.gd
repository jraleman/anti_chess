extends SceneTree

## Pure tutorial-driver regressions: variant contracts and scripted practice lines.

const Driver = preload("res://games/anti_chess/tools/tutorial_driver.gd")
const State = preload("res://games/anti_chess/board/chess_state.gd")

var _failures := PackedStringArray()
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_variants()
	_test_scripted_fixtures()
	if _failures.is_empty():
		print("Anti-Chess tutorial driver tests passed (%d checks)." % _checks)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_variants() -> void:
	var driver := Driver.new()
	_expect(driver.configure("solo"), "The solo tutorial variant must be accepted.")
	_expect(driver.steps().size() == 6, "Solo should have six tutorial chapters.")
	_expect(is_equal_approx(driver.duration(), 35.0), "Solo should run for 35 seconds.")
	var solo_settings := driver.settings_overrides()
	_expect(int(solo_settings["game/anti_chess_player_side"]) == State.BLACK,
		"Solo must record from the human Black side.")
	_expect(driver.configure("local"), "The local tutorial variant must be accepted.")
	_expect(driver.steps().size() == 5, "Local should have five tutorial chapters.")
	_expect(is_equal_approx(driver.duration(), 32.5), "Local should run for 32.5 seconds.")
	var local_settings := driver.settings_overrides()
	_expect(int(local_settings["game/anti_chess_player_side"]) == State.WHITE,
		"Local should remain White-facing for shared play.")
	_expect(not driver.configure("versus"), "Unknown tutorial variants must be rejected.")


func _test_scripted_fixtures() -> void:
	var kings := _position({"d4": State.KING, "e5": -State.KING, "h7": -State.PAWN})
	_expect(kings.play_move(_move("d4", "e5")), "The king practice capture must be legal.")
	_expect(not kings.finished and kings.turn == State.BLACK,
		"Capturing the enemy king must leave the remaining side to move.")
	_expect(kings.play_move(_move("h7", "h6")), "The king practice follow-up must be legal.")
	var promotion := _position({"a1": State.KING, "h2": -State.PAWN}, State.BLACK)
	_expect(promotion.play_move(_move("h2", "h1", State.KING)),
		"The scripted Black king promotion must be legal.")
	_expect(promotion.board[_square("h1")] == -State.KING,
		"The promotion fixture must really produce a Black king.")
	var sacrifice := _position({"a1": State.ROOK, "h1": State.KING, "c6": -State.KNIGHT}, State.BLACK)
	_expect(sacrifice.play_move(_move("c6", "a5")),
		"Black's last-piece sacrifice must be legal.")
	_expect(sacrifice.captures_required() and sacrifice.legal_moves().size() == 1,
		"The sacrifice must force White's recapture.")
	_expect(sacrifice.play_move(sacrifice.legal_moves()[0]),
		"The forced tutorial recapture must execute.")
	_expect(sacrifice.finished and sacrifice.winner == State.BLACK
		and sacrifice.result_reason == "no_pieces",
		"Solo should finish by Black giving away the final piece.")
	var stalemate := _position({
		"a2": State.PAWN, "c3": State.KNIGHT, "a3": -State.PAWN, "a8": -State.ROOK,
	})
	_expect(stalemate.play_move(_move("c3", "a4")),
		"White's local practice knight offer must be legal.")
	_expect(stalemate.captures_required() and stalemate.legal_moves().size() == 1,
		"Black must be forced to take the offered knight.")
	_expect(stalemate.play_move(stalemate.legal_moves()[0]),
		"The forced local tutorial capture must execute.")
	_expect(stalemate.finished and stalemate.winner == State.WHITE
		and stalemate.result_reason == "no_moves",
		"Local should finish by White having no legal move.")


func _position(pieces: Dictionary, turn: int = State.WHITE) -> State:
	var state := State.new()
	_expect(state.set_position(_board(pieces), turn), "Tutorial fixtures must be valid.")
	return state


func _board(pieces: Dictionary) -> PackedInt32Array:
	var board := PackedInt32Array()
	board.resize(64)
	for square_name: String in pieces:
		board[_square(square_name)] = int(pieces[square_name])
	return board


func _move(from_square: String, to_square: String, promotion: int = State.EMPTY) -> Dictionary:
	return {
		"from": _square(from_square),
		"to": _square(to_square),
		"promotion": promotion,
	}


func _square(name: String) -> int:
	return name.unicode_at(0) - 97 + (name.substr(1).to_int() - 1) * 8


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
