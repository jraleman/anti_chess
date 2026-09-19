extends RefCounted

## Node-free standard losing chess: compulsory captures, capturable kings,
## explicit promotions, and automatic repetition / fifty-move draws.
## Use set_position(), not direct board edits, to keep fixtures and history in sync.

const ChessState = preload("res://games/anti_chess/board/chess_state.gd")

const EMPTY := 0
const PAWN := 1
const KNIGHT := 2
const BISHOP := 3
const ROOK := 4
const QUEEN := 5
const KING := 6
const WHITE := 0
const BLACK := 1

const _BACK_RANK: Array[int] = [
	ROOK, KNIGHT, BISHOP, QUEEN, KING, BISHOP, KNIGHT, ROOK,
]
const _PROMOTIONS: Array[int] = [QUEEN, ROOK, BISHOP, KNIGHT, KING]
const _ORTHOGONAL: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const _DIAGONAL: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]
const _KNIGHT_STEPS: Array[Vector2i] = [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2),
	Vector2i(-1, -2), Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2),
]

var board := PackedInt32Array()
var turn: int = WHITE
var winner: int = -1
var finished: bool = false
var result_reason: String = ""
var ply_count: int = 0
var halfmove_clock: int = 0
var last_move: Dictionary = {}

var _ep_square: int = -1
var _repetitions: Dictionary[String, int] = {}


func _init() -> void:
	reset()


## Restores the ordinary opening without retaining moves or draw history.
func reset() -> void:
	board = PackedInt32Array()
	board.resize(64)
	for file in range(8):
		board[file] = _BACK_RANK[file]
		board[file + 8] = PAWN
		board[file + 48] = -PAWN
		board[file + 56] = -_BACK_RANK[file]
	turn = WHITE
	winner = -1
	finished = false
	result_reason = ""
	ply_count = 0
	halfmove_clock = 0
	last_move = {}
	_ep_square = -1
	_repetitions.clear()
	_record_position()


## Returns detached canonical moves, filtered across the whole side for captures.
func legal_moves() -> Array[Dictionary]:
	if finished:
		return []
	return _generate_moves()


## A piece cannot make a quiet move when any friendly piece can capture.
func moves_from(square: int) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if square < 0 or square >= 64:
		return moves
	for move: Dictionary in legal_moves():
		if int(move["from"]) == square:
			moves.append(move)
	return moves


## Validates before mutation; caller-supplied capture metadata is never trusted.
## Omitted promotion means EMPTY, which cannot match a promotion move.
func play_move(move: Dictionary) -> bool:
	if finished:
		return false
	var from_value: Variant = move.get("from")
	var to_value: Variant = move.get("to")
	var promotion_value: Variant = move.get("promotion", EMPTY)
	if (
		typeof(from_value) != TYPE_INT
		or typeof(to_value) != TYPE_INT
		or typeof(promotion_value) != TYPE_INT
	):
		return false
	for canonical: Dictionary in legal_moves():
		if (
			canonical["from"] == from_value
			and canonical["to"] == to_value
			and canonical["promotion"] == promotion_value
		):
			_apply_move(canonical)
			return true
	return false


## Either side may concede off turn without changing the board or move history.
func resign(side: int) -> bool:
	if finished or (side != WHITE and side != BLACK):
		return false
	_win(1 - side, "resignation")
	return true


## Counts pieces, not conventional chess material; every piece must be lost.
func piece_count(side: int) -> int:
	if side != WHITE and side != BLACK:
		return 0
	var count := 0
	for piece: int in board:
		if side_of(piece) == side:
			count += 1
	return count


## En passant counts as a compulsory capture too; finished games have no moves.
func captures_required() -> bool:
	var moves := legal_moves()
	return not moves.is_empty() and int(moves[0]["capture"]) >= 0


## Search copies own their board, move metadata, and complete repetition history.
func copy_state() -> ChessState:
	var copied := ChessState.new()
	copied.board = board.duplicate()
	copied.turn = turn
	copied.winner = winner
	copied.finished = finished
	copied.result_reason = result_reason
	copied.ply_count = ply_count
	copied.halfmove_clock = halfmove_clock
	copied.last_move = last_move.duplicate(true)
	copied._ep_square = _ep_square
	copied._repetitions = _repetitions.duplicate()
	return copied


