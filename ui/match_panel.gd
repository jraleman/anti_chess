extends PanelContainer

## A turn briefing and scrollable move ledger, not a second round/results shell.

signal flip_requested
signal reset_camera_requested
signal resign_requested

const CREAM := Color("fff0d3")
const GOLD := Color("e8bd72")

var _turn: Label
var _rule: Label
var _selection: Label
var _last_move: Label
var _history: RichTextLabel
var _keys: Label
var _resign: Button
var _flip: Button
var _reset_camera: Button
var _column: VBoxContainer
var _labels: Array[Label] = []
var _key_hint := ""
var _compact := false


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142422")
	style.border_color = Color("6b6146")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	add_theme_stylebox_override("panel", style)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 12)
	add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	frame.add_child(scroll)
	var column := VBoxContainer.new()
	_column = column
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	scroll.add_child(column)
	_label(column, "GIVE IT ALL AWAY", 16, GOLD)
	_turn = _label(column, "White to move", 32, CREAM)
	_rule = _label(column, "Choose a piece", 21, GOLD)
	_selection = _label(column, "Click a piece, then its destination.", 20, CREAM)
	_selection.custom_minimum_size.y = 60
	column.add_child(HSeparator.new())
	_last_move = _label(column, "White moves first.", 18, Color("c6c9bc"))
	_label(column, "MOVE LEDGER", 14, GOLD)
	_history = RichTextLabel.new()
	_history.name = "MoveLedger"
	_history.custom_minimum_size.y = 110
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history.bbcode_enabled = false
	_history.scroll_following = true
	_history.add_theme_font_size_override("normal_font_size", 18)
	_history.add_theme_color_override("default_color", CREAM)
	_history.accessibility_name = "Move ledger"
	column.add_child(_history)
	_keys = _label(column, "", 16, Color("c6c9bc"))
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 10)
	frame.add_child(buttons)
	var flip := Button.new()
	_flip = flip
	flip.text = "Flip Board"
	flip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flip.custom_minimum_size.y = 48
	flip.pressed.connect(func() -> void: flip_requested.emit())
	buttons.add_child(flip)
	_reset_camera = Button.new()
	_reset_camera.text = "Reset View"
	_reset_camera.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reset_camera.pressed.connect(func() -> void: reset_camera_requested.emit())
	buttons.add_child(_reset_camera)
	_resign = Button.new()
	_resign.text = "Resign"
	_resign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resign.pressed.connect(func() -> void: resign_requested.emit())
	buttons.add_child(_resign)


## The textual rule remains explicit even when legal-move assistance is disabled.
func present(turn: String, forced_capture: bool, thinking: bool, finished: bool) -> void:
	_turn.text = turn
	_rule.text = (
		"MATCH COMPLETE" if finished else
		"CAPTURE REQUIRED" if forced_capture else "NO CAPTURE - MOVE FREELY"
	)
	if thinking and not finished:
		_rule.text += "\nCPU is thinking..."
	_resign.disabled = finished


## Selection feedback is also exposed to assistive technology.
func describe_square(text: String) -> void:
	_selection.text = text
	_selection.accessibility_description = text


## Replaces rather than appends so a replay cannot retain the previous match.
func set_ledger(lines: PackedStringArray, last_move: String) -> void:
	_history.text = "\n".join(lines)
	_last_move.text = last_move


## Rebound keys are provided by the controller; this view never reads Settings.
func set_key_hint(text: String) -> void:
	_key_hint = text
	_keys.text = text.replace("\n", " | ") if _compact else text


## The host expands a wide virtual canvas on phones; keep text at a useful pixel size.
func set_readability_scale(factor: float, compact: bool) -> void:
	_compact = compact
	for label in _labels:
		label.add_theme_font_size_override("font_size", roundi(float(label.get_meta("font_size")) * factor))
	_history.add_theme_font_size_override("normal_font_size", roundi(18 * factor))
	_history.custom_minimum_size.y = (85 if compact else 110) * factor
	_selection.custom_minimum_size.y = (42 if compact else 60) * factor
	_column.add_theme_constant_override("separation", roundi((10 if compact else 14) * factor))
	for button in [_flip, _reset_camera, _resign]:
		button.add_theme_font_size_override("font_size", roundi(22 * factor))
		button.custom_minimum_size.y = (66 if compact else 48) * factor
	set_key_hint(_key_hint)


func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("font_size", font_size)
	_labels.append(label)
	parent.add_child(label)
	return label
