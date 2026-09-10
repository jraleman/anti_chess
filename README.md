# Anti-Chess

**Give it all away.** An untimed losing-chess game on an original 3D,
jade-and-brass chess table. It uses the host project's `gl_compatibility`
renderer and inherits `GameShell`: menus, settings, pause, results, scorecards
and achievements remain part of the shared framework.

From `godot-base`:

```powershell
godot --path . -- --game=anti_chess
```

From this folder:

```powershell
godot --path ..\.. -- --game=anti_chess
```

The existing catalog discovers `game.gd`. A standalone launch wears this
game's logo, brass/jade menu skin and checkerboard backdrop, plays its
skippable opening, and exposes its own Controls and Game settings.
`--game=all` also includes it in the collection picker.

## Rules and modes

- **Single Player:** choose White or Black before starting; the CPU takes the
  other side. **White always moves first**, including a White CPU opening.
- **Local Multiplayer:** two humans alternate turns on the same device.
  There is no multiplayer CPU selector. Mobile uses solo play and still offers
  the colour choice.
- Pieces move as in chess, but **every available capture is compulsory**.
  When several captures exist, choose any one.
- There is no check, checkmate or castling. Kings can be captured and have no
  special protection. Pawns can double-step from their starting rank and
  capture en passant.
- Promotion offers **queen, rook, bishop, knight or king**. A human chooses
  before the move is committed; cancelling leaves the pawn unmoved.
- **Win by having no pieces, or no legal moves on your turn.**
  Material totals do not override that result.
- A third repetition, or 100 consecutive plies without a pawn move or capture,
  automatically draws. A win takes precedence. There is no insufficient-material
  draw and no match clock.

The shared Timer/Lives preference is preserved but not used. The manifest's
generic `uses_shell_round_rules = false` capability hides arcade round modifiers
and keeps the shell from starting a countdown. Resigning requires confirmation
and awards the opponent the win; abandoning through the pause menu records no result.

## Controls and accessibility

Click or tap a piece, then a destination. Keyboard defaults are **WASD** to
browse squares, **Enter** to select/move and **Backspace** to cancel.
**Right-mouse drag or held arrow keys** move the camera; the **mouse wheel**
zooms. **Home** or **Reset View** restores the starting view, and **F** flips
the board. **Esc** opens the shared pause overlay. Both humans share the
controls; all twelve board/camera keys are rebindable in Settings.

Solo starts at a slightly frontal angle facing the human's chosen colour and
lets the camera orbit. Local play starts exactly overhead; camera movement
pans without tilting, including after a flip. Zoom, pan and elevation are
bounded, survive window resizes, and never move the pieces. WASD follows the
nearest visible board axes after an orbit or flip. Camera controls work during
CPU turns, but not behind pause/decision dialogs or while navigating sidebar
buttons with the keyboard.

Old saved arrow-cursor bindings conflict with the new camera arrows. The host's
existing per-game binding repair resets that conflicting Anti-Chess control
profile to the new defaults, without changing other games. Nonconflicting
custom bindings are retained.

Legal destinations use dots, captures have outlines, and the turn panel always
spells out a compulsory capture. White/Black names, optional P1/P2 labels,
different piece materials, player-colour base rings and optional P/N/B/R/Q/K
badges supplement the silhouettes. The ledger records coordinate notation,
promotions and en passant. The board remains visible above the ledger in portrait.

Settings offers three CPU levels: **Casual**, **Thoughtful** and **Cunning**.
The latter two search replies using a bounded, incremental losing-chess search;
the CPU never bypasses the model's legal-move path. Difficulty and **Play as**
apply next match; replay adopts them without changing players mid-match.
Legal-move hints and piece-letter badges change live.

Reduced motion settles piece movement and camera flips immediately, while keeping
direct user-controlled camera movement. There is
no ambient camera movement or game-critical sound-only information. Captures,
promotions and results receive captions through `AudioManager`; its volume and
mute settings apply to all cues. CPU thinking and the scene-owned final-move
hold pause with the scene and are cancelled on replay or exit.

