extends RefCounted

## Anti-Chess owns its salon, rules copy and presentation resources.
## The catalog can discover this manifest before autoload instances exist.

const OPTIONS := preload("res://games/anti_chess/anti_chess_options.gd")
const GAME_ID := OPTIONS.GAME_ID


## Declares an always-available, untimed match without changing shared menus.
static func manifest() -> GameManifest:
	var game := GameManifest.new()
	game.id = GAME_ID
	game.title = "Anti-Chess"
	game.tagline = "Give it all away."
	game.menu_order = 4
	game.gameplay_scene_path = "res://games/anti_chess/gameplay.tscn"
	game.intro_scene_path = "res://games/anti_chess/intro.tscn"
	game.tutorial_video_path = "res://assets/video/tutorial_anti_chess.ogv"
	game.local_tutorial_video_path = "res://assets/video/tutorial_anti_chess_local.ogv"
	game.tutorial_poster_path = "res://assets/video/tutorial_anti_chess_poster.webp"
	game.local_tutorial_poster_path = "res://assets/video/tutorial_anti_chess_local_poster.webp"
	game.share_art_scene_path = "res://games/anti_chess/ui/share_art.tscn"
	game.share_art_style = GAME_ID
	game.stats_url = "https://deskcansaw.com"
	game.supports_single_player = true
	game.supports_multiplayer = true
	game.supports_cpu_opponent = false
	game.uses_shell_round_rules = false
	game.default_lives_mode = false
	game.unlock_rule = null
	game.hidden_until_unlocked = false
	game.control_style = GameManifest.CONTROL_STYLE_CUSTOM_KEYS
	game.tunables = OPTIONS.TUNABLES
	game.control_bindings = OPTIONS.CONTROL_BINDINGS
	game.solo_setup_choices = [OPTIONS.PLAYER_SIDE_KEY]

	var controls := (
		"Click or tap a piece, then its destination, or use the shared "
		+ "square-cursor keys listed below. "
		+ "Select confirms a piece or destination; Cancel clears a choice; "
		+ "Flip changes only the view; Reset camera restores the starting view.\n"
		+ "In solo, right-drag or the camera keys orbit the board. In local "
		+ "multiplayer, the same camera controls stay locked to a top-down pan. "
		+ "The wheel always zooms. Rebind everything in Settings > Controls. "
		+ "Esc pauses."
	)
	var cpu_description := (
		"Single-player seats the CPU on the side you did not choose. "
		+ "Choose Casual, Thoughtful or Cunning in Settings > Game; "
		+ "difficulty changes apply next match."
	)
	var solo_summary := (
		"You play %s and the CPU plays the other side. White moves first. "
		+ "Both sides try to give their pieces away, and both must capture "
		+ "whenever a capture is available. There is no match clock."
	)
	game.copy = {
		"mode_select_intro": "One chessboard. A different way to win.",
		"mode_select_hint": (
			"Single player lets you choose White or Black before the match. "
			+ "Local multiplayer is always two humans on one overhead board."
		),
		"single_player_description": (
			"Choose your colour below. White always starts; the CPU takes "
			+ "the other side."
		),
		"single_player_roster": (
			"You as %s vs CPU"
		),
		"single_player_selection_summary": (
			"Selected: Single Player - You as %s vs CPU."
		),
		"multiplayer_description": (
			"Two humans take turns on the same board with the same shared "
			+ "controls and a true top-down camera."
		),
		"player_one_control_description": (
			"Use the shared square-cursor and camera bindings shown below. "
			+ "White always moves first."
		),
		"player_two_control_description": (
			"On Black's turn, use the same shared square-cursor and camera "
			+ "bindings. A second keyboard is not needed."
		),
		"cpu_opponent_description": cpu_description,
		"solo_confirm_title": "%s vs CPU",
		"solo_confirm_description": "You play %s. White always moves first.",
		"versus_confirm_title": "Two humans, one board",
		"versus_confirm_description": (
			"Two humans alternate White and Black on the same board. "
			+ "The camera stays overhead for both players."
		),
		"instructions_headline": "Lose every piece. Win the game.",
		"instructions_rules": (
			"If any capture is available, you must capture; choose any legal "
			+ "capture. Otherwise make a normal move.\n"
			+ "There is no check, checkmate or castling. Kings are ordinary "
			+ "pieces and can be captured. Pawn doubles and en passant apply.\n"
			+ "On promotion, choose Queen, Rook, Bishop, Knight or King.\n"
			+ "Win by losing all your pieces, or by having no legal move "
			+ "on your turn.\n"
			+ "A third repetition of a position is an automatic draw, as are "
			+ "50 moves by each side without a pawn move or capture. "
			+ "Matches are untimed."
		),
		"instructions_demo_prompt": "GIVE IT ALL AWAY.",
		"instructions_solo_summary": solo_summary,
		"instructions_cpu_summary": solo_summary,
		"instructions_versus_summary": (
			"Two humans alternate as White and Black using one board and "
			+ "the same controls. White moves first. The view stays overhead; "
			+ "use the shared camera bindings to pan, the wheel to zoom and "
			+ "Flip Board when you want the other perspective."
		),
		"instructions_player_one_controls": controls,
		"instructions_player_two_controls": controls,
		"instructions_cpu_controls": cpu_description,
	}
	game.achievements = {
		"anti_chess_first_match": {
			"title": "A Seat at the Table",
			"description": "Finish an Anti-Chess match.",
			"badge": "AC",
		},
		"anti_chess_giveaway": {
			"title": "Nothing Left to Lose",
			"description": "Win as a human by giving away every piece.",
			"badge": "0",
		},
		"anti_chess_outsmarted": {
			"title": "Outsmarted",
			"description": "Win an Anti-Chess match against the CPU.",
			"badge": "CPU",
		},
		"anti_chess_royal_exit": {
			"title": "Royal Exit",
			"description": "Finish a match after one of your kings is captured.",
			"badge": "K",
		},
	}
	game.credits = [
		{
			"heading": "Game Design & Code",
			"lines": ["DeskCanSaw"],
		},
		{
			"heading": "Rules",
			"lines": ["Traditional losing chess (antichess)"],
		},
		{
			"heading": "Board, Models & Vector Art",
			"lines": [
				"Original chess table, salon and pieces - DeskCanSaw",
				"Original vector crest, cover and brass inlays - DeskCanSaw",
			],
		},
		{
			"heading": "Sound",
			"lines": [
				"Original ceramic and wood move, capture and promotion cues",
				"DeskCanSaw - offline-authored PCM with no external samples",
			],
		},
		{
			"heading": "Accessible Play",
			"lines": [
				"Shared, rebindable chessboard controls",
				"Piece letters and player labels supplement the silhouettes",
				"A skippable text opening with no sound-only instructions",
			],
		},
	]
	game.theme = _theme()
	return game


static func _theme() -> GameTheme:
	var theme := GameTheme.new()
	theme.logo_texture_path = "res://games/anti_chess/assets/logo.svg"
	theme.logo_color = Color.WHITE
	# The plaque texture already contains the dark walnut and brass palette.
	theme.plaque_color = Color.WHITE
	theme.accent = Color("e8bd72")
	theme.light = Color("fff0d3")
	theme.background_top = Color("152826")
	theme.background_bottom = Color("090f15")
	theme.background_material = preload("res://games/anti_chess/ui/menu_background.tres")
	theme.plaque_material = preload("res://games/anti_chess/ui/menu_plaque.tres")
	theme.ui_theme = preload("res://games/anti_chess/ui/menu_skin.tres")
	theme.menu_motion = GameTheme.MenuMotion.FIRM
	theme.style_share_card = true
	return theme
