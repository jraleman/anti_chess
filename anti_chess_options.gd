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

const FINISH_CLASSIC := "chess_classic"
const FINISH_BRONZE := "chess_bronze"
const FINISH_SILVER := "chess_silver"
const FINISH_GOLD := "chess_gold"
const FINISH_PLATINUM := "chess_platinum"
const FINISH_DIAMOND := "chess_diamond"
const FINISH_SLOTS: Array[String] = ["chess_finish_p1", "chess_finish_p2"]
const STORE_CURRENCY := {
	"name": "Coin",
	"plural": "Coins",
	"points_per_score": 2.0,
	"round_bonus": 10,
	"win_bonus": 15,
	"max_per_round": 60,
}
const STORE_SLOTS: Array[Dictionary] = [
	{
		"id": FINISH_SLOTS[0], "kind": "piece_finish", "title": "P1 / You",
		"description": "Your pieces in solo, or White's pieces in local play. Next match.",
	},
	{
		"id": FINISH_SLOTS[1], "kind": "piece_finish", "title": "P2 / CPU",
		"description": "The CPU's pieces in solo, or Black's pieces in local play. Next match.",
	},
]

## The first default dresses both seats; the other defaults are owned starter colours.
## Material fields are game-owned; the shared store only handles price and ownership.
const STORE_ITEMS: Array[Dictionary] = [
	{
		"id": FINISH_CLASSIC, "kind": "piece_finish", "title": "Classic",
		"description": "Ivory for White, ink for Black. The original two-tone set.",
		"price": 0, "default": true, "badge": "CLASSIC",
		"color": Color("d6c7ad"), "heading": "Starter colours",
	},
	{
		"id": "chess_ivory", "kind": "piece_finish", "title": "Ivory",
		"description": "Warm, polished ivory for either player's whole set.",
		"price": 0, "default": true, "badge": "IVORY",
		"color": Color("e5d7bb"), "heading": "Starter colours",
	},
	{
		"id": "chess_ink", "kind": "piece_finish", "title": "Ink",
		"description": "Deep violet-black lacquer with a satin sheen.",
		"price": 0, "default": true, "badge": "INK",
		"color": Color("51415e"), "heading": "Starter colours",
	},
	{
		"id": "chess_jade", "kind": "piece_finish", "title": "Jade",
		"description": "A cool green glaze, inspired by the salon's chess table.",
		"price": 0, "default": true, "badge": "JADE",
		"color": Color("429b80"), "heading": "Starter colours",
	},
	{
		"id": "chess_ruby", "kind": "piece_finish", "title": "Ruby",
		"description": "Rich red lacquer with the same readable player-colour rings.",
		"price": 0, "default": true, "badge": "RUBY",
		"color": Color("b9435b"), "heading": "Starter colours",
	},
	{
		"id": "chess_sapphire", "kind": "piece_finish", "title": "Sapphire",
		"description": "A royal blue glaze for your knights and their court.",
		"price": 0, "default": true, "badge": "BLUE",
		"color": Color("457fc7"), "heading": "Starter colours",
	},
	{
		"id": FINISH_BRONZE, "kind": "piece_finish", "title": "Bronze",
		"description": "Warm cast bronze, polished along the turned edges.",
		"price": 60, "badge": "BRONZE", "color": Color("b97943"),
		"metallic": 0.65, "roughness": 0.32, "heading": "Precious finishes",
	},
	{
		"id": FINISH_SILVER, "kind": "piece_finish", "title": "Silver",
		"description": "Cool silver with bright, softly brushed highlights.",
		"price": 120, "badge": "SILVER", "color": Color("b9c5d2"),
		"metallic": 0.75, "roughness": 0.27, "heading": "Precious finishes",
	},
	{
		"id": FINISH_GOLD, "kind": "piece_finish", "title": "Gold",
		"description": "A golden court. Bought once, wearable by either player.",
		"price": 200, "badge": "GOLD", "color": Color("e5b653"),
		"metallic": 0.78, "roughness": 0.23, "heading": "Precious finishes",
	},
	{
		"id": FINISH_PLATINUM, "kind": "piece_finish", "title": "Platinum",
		"description": "Pale, lustrous platinum with a crisp polished finish.",
		"price": 320, "badge": "PLAT", "color": Color("deebe7"),
		"metallic": 0.8, "roughness": 0.18, "heading": "Precious finishes",
	},
	{
		"id": FINISH_DIAMOND, "kind": "piece_finish", "title": "Diamond",
		"description": "Ice-blue, gem-cut facets. A solid finish, never an invisible piece.",
		"price": 500, "badge": "GEM", "color": Color("a9e1f2"),
		"metallic": 0.3, "roughness": 0.14, "faceted": true,
		"heading": "Precious finishes",
	},
]

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
