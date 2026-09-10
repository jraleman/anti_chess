extends Control

## Original cover art with optional match facts; safe to preload without a game.

const POSTER := preload("res://games/anti_chess/assets/poster.svg")
const ART_SIZE := Vector2(1200.0, 630.0)
const IVORY := Color("fff0d3")
const BRASS := Color("e8bd72")
const INK := Color("102320")

var _pieces_left: Array[int] = []
var _ply_count := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


## Reconfiguration never carries a previous match's counts into a generic card.
func configure(data: Dictionary) -> void:
	_pieces_left.clear()
	_ply_count = -1
	if data.has("pieces_left"):
		var counts: Variant = data["pieces_left"]
		if (
			counts is Array and counts.size() == 2
			and counts[0] is int and counts[1] is int
			and counts[0] >= 0 and counts[0] <= 16
			and counts[1] >= 0 and counts[1] <= 16
		):
			_pieces_left.assign(counts)
		else:
			push_warning("Anti-Chess share art: pieces_left needs two counts from 0 to 16.")
	if data.has("ply_count"):
		var plies: Variant = data["ply_count"]
		if plies is int and plies >= 0:
			_ply_count = plies
		else:
			push_warning("Anti-Chess share art: ply_count must be a non-negative integer.")
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fit := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	var offset := (size - ART_SIZE * fit) * 0.5
	draw_set_transform(offset, 0.0, Vector2.ONE * fit)
	draw_texture_rect(POSTER, Rect2(Vector2.ZERO, ART_SIZE), false)

	if _pieces_left.is_empty() and _ply_count < 0:
		return
	draw_rect(Rect2(62.0, 448.0, 423.0, 122.0), INK)
	draw_line(Vector2(63.0, 448.0), Vector2(63.0, 570.0), BRASS, 3.0)
	var font := ThemeDB.fallback_font
	var baseline := 493.0
	if not _pieces_left.is_empty():
		draw_string(
			font, Vector2(80.0, 478.0), "PIECES LEFT",
			HORIZONTAL_ALIGNMENT_LEFT, 390.0, 21, BRASS
		)
		draw_string(
			font, Vector2(80.0, 512.0),
			"White: %d   Black: %d" % [_pieces_left[0], _pieces_left[1]],
			HORIZONTAL_ALIGNMENT_LEFT, 390.0, 29, IVORY
		)
		baseline = 548.0
	if _ply_count >= 0:
		draw_string(
			font, Vector2(80.0, baseline), "%d %s played" % [
				_ply_count, "half-move" if _ply_count == 1 else "half-moves",
			],
			HORIZONTAL_ALIGNMENT_LEFT, 390.0, 24, IVORY
		)
