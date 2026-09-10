extends RefCounted

## Preload-safe option and shared-input declarations for the chessboard.
## Gameplay reads these same keys; the host owns persistence and rebinding.

const GAME_ID := "anti_chess"

const CPU_DIFFICULTY_KEY := "game/anti_chess_cpu_difficulty"
const PLAYER_SIDE_KEY := "game/anti_chess_player_side"
const SHOW_HINTS_KEY := "game/anti_chess_show_hints"
const PIECE_LABELS_KEY := "game/anti_chess_piece_labels"

const CPU_EASY := 0
const CPU_THOUGHTFUL := 1
const CPU_CUNNING := 2
const PLAYER_WHITE := 0
const PLAYER_BLACK := 1
const DEFAULT_CPU_DIFFICULTY := CPU_THOUGHTFUL
const DEFAULT_PLAYER_SIDE := PLAYER_WHITE
const DEFAULT_SHOW_HINTS := true
const DEFAULT_PIECE_LABELS := true

const CURSOR_UP_KEY := "controls/anti_chess_up"
const CURSOR_DOWN_KEY := "controls/anti_chess_down"
const CURSOR_LEFT_KEY := "controls/anti_chess_left"
const CURSOR_RIGHT_KEY := "controls/anti_chess_right"
const CAMERA_UP_KEY := "controls/anti_chess_camera_up"
const CAMERA_DOWN_KEY := "controls/anti_chess_camera_down"
const CAMERA_LEFT_KEY := "controls/anti_chess_camera_left"
const CAMERA_RIGHT_KEY := "controls/anti_chess_camera_right"
const CAMERA_RESET_KEY := "controls/anti_chess_camera_reset"
const SELECT_KEY := "controls/anti_chess_select"
const CANCEL_KEY := "controls/anti_chess_cancel"
const FLIP_KEY := "controls/anti_chess_flip"

const CURSOR_UP_ACTION := &"anti_chess_up"
const CURSOR_DOWN_ACTION := &"anti_chess_down"
const CURSOR_LEFT_ACTION := &"anti_chess_left"
const CURSOR_RIGHT_ACTION := &"anti_chess_right"
const CAMERA_UP_ACTION := &"anti_chess_camera_up"
const CAMERA_DOWN_ACTION := &"anti_chess_camera_down"
const CAMERA_LEFT_ACTION := &"anti_chess_camera_left"
const CAMERA_RIGHT_ACTION := &"anti_chess_camera_right"
const CAMERA_RESET_ACTION := &"anti_chess_camera_reset"
const SELECT_ACTION := &"anti_chess_select"
const CANCEL_ACTION := &"anti_chess_cancel"
const FLIP_ACTION := &"anti_chess_flip"

const CONTROL_HEADING := "Shared chessboard"
const BOARD_CONTROL_HEADING := "Board squares"
const CAMERA_CONTROL_HEADING := "Camera"

const TUNABLES: Array[Dictionary] = [
	{
		"key": CPU_DIFFICULTY_KEY,
		"type": GameManifest.OPTION_CHOICE,
		"default": DEFAULT_CPU_DIFFICULTY,
		"title": "CPU difficulty",
		"description": (
			"Choose how the CPU plans its moves in single-player. "
			+ "Applies next match."
		),
		"heading": "Anti-Chess - next match",
		"choices": [
			{"value": CPU_EASY, "title": "Casual"},
			{"value": CPU_THOUGHTFUL, "title": "Thoughtful"},
			{"value": CPU_CUNNING, "title": "Cunning"},
		],
	},
	{
		"key": PLAYER_SIDE_KEY,
		"type": GameManifest.OPTION_CHOICE,
		"default": DEFAULT_PLAYER_SIDE,
		"title": "Play as",
		"description": (
			"Solo only. White moves first; the CPU takes the other colour. "
			+ "Next match."
		),
		"heading": "Anti-Chess - next match",
		"choices": [
			{
				"value": PLAYER_WHITE,
				"title": "White (you move first)",
				"summary_title": "White",
			},
			{
				"value": PLAYER_BLACK,
				"title": "Black (CPU moves first)",
				"summary_title": "Black",
			},
		],
	},
	{
		"key": SHOW_HINTS_KEY,
		"type": GameManifest.OPTION_TOGGLE,
		"default": DEFAULT_SHOW_HINTS,
		"title": "Legal-move hints",
		"description": (
			"Show legal-destination dots. Changes immediately; mandatory "
			+ "captures are always announced and enforced, even with dots off."
		),
		"heading": "Anti-Chess - live",
	},
	{
		"key": PIECE_LABELS_KEY,
		"type": GameManifest.OPTION_TOGGLE,
		"default": DEFAULT_PIECE_LABELS,
		"title": "Piece letters",
		"description": (
			"Add P/N/B/R/Q/K letters to the 3D silhouettes. "
			+ "Changes immediately."
		),
		"heading": "Anti-Chess - live",
	},
]

