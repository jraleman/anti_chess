extends SceneTree

## Focused setup-flow coverage for Anti-Chess mode selection and instructions.

const Options = preload("res://games/anti_chess/anti_chess_options.gd")
const ROUTE_FIXTURE := "res://games/anti_chess/tests/route_fixture.gd"
const MODE_SELECT := "res://scenes/menus/mode_select.tscn"
const INSTRUCTIONS := "res://scenes/menus/instructions.tscn"
const HUMAN_CONTROLLER := 0
const CPU_CONTROLLER := 1

var _failures := PackedStringArray()
var _settings: Node
var _session: Node
var _router: Node
var _manifest: GameManifest
var _saved_values: Dictionary
var _saved_session := {}
var _saved_game := ""
var _saved_router_busy := false
var _saved_manifest := {}
var _save_timer: Timer
var _save_timer_mode := Node.PROCESS_MODE_INHERIT
var _save_timer_wait := 0.0
var _save_timer_remaining := 0.0
var _settings_hash := ""
var _original_actions := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_settings = get_root().get_node_or_null("Settings")
	_session = get_root().get_node_or_null("GameSession")
	_router = get_root().get_node_or_null("Router")
	_manifest = GameCatalog.get_manifest(Options.GAME_ID)
	if _settings == null or _session == null or _router == null or _manifest == null:
		_failures.append("Settings, GameSession, Router and the Anti-Chess manifest are required.")
		_finish()
		return

	_snapshot_state()
	_install_defaults()

	await _test_solo_colour_choices()
	await _test_local_setup_is_human_only()
	await _test_solo_only_routing_and_confirmation()
	await _test_live_rebindings()
	await _test_instruction_paths_and_copy()

	_restore_state()
	_expect(
		_settings_hash_now() == _settings_hash,
		"The setup test must not write temporary values to user://settings.cfg."
	)
	_finish()


func _snapshot_state() -> void:
	_saved_values = (_settings.get("_values") as Dictionary).duplicate(true)
	_saved_game = GameCatalog.current_id()
	for property: String in [
		"game_mode", "player_two_controller", "cpu_difficulty",
		"_controllers_assigned", "_gamepad_available",
	]:
		_saved_session[property] = _session.get(property)
	_saved_session["_controller_devices"] = (
		_session.get("_controller_devices") as Array
	).duplicate()
	_saved_router_busy = bool(_router.get("_busy"))
	_router.set("_busy", true)
	_saved_manifest = {
		"supports_multiplayer": _manifest.supports_multiplayer,
		"solo_setup_choices": (_manifest.solo_setup_choices as Array[String]).duplicate(),
	}
	_save_timer = _settings.get("_save_timer") as Timer
	_save_timer_mode = _save_timer.process_mode
	_save_timer_wait = _save_timer.wait_time
	_save_timer_remaining = _save_timer.time_left
	_save_timer.process_mode = Node.PROCESS_MODE_DISABLED
	_save_timer.stop()
	_settings_hash = _settings_hash_now()
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		var action := StringName(binding.get("action", &""))
		if action.is_empty():
			continue
		var exists := InputMap.has_action(action)
		_original_actions[action] = {
			"exists": exists,
			"deadzone": InputMap.action_get_deadzone(action) if exists else 0.5,
			"events": InputMap.action_get_events(action) if exists else [],
		}


func _install_defaults() -> void:
	GameCatalog.select(Options.GAME_ID)
	for binding: Dictionary in Options.CONTROL_BINDINGS:
		_settings.call("set_value", binding["key"], binding["default"])
	_settings.call("set_value", Options.CPU_DIFFICULTY_KEY, Options.DEFAULT_CPU_DIFFICULTY)
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, Options.DEFAULT_PLAYER_SIDE)
	_settings.call("set_value", Options.SHOW_HINTS_KEY, Options.DEFAULT_SHOW_HINTS)
	_settings.call("set_value", Options.PIECE_LABELS_KEY, Options.DEFAULT_PIECE_LABELS)
	_settings.call("set_value", Settings.REDUCED_MOTION_KEY, true)
	_settings.call("set_value", "game/show_instructions", true)
	_session.call("configure_single_player")