The HUD counts **pieces left**. Results count **pieces given away**; the
headline still follows the actual win rule, including a blocked player winning
with pieces remaining. Scorecards carry both scores, both sides' remaining
pieces and the same move count, including in solo CPU matches. P1 always denotes
the human in solo, so a Black human's scores, statistics, colour and achievements
stay with P1; the artwork's White/Black piece counts remain explicitly labelled.
Their QR links
to the studio website, not an invented stats service.

## Source and assets

| Path | Responsibility |
| --- | --- |
| `game.gd`, `anti_chess_options.gd` | Manifest, standalone identity, copy and constants-only settings |
| `board/chess_state.gd`, `board/cpu_player.gd` | Node-free rules and seeded CPU; no autoload access |
| `board/chess_mesh.gd` | Original lathed/constructed chessmen and batched table geometry |
| `board/board_view.gd`, `board/chess_camera.gd` | Read-only 3D world, batched pieces, captured-piece trays and mode-specific camera |
| `ui/board_input.gd` | Plane-based picking and native-resolution, focusable board overlay |
| `ui/match_panel.gd`, `ui/match_dialog.gd` | Turn briefing, scrollable ledger and explicit decisions |
| `gameplay.gd`, `gameplay.tscn` | Inherited shell integration and match lifecycle |
| `assets`, `ui/menu_*`, `intro.tscn` | Original vector identity, menu resources and opening |
| `tools/render_audio.gd` | Offline authoring of four original PCM cues, with no external samples |
| `tools/tutorial_driver.gd` | Game-owned solo/local lessons driving the actual match and camera |

The geometry, vector artwork and short ceramic/wood sounds are original source
assets. No models, fonts, samples, plugins or rendering extensions are downloaded.
The 3D view batches tiles and pieces and targets at most **100 draw calls including
shadows**, measured by the graphical regression.

## Development

The instructions screen selects the solo or local walkthrough and its matching
poster. The game picker uses the solo clip. These are muted, captioned Theora
videos in the host's `assets\video` folder; reduced motion parks them on a still.
Lessons show the actual controls, compulsory captures, ordinary kings, promotion
and giving away the last piece. Small teaching positions are explicitly labelled
as practice positions, rather than making pieces disappear without explanation.

Re-record both clips from this folder after changing visuals or captions:

```powershell
pwsh ..\..\tools\record_tutorials.ps1 -Games anti_chess -Godot (Get-Command godot).Source
godot --headless --path ..\.. --import
```

The recorder uses a unique temporary capture directory and isolated user profile
per invocation, keeps other games' clips untouched, and publishes only completed
encodes. Exclude `tools/*` and `games/*/tools/*` from exports;
the shipped videos do not depend on the recording scripts.

From this folder, regenerate the included sounds after changing their source:

```powershell
godot --headless --path ..\.. --script res://games/anti_chess/tools/render_audio.gd -- --game=all
godot --headless --path ..\.. --import
```

Run the existing Godot `SceneTree` test style, sequentially:

```powershell
godot --headless --path ..\.. --script res://games/anti_chess/tests/chess_state_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/anti_chess/tests/cpu_player_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/anti_chess/tests/anti_chess_scene_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/anti_chess/tests/anti_chess_setup_test.gd -- --game=all
godot --headless --path ..\.. --script res://games/anti_chess/tests/tutorial_driver_test.gd -- --game=all
godot --audio-driver Dummy --path ..\.. --script res://games/anti_chess/tests/board_view_test.gd -- --game=all
```

The last command requires a graphics window; headless output is not visual coverage.
Add `--anti-chess-capture-dir=<absolute directory>` after `--` to save landscape,
portrait, wide, both solo colours, orbit/pan, compulsory-capture, promotion,
results, scorecard and title-screen images.
The scene fixture suppresses achievement/progression writes and restores settings.
Run shared framework coverage with an isolated user profile: some host tests
deliberately complete real rounds and exercise persistence.

Affected shared coverage includes `game_shell_test.gd`, `lives_mode_test.gd`,
`game_options_test.gd`, `custom_keys_test.gd`, `instructions_video_test.gd`,
`game_select_test.gd`, and
`single_game_test.gd`. The last also runs with `--game=anti_chess` to exercise
the actual standalone launch.