## Both seats use one board cursor; there are no separate player key clusters.
const CONTROL_BINDINGS: Array[Dictionary] = [
	{
		"key": CURSOR_UP_KEY,
		"action": CURSOR_UP_ACTION,
		"default": KEY_W,
		"title": "Cursor up",
		"description": "Move the shared square cursor toward the top of the board.",
		"player": -1,
		"movement": true,
		"heading": BOARD_CONTROL_HEADING,
	},
	{
		"key": CURSOR_DOWN_KEY,
		"action": CURSOR_DOWN_ACTION,
		"default": KEY_S,
		"title": "Cursor down",
		"description": "Move the shared square cursor toward the bottom of the board.",
		"player": -1,
		"movement": true,
		"heading": BOARD_CONTROL_HEADING,
	},
	{
		"key": CURSOR_LEFT_KEY,
		"action": CURSOR_LEFT_ACTION,
		"default": KEY_A,
		"title": "Cursor left",
		"description": "Move the shared square cursor left on the board.",
		"player": -1,
		"movement": true,
		"heading": BOARD_CONTROL_HEADING,
	},
	{
		"key": CURSOR_RIGHT_KEY,
		"action": CURSOR_RIGHT_ACTION,
		"default": KEY_D,
		"title": "Cursor right",
		"description": "Move the shared square cursor right on the board.",
		"player": -1,
		"movement": true,
		"heading": BOARD_CONTROL_HEADING,
	},
	{
		"key": SELECT_KEY,
		"action": SELECT_ACTION,
		"default": KEY_ENTER,
		"title": "Select piece / destination",
		"description": "Select your piece, then confirm a legal destination.",
		"player": -1,
		"movement": false,
		"heading": BOARD_CONTROL_HEADING,
	},
	{
		"key": CANCEL_KEY,
		"action": CANCEL_ACTION,
		"default": KEY_BACKSPACE,
		"title": "Cancel selection",
		"description": "Clear the selected piece without making a move.",
		"player": -1,
		"movement": false,
		"heading": BOARD_CONTROL_HEADING,
	},
	{
		"key": FLIP_KEY,
		"action": FLIP_ACTION,
		"default": KEY_F,
		"title": "Flip board",
		"description": (
			"View the board from the other side. Turns never flip it for you."
		),
		"player": -1,
		"movement": false,
		"heading": BOARD_CONTROL_HEADING,
	},
	{
		"key": CAMERA_UP_KEY,
		"action": CAMERA_UP_ACTION,
		"default": KEY_UP,
		"title": "Camera up",
		"description": "Orbit or pan the camera upward.",
		"player": -1,
		"movement": false,
		"heading": CAMERA_CONTROL_HEADING,
	},
	{
		"key": CAMERA_DOWN_KEY,
		"action": CAMERA_DOWN_ACTION,
		"default": KEY_DOWN,
		"title": "Camera down",
		"description": "Orbit or pan the camera downward.",
		"player": -1,
		"movement": false,
		"heading": CAMERA_CONTROL_HEADING,
	},
	{
		"key": CAMERA_LEFT_KEY,
		"action": CAMERA_LEFT_ACTION,
		"default": KEY_LEFT,
		"title": "Camera left",
		"description": "Orbit or pan the camera left.",
		"player": -1,
		"movement": false,
		"heading": CAMERA_CONTROL_HEADING,
	},
	{
		"key": CAMERA_RIGHT_KEY,
		"action": CAMERA_RIGHT_ACTION,
		"default": KEY_RIGHT,
		"title": "Camera right",
		"description": "Orbit or pan the camera right.",
		"player": -1,
		"movement": false,
		"heading": CAMERA_CONTROL_HEADING,
	},
	{
		"key": CAMERA_RESET_KEY,
		"action": CAMERA_RESET_ACTION,
		"default": KEY_HOME,
		"title": "Reset camera",
		"description": "Restore the default view for the current mode.",
		"player": -1,
		"movement": false,
		"heading": CAMERA_CONTROL_HEADING,
	},
]