func _test_solo_colour_choices() -> void:
	var menu := await _open(MODE_SELECT)
	if menu == null:
		return
	_press(menu, "%SinglePlayerButton")
	var choices := menu.get_node("%SoloSetupChoices") as Control
	var white := _solo_choice_button(menu, Options.PLAYER_SIDE_KEY, Options.PLAYER_WHITE)
	var black := _solo_choice_button(menu, Options.PLAYER_SIDE_KEY, Options.PLAYER_BLACK)
	_expect(
		choices.visible and white != null and black != null,
		"Single-player Anti-Chess must show White/Black setup buttons."
	)
	if white != null and black != null:
		_expect(
			white.button_pressed and not black.button_pressed,
			"White must be the default solo side."
		)
		_expect(
			not white.tooltip_text.is_empty()
			and white.accessibility_description == white.tooltip_text
			and not black.tooltip_text.is_empty()
			and black.accessibility_description == black.tooltip_text,
			"Generated solo setup buttons must expose accessible descriptions."
		)
		black.emit_signal("pressed")
		_expect(
			int(_settings.call("tunable_choice", Options.PLAYER_SIDE_KEY))
			== Options.PLAYER_BLACK,
			"Choosing Black must write through Settings immediately."
		)
		_expect(
			str((menu.get_node("%SinglePlayerRoster") as Label).text).contains("Black")
			and str((menu.get_node("%SinglePlayerRoster") as Label).text).contains("CPU")
			and str((menu.get_node("%SelectionSummary") as Label).text).contains("Black")
			and str((menu.get_node("%SelectionSummary") as Label).text).contains("CPU"),
			"Solo roster and selection summary must name the chosen colour against the CPU."
		)
		_expect(
			not _visible_copy(menu).contains("plays alone")
			and not _visible_copy(menu).contains("only Player 1 takes part"),
			"Anti-Chess solo setup must not use generic plays-alone wording."
		)
		_expect(
			(menu.get_node("%ConfirmTitle") as Label).text.contains("Black")
			and (menu.get_node("%ConfirmDescription") as Label).text.contains("Black"),
			"Solo confirmation copy must follow the chosen colour."
		)
		white.emit_signal("pressed")
		_expect(
			int(_settings.call("tunable_choice", Options.PLAYER_SIDE_KEY))
			== Options.PLAYER_WHITE
			and white.button_pressed
			and not black.button_pressed,
			"Choosing White again must restore the persisted solo side."
		)
	await _close(menu)


func _test_local_setup_is_human_only() -> void:
	_session.call("configure_multiplayer", CPU_CONTROLLER, 2)
	var menu := await _open(MODE_SELECT)
	if menu == null:
		return
	_press(menu, "%MultiplayerButton")
	_expect(
		not (menu.get_node("%SoloSetupChoices") as Control).visible
		and not (menu.get_node("%OpponentSelector") as Control).visible,
		"Local Anti-Chess must hide the solo colour chooser and the multiplayer CPU picker."
	)
	var cpu_button := menu.get_node("%CpuOptionButton") as Button
	var human_button := menu.get_node("%HumanOptionButton") as Button
	cpu_button.button_pressed = true
	human_button.button_pressed = false
	_press(menu, "%ConfirmButton")
	_expect(
		bool(_session.call("player_two_enabled"))
		and not bool(_session.call("player_two_is_cpu")),
		"Confirming local Anti-Chess must seat a second human even from a stale CPU state."
	)
	_expect(
		(menu.get_node("%ConfirmDescription") as Label).text.contains("Two humans")
		and not _visible_copy(menu).containsn("choose player 2"),
		"Local confirmation copy must describe two humans, not a hidden CPU branch."
	)
	await _close(menu)


