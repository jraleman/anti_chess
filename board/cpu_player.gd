extends RefCounted

## Seeded losing-chess CPU. The explicit negamax stack can yield between every
## node or bookkeeping step; neither the live board nor wall-clock time is used.

const ChessState = preload("res://games/anti_chess/board/chess_state.gd")

const _WIN_SCORE := 100000
const _INFINITY := 1000000
const _PIECE_WEIGHT := 100
const _MAX_BATCH_WORK := 128
const _DEPTH_LIMITS: Array[int] = [0, 3, 5]
const _NODE_LIMITS: Array[int] = [0, 1500, 2800]

class SearchFrame:
	extends RefCounted

	var state: ChessState
	var depth_left: int
	var alpha: int
	var beta: int
	var entered: bool = false
	var moves: Array[Dictionary] = []
	var next_index: int = 0
	var best_score: int = -_INFINITY
	var best_move: Dictionary = {}

	func _init(
		position: ChessState, depth: int, lower: int, upper: int
	) -> void:
		state = position
		depth_left = depth
		alpha = lower
		beta = upper


var chosen_move: Dictionary = {}
var completed: bool = true

var _level: int
var _seed_value: int
var _rng := RandomNumberGenerator.new()
var _snapshot: ChessState
var _root_moves: Array[Dictionary] = []
var _stack: Array[SearchFrame] = []
var _node_limit: int = 0
var _nodes_searched: int = 0
var _search_depth: int = 0
var _completed_depth: int = 0


func _init(level: int = 1, seed_value: int = 1) -> void:
	_level = clampi(level, 0, 2)
	_seed_value = seed_value


## Starts from an owned snapshot. Reusing the same seed and position reproduces
## the choice, independently of batching or previously cancelled searches.
func begin_turn(state: ChessState) -> void:
	cancel()
	if state == null:
		return
	_snapshot = state.copy_state()
	_root_moves = _snapshot.legal_moves()
	if _root_moves.is_empty():
		_snapshot = null
		return
	_rng.seed = _seed_value
	_shuffle_root_moves()
	chosen_move = _root_moves[0].duplicate(true)
	if _level == 0 or _root_moves.size() == 1:
		_finish_search()
		return
	completed = false
	_node_limit = _NODE_LIMITS[_level]
	_search_depth = 1
	_start_depth()


## Performs at most node_budget small steps (and at most 128 per call).
## A step visits at most one node; zero or negative budgets do no work.
func think(node_budget: int = 64) -> bool:
	var work_left := clampi(node_budget, 0, _MAX_BATCH_WORK)
	while work_left > 0 and not completed and _nodes_searched < _node_limit:
		_step_search()
		work_left -= 1
	if not completed and _nodes_searched >= _node_limit:
		_finish_search()
	return completed


## Discards both pending work and any fallback choice, ready for another turn.
func cancel() -> void:
	completed = true
	chosen_move = {}
	_snapshot = null
	_root_moves.clear()
	_stack.clear()
	_node_limit = 0
	_nodes_searched = 0
	_search_depth = 0
	_completed_depth = 0


## Synchronous convenience for tests/offline use; the UI should call think().
func choose_move(state: ChessState) -> Dictionary:
	begin_turn(state)
	while not think():
		pass
	return chosen_move.duplicate(true)


func _shuffle_root_moves() -> void:
	for index in range(_root_moves.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var move := _root_moves[index]
		_root_moves[index] = _root_moves[other]
		_root_moves[other] = move


func _start_depth() -> void:
	var frame := SearchFrame.new(
		_snapshot, _search_depth, -_INFINITY, _INFINITY
	)
	frame.moves = _root_moves.duplicate(true)
	_stack.append(frame)


func _step_search() -> void:
	var frame: SearchFrame = _stack.back()
	if not frame.entered:
		frame.entered = true
		_nodes_searched += 1
		if frame.state.finished:
			_return_score(_terminal_score(frame))
			return
		if frame.depth_left == 0:
			_return_score(_evaluate(frame.state))
			return
		if _stack.size() > 1:
			frame.moves = frame.state.legal_moves()
		return
	if frame.next_index >= frame.moves.size():
		_return_score(frame.best_score)
		return
	var move := frame.moves[frame.next_index]
	frame.next_index += 1
	var next_state := frame.state.copy_state()
	if not next_state.play_move(move):
		push_error("Anti-chess CPU generated an invalid search move.")
		cancel()
		return
	_stack.append(SearchFrame.new(
		next_state, frame.depth_left - 1, -frame.beta, -frame.alpha
	))


func _return_score(score: int) -> void:
	var frame: SearchFrame = _stack.pop_back()
	if _stack.is_empty():
		_completed_depth = _search_depth
		chosen_move = frame.best_move.duplicate(true)
		# Only a fully completed root search can replace the committed choice.
		_root_moves.erase(frame.best_move)
		_root_moves.push_front(frame.best_move)
		if (
			_search_depth >= _DEPTH_LIMITS[_level]
			or absi(score) >= _WIN_SCORE - _DEPTH_LIMITS[_level]
		):
			_finish_search()
		else:
			_search_depth += 1
			_start_depth()
		return
	var parent: SearchFrame = _stack.back()
	var value := -score
	if value > parent.best_score:
		parent.best_score = value
		parent.best_move = parent.moves[parent.next_index - 1]
	parent.alpha = maxi(parent.alpha, value)
	if parent.alpha >= parent.beta:
		parent.next_index = parent.moves.size()


func _terminal_score(frame: SearchFrame) -> int:
	if frame.state.winner < 0:
		return 0
	var distance := _search_depth - frame.depth_left
	var score := _WIN_SCORE - distance
	return score if frame.state.winner == frame.state.turn else -score


func _evaluate(state: ChessState) -> int:
	var own := state.piece_count(state.turn)
	var opponent := state.piece_count(1 - state.turn)
	var moves := state.legal_moves()
	var score := (opponent - own) * _PIECE_WEIGHT
	# Being forced to remove the opponent's pieces is a burden, not a reward.
	if not moves.is_empty() and int(moves[0]["capture"]) >= 0:
		score -= 24
	# Few options can lead to the other winning condition: no legal moves.
	score -= mini(moves.size(), 24)
	return score


func _finish_search() -> void:
	completed = true
	_stack.clear()
	_root_moves.clear()
	_snapshot = null
