extends Control

## Keyboard- and touch-accessible promotion/resignation decisions on the shared HUD.

signal promotion_chosen(kind: int)
signal resignation_confirmed
signal cancelled

const State = preload("res://games/anti_chess/board/chess_state.gd")
const Options = preload("res://games/anti_chess/anti_chess_options.gd")

var _title: Label
var _description: Label
var _choices: GridContainer
var _resign: Button
var _cancel: Button
var _first_choice: Button
var _panel: PanelContainer
var _column: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.04, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size.x = 500
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142422")
	style.border_color = Color("e8bd72")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 28)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_panel.add_child(scroll)
	var column := VBoxContainer.new()
	_column = column
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 18)
	scroll.add_child(column)
	column.minimum_size_changed.connect(_queue_fit)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color("fff0d3"))
	column.add_child(_title)
	_description = Label.new()
	_description.custom_minimum_size.x = 430
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.add_theme_font_size_override("font_size", 20)
	column.add_child(_description)
	_choices = GridContainer.new()
	_choices.columns = 2
	_choices.add_theme_constant_override("h_separation", 12)
	_choices.add_theme_constant_override("v_separation", 12)
	column.add_child(_choices)
	for kind in [State.QUEEN, State.ROOK, State.BISHOP, State.KNIGHT, State.KING]:
		var button := Button.new()
		button.text = State.piece_name(kind).capitalize()
		button.custom_minimum_size = Vector2(205, 54)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose.bind(kind))
		_choices.add_child(button)
		if _first_choice == null:
			_first_choice = button
	_resign = Button.new()
	_resign.text = "Resign this match"
	_resign.custom_minimum_size.y = 54
	_resign.pressed.connect(_confirm_resignation)
	column.add_child(_resign)
	_cancel = Button.new()
	_cancel.custom_minimum_size.y = 54
	_cancel.pressed.connect(_cancel_decision)
	column.add_child(_cancel)
	hide()


## No default promotion is played before the human chooses one of all five pieces.
func show_promotion(side_name: String) -> void:
	_title.text = "%s promotes" % side_name
	_description.text = "Choose any piece, even a king. Kings have no royal protection here."
	_choices.show()
	_resign.hide()
	_cancel.text = "Cancel selection"
	show()
	var buttons: Array[Control] = []
	for child in _choices.get_children():
		buttons.append(child as Control)
	buttons.append(_cancel)
	_confine_focus(buttons)
	focus_decision()
	_queue_fit()


## Resignation is explicit because losing one's pieces is otherwise the objective.
func show_resignation(side_name: String) -> void:
	_title.text = "Resign as %s?" % side_name
	_description.text = (
		"Giving away pieces wins. Resigning is different: it awards this match "
		+ "to your opponent."
	)
	_choices.hide()
	_resign.show()
	_cancel.text = "Keep playing"
	show()
	_confine_focus([_cancel, _resign])
	focus_decision()
	_queue_fit()


## Resume returns to the pending decision instead of leaving focus in a freed pause menu.
func focus_decision() -> void:
	if visible:
		(_first_choice if _choices.visible else _cancel).grab_focus()


## Keep five choices readable and tappable without depending on a desktop-sized canvas.
func set_readability_scale(factor: float, compact: bool) -> void:
	var width := minf(500 * factor, maxf(get_viewport_rect().size.x - 56, 1))
	var inner_width := maxf(width - 56, 1)
	var button_width := minf(205 * factor, inner_width)
	_panel.custom_minimum_size.x = width
	_description.custom_minimum_size.x = minf(430 * factor, inner_width)
	_title.add_theme_font_size_override("font_size", roundi(30 * factor))
	_description.add_theme_font_size_override("font_size", roundi(20 * factor))
	_column.add_theme_constant_override("separation", roundi(18 * factor))
	_choices.add_theme_constant_override("h_separation", roundi(12 * factor))
	_choices.add_theme_constant_override("v_separation", roundi(12 * factor))
	_choices.columns = 2 if button_width * 2 + 12 * factor <= inner_width else 1
	var buttons: Array[Control] = [_cancel, _resign]
	for child in _choices.get_children():
		buttons.append(child as Control)
	for button in buttons:
		button.add_theme_font_size_override("font_size", roundi(22 * factor))
		button.custom_minimum_size = Vector2(button_width, (66 if compact else 54) * factor)
	_queue_fit()


## Replay and exit dismiss a pending decision without playing it.
func dismiss() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(Options.CANCEL_ACTION):
		get_viewport().set_input_as_handled()
		_cancel_decision()


func _choose(kind: int) -> void:
	hide()
	promotion_chosen.emit(kind)


func _confirm_resignation() -> void:
	hide()
	resignation_confirmed.emit()


func _cancel_decision() -> void:
	hide()
	cancelled.emit()


func _confine_focus(buttons: Array[Control]) -> void:
	for index in buttons.size():
		var button := buttons[index]
		var before := button.get_path_to(buttons[posmod(index - 1, buttons.size())])
		var after := button.get_path_to(buttons[(index + 1) % buttons.size()])
		button.focus_previous = before
		button.focus_next = after
		button.focus_neighbor_top = before
		button.focus_neighbor_left = before
		button.focus_neighbor_bottom = after
		button.focus_neighbor_right = after


func _queue_fit() -> void:
	_fit_panel.call_deferred()


func _fit_panel() -> void:
	if not is_inside_tree():
		return
	_panel.custom_minimum_size.y = minf(
		_column.get_combined_minimum_size().y + 56,
		maxf(get_viewport_rect().size.y - 56, 1)
	)