func _test_solo_only_routing_and_confirmation() -> void:
	var original_multiplayer := _manifest.supports_multiplayer
	var original_choices := (_manifest.solo_setup_choices as Array[String]).duplicate()
	_manifest.supports_multiplayer = false
	_manifest.solo_setup_choices = original_choices.duplicate()
	_settings.call("set_value", "game/show_instructions", false)
	_session.call("configure_multiplayer", CPU_CONTROLLER, 2)

	var script := load(ROUTE_FIXTURE) as Script
	var route := script.new() as Node
	route.call("start_selected_game", MODE_SELECT, INSTRUCTIONS)
	_expect(
		int(route.get("goto_calls")) == 1 and str(route.get("last_destination")) == MODE_SELECT,
		"Solo-only Anti-Chess with solo_setup_choices must still route to mode select."
	)

	var menu := await _open(MODE_SELECT)
	if menu != null:
		_expect(
			not bool(menu.get("_player_count_offered"))
			and int(menu.get("_pending_mode")) == GameSession.GameMode.SINGLE_PLAYER
			and bool(menu.get("_mode_chosen"))
			and not (menu.get_node("Margins/Layout/Stepper") as Control).visible
			and not (menu.get_node("%PreviousButton") as Control).visible
			and not (menu.get_node("%SelectionStep") as Control).visible
			and (menu.get_node("%ConfirmStep") as Control).visible
			and (menu.get_node("%SoloSetupChoices") as Control).visible,
			"A solo-only Anti-Chess setup must collapse straight to the single-player confirmation."
		)
		await _close(menu)

	_manifest.solo_setup_choices = []
	route.free()
	route = script.new() as Node
	route.call("start_selected_game", MODE_SELECT, INSTRUCTIONS)
	_expect(
		int(route.get("goto_calls")) == 1
		and str(route.get("last_destination")) == _manifest.gameplay_scene_path,
		"Without solo_setup_choices and with instructions off, solo-only Anti-Chess must start directly."
	)
	_expect(
		bool(_session.call("is_single_player")),
		"Direct solo start must still configure a single-player session."
	)
	_settings.call("set_value", "game/show_instructions", true)
	route.free()
	route = script.new() as Node
	route.call("start_selected_game", MODE_SELECT, INSTRUCTIONS)
	_expect(
		int(route.get("goto_calls")) == 1 and str(route.get("last_destination")) == INSTRUCTIONS,
		"Without solo_setup_choices and with instructions on, solo-only Anti-Chess must keep the old instructions route."
	)

	_manifest.supports_multiplayer = original_multiplayer
	_manifest.solo_setup_choices = original_choices
	route.free()


func _test_live_rebindings() -> void:
	_session.call("configure_single_player")
	var menu := await _open(MODE_SELECT)
	var instructions := await _open(INSTRUCTIONS)
	if menu == null or instructions == null:
		await _close(menu)
		await _close(instructions)
		return
	_press(menu, "%SinglePlayerButton")
	_expect(
		bool(_settings.call("set_binding_key", Options.CURSOR_UP_KEY, KEY_F6, Options.GAME_ID))
		and bool(_settings.call("set_binding_key", Options.CAMERA_UP_KEY, KEY_F7, Options.GAME_ID)),
		"Square and camera bindings must both rebind through Settings."
	)
	_expect(
		(menu.get_node("%SinglePlayerControls") as Label).text.contains("F6")
		and (menu.get_node("%SinglePlayerControls") as Label).text.contains("F7")
		and (menu.get_node("%PlayerOneControlKeys") as Label).text.contains("F6")
		and (menu.get_node("%PlayerOneControlKeys") as Label).text.contains("F7"),
		"Mode select must refresh both square and camera key summaries live."
	)
	_expect(
		(instructions.get_node("%PlayerOneControls") as Label).text.contains("Cursor up: F6")
		and (instructions.get_node("%PlayerOneControls") as Label).text.contains("Camera up: F7"),
		"Instructions must refresh rebound square and camera bindings live."
	)
	await _close(menu)
	await _close(instructions)