## Installs a detached fixture atomically and starts fresh draw history.
## An EP target must describe a just-completed double step, even if unusable.
## Kings are unrestricted; unpromoted pawns cannot occupy either back rank.
func set_position(
	pieces: PackedInt32Array,
	next_turn: int = WHITE,
	ep_square: int = -1,
	reversible_plies: int = 0
) -> bool:
	if (
		pieces.size() != 64
		or (next_turn != WHITE and next_turn != BLACK)
		or reversible_plies < 0
		or ep_square < -1
		or ep_square >= 64
	):
		return false
	var occupied := false
	for square in range(64):
		var piece := pieces[square]
		if piece < -KING or piece > KING:
			return false
		if absi(piece) == PAWN and (square < 8 or square >= 56):
			return false
		occupied = occupied or piece != EMPTY
	if not occupied:
		return false
	if ep_square >= 0:
		var step := 8 if next_turn == WHITE else -8
		var target_rank := 5 if next_turn == WHITE else 2
		var enemy_pawn := -PAWN if next_turn == WHITE else PAWN
		if (ep_square >> 3) != target_rank or reversible_plies != 0:
			return false
		if (
			pieces[ep_square] != EMPTY
			or pieces[ep_square - step] != enemy_pawn
			or pieces[ep_square + step] != EMPTY
		):
			return false
	board = pieces.duplicate()
	turn = next_turn
	_ep_square = ep_square
	halfmove_clock = reversible_plies
	ply_count = 0
	last_move = {}
	_repetitions.clear()
	_record_position()
	_resolve_result()
	return true


## Signed piece encoding leaves EMPTY without a side.
static func side_of(piece: int) -> int:
	if piece == EMPTY:
		return -1
	return WHITE if piece > 0 else BLACK


## Algebraic coordinates are presentation-only; an invalid square has no name.
static func square_name(square: int) -> String:
	if square < 0 or square >= 64:
		return ""
	return "%s%d" % [String.chr(97 + square % 8), (square >> 3) + 1]


## Accepts either signed pieces or unsigned promotion types.
static func piece_name(piece_type: int) -> String:
	match absi(piece_type):
		EMPTY:
			return "Empty"
		PAWN:
			return "Pawn"
		KNIGHT:
			return "Knight"
		BISHOP:
			return "Bishop"
		ROOK:
			return "Rook"
		QUEEN:
			return "Queen"
		KING:
			return "King"
	return ""


func _generate_moves() -> Array[Dictionary]:
	var quiet: Array[Dictionary] = []
	var captures: Array[Dictionary] = []
	for square in range(64):
		var piece := board[square]
		if side_of(piece) != turn:
			continue
		match absi(piece):
			PAWN:
				_pawn_moves(square, quiet, captures)
			KNIGHT:
				_ray_moves(square, _KNIGHT_STEPS, false, quiet, captures)
			BISHOP:
				_ray_moves(square, _DIAGONAL, true, quiet, captures)
			ROOK:
				_ray_moves(square, _ORTHOGONAL, true, quiet, captures)
			QUEEN:
				_ray_moves(square, _ORTHOGONAL, true, quiet, captures)
				_ray_moves(square, _DIAGONAL, true, quiet, captures)
			KING:
				_ray_moves(square, _ORTHOGONAL, false, quiet, captures)
				_ray_moves(square, _DIAGONAL, false, quiet, captures)
	return captures if not captures.is_empty() else quiet


func _ray_moves(
	square: int,
	directions: Array[Vector2i],
	sliding: bool,
	quiet: Array[Dictionary],
	captures: Array[Dictionary]
) -> void:
	var origin := Vector2i(square % 8, square >> 3)
	for direction: Vector2i in directions:
		var target := origin + direction
		while target.x >= 0 and target.x < 8 and target.y >= 0 and target.y < 8:
			var destination := target.x + target.y * 8
			var occupant := board[destination]
			if side_of(occupant) == turn:
				break
			var capture := destination if occupant != EMPTY else -1
			var move := _move(square, destination, EMPTY, capture)
			if capture >= 0:
				captures.append(move)
			else:
				quiet.append(move)
			if not sliding or occupant != EMPTY:
				break
			target += direction