func _test_instruction_paths_and_copy() -> void:
	_settings.call("set_value", Options.PLAYER_SIDE_KEY, Options.PLAYER_BLACK)
	_session.call("configure_single_player")
	var instructions := await _open(INSTRUCTIONS)
	if instructions != null:
		_expect(
			str(instructions.call("_selected_tutorial_video_path")) == _manifest.tutorial_video_path,
			"Single-player instructions must keep the primary Anti-Chess tutorial clip."
		)
		_expect(
			str(instructions.call("_selected_tutorial_poster_path")) == _manifest.tutorial_poster_path,
			"Single-player instructions must keep the primary Anti-Chess tutorial poster."
		)
		_expect(
			(instructions.get_node("%Summary") as Label).text.contains("Black")
			and (instructions.get_node("%Summary") as Label).text.contains("CPU"),
			"Single-player instructions must describe the chosen colour against the CPU."
		)
		await _close(instructions)

	_session.call("configure_multiplayer", HUMAN_CONTROLLER, 2)
	instructions = await _open(INSTRUCTIONS)
	if instructions != null:
		_expect(
			str(instructions.call("_selected_tutorial_video_path"))
			== _manifest.local_tutorial_video_path,
			"Local human instructions must select the local Anti-Chess tutorial clip."
		)
		_expect(
			str(instructions.call("_selected_tutorial_poster_path"))
			== _manifest.local_tutorial_poster_path,
			"Local human instructions must select the local Anti-Chess tutorial poster."
		)
		_expect(
			(instructions.get_node("%Summary") as Label).text.contains("Two humans")
			and not (instructions.get_node("%Summary") as Label).text.contains("CPU"),
			"Local instructions must describe two humans only."
		)
		await _close(instructions)

	_session.call("configure_multiplayer", CPU_CONTROLLER, 2)
	instructions = await _open(INSTRUCTIONS)
	if instructions != null:
		_expect(
			str(instructions.call("_selected_tutorial_video_path")) == _manifest.tutorial_video_path,
			"A CPU-controlled second seat must fall back to the primary tutorial clip."
		)
		_expect(
			str(instructions.call("_selected_tutorial_poster_path")) == _manifest.tutorial_poster_path,
			"A CPU-controlled second seat must fall back to the primary tutorial poster."
		)
		await _close(instructions)


func _solo_choice_button(screen: Node, key: String, value: int) -> Button:
	return _find_solo_choice(screen.get_node("%SoloSetupChoices"), key, value)


func _find_solo_choice(node: Node, key: String, value: int) -> Button:
	if node is Button:
		var button := node as Button
		if (
			str(button.get_meta("setting_key", "")) == key
			and int(button.get_meta("choice_value", -9999)) == value
		):
			return button
	for child: Node in node.get_children():
		var found := _find_solo_choice(child, key, value)
		if found != null:
			return found
	return null


func _press(screen: Node, path: String) -> void:
	(screen.get_node(path) as Button).emit_signal("pressed")


func _visible_copy(node: Node) -> String:
	var result := ""
	if node is Control and not (node as Control).is_visible_in_tree():
		return result
	if node is Label:
		result += (node as Label).text + "\n"
	elif node is Button:
		result += (node as Button).text + "\n"
	for child: Node in node.get_children():
		result += _visible_copy(child)
	return result


func _open(path: String) -> Node:
	var packed := load(path) as PackedScene
	_expect(packed != null, "The setup scene must load: %s." % path)
	if packed == null:
		return null
	var screen := packed.instantiate()
	get_root().add_child(screen)
	await process_frame
	await process_frame
	return screen


func _close(screen: Node) -> void:
	if is_instance_valid(screen):
		screen.queue_free()
		await process_frame


func _restore_state() -> void:
	_save_timer.stop()
	_settings.set("_values", _saved_values.duplicate(true))
	for property: String in _saved_session:
		_session.set(property, _saved_session[property])
	_router.set("_busy", _saved_router_busy)
	_manifest.supports_multiplayer = bool(_saved_manifest.get("supports_multiplayer", true))
	_manifest.solo_setup_choices = (
		_saved_manifest.get("solo_setup_choices", []) as Array[String]
	).duplicate()
	GameCatalog.select(_saved_game)
	for action: StringName in _original_actions:
		var saved: Dictionary = _original_actions[action]
		if not bool(saved["exists"]):
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action, float(saved["deadzone"]))
		else:
			InputMap.action_set_deadzone(action, float(saved["deadzone"]))
		InputMap.action_erase_events(action)
		for event: InputEvent in saved["events"]:
			InputMap.action_add_event(action, event)
	_save_timer.process_mode = _save_timer_mode
	if _save_timer_remaining > 0.0:
		_save_timer.start(_save_timer_remaining)
	_save_timer.wait_time = _save_timer_wait


func _settings_hash_now() -> String:
	return (
		FileAccess.get_sha256(Settings.SAVE_PATH)
		if FileAccess.file_exists(Settings.SAVE_PATH)
		else ""
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Anti-Chess setup tests passed.")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