func _pawn_moves(
	square: int, quiet: Array[Dictionary], captures: Array[Dictionary]
) -> void:
	var step := 8 if turn == WHITE else -8
	var target := square + step
	if target < 0 or target >= 64:
		return
	if board[target] == EMPTY:
		_append_pawn_move(quiet, square, target, -1)
		var start_rank := 1 if turn == WHITE else 6
		if (square >> 3) == start_rank and board[target + step] == EMPTY:
			quiet.append(_move(square, target + step, EMPTY, -1))
	for file_step: int in [-1, 1]:
		var file := square % 8 + file_step
		if file < 0 or file >= 8:
			continue
		var destination := target + file_step
		var capture := -1
		if board[destination] != EMPTY and side_of(board[destination]) != turn:
			capture = destination
		elif destination == _ep_square:
			capture = _en_passant_capture(square)
		if capture >= 0:
			_append_pawn_move(captures, square, destination, capture)


func _append_pawn_move(
	moves: Array[Dictionary], from: int, to: int, capture: int
) -> void:
	if to < 8 or to >= 56:
		for promotion: int in _PROMOTIONS:
			moves.append(_move(from, to, promotion, capture))
	else:
		moves.append(_move(from, to, EMPTY, capture))


func _move(from: int, to: int, promotion: int, capture: int) -> Dictionary:
	return {"from": from, "to": to, "promotion": promotion, "capture": capture}


func _en_passant_capture(from: int) -> int:
	if _ep_square < 0 or from < 0 or from >= 64:
		return -1
	var pawn := PAWN if turn == WHITE else -PAWN
	var step := 8 if turn == WHITE else -8
	if board[from] != pawn or board[_ep_square] != EMPTY:
		return -1
	if (
		absi(from % 8 - _ep_square % 8) != 1
		or ((_ep_square - step) >> 3) != (from >> 3)
	):
		return -1
	var capture := _ep_square - step
	return capture if board[capture] == -pawn else -1


func _apply_move(move: Dictionary) -> void:
	var from := int(move["from"])
	var to := int(move["to"])
	var capture := int(move["capture"])
	var promotion := int(move["promotion"])
	var piece := board[from]
	board[from] = EMPTY
	if capture >= 0:
		board[capture] = EMPTY
	board[to] = piece
	if promotion != EMPTY:
		board[to] = promotion if turn == WHITE else -promotion
	_ep_square = -1
	if absi(piece) == PAWN and absi(to - from) == 16:
		_ep_square = from + (8 if turn == WHITE else -8)
	if absi(piece) == PAWN or capture >= 0:
		halfmove_clock = 0
	else:
		halfmove_clock += 1
	ply_count += 1
	last_move = move.duplicate(true)
	turn = 1 - turn
	_record_position()
	_resolve_result()


func _position_key() -> String:
	var relevant_ep := -1
	if _ep_square >= 0:
		var step := 8 if turn == WHITE else -8
		for file_step: int in [-1, 1]:
			if _en_passant_capture(_ep_square - step + file_step) >= 0:
				relevant_ep = _ep_square
				break
	return "%s|%d|%d" % [str(board), turn, relevant_ep]


func _record_position() -> void:
	var key := _position_key()
	_repetitions[key] = _repetitions.get(key, 0) + 1


func _resolve_result() -> void:
	winner = -1
	finished = false
	result_reason = ""
	if piece_count(turn) == 0:
		_win(turn, "no_pieces")
	elif piece_count(1 - turn) == 0:
		_win(1 - turn, "no_pieces")
	elif _generate_moves().is_empty():
		_win(turn, "no_moves")
	elif _repetitions.get(_position_key(), 0) >= 3:
		finished = true
		result_reason = "repetition"
	elif halfmove_clock >= 100:
		finished = true
		result_reason = "fifty_moves"


func _win(side: int, reason: String) -> void:
	finished = true
	winner = side
	result_reason = reason
