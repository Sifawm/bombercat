# Spec: Match Loading Screen

- **Status:** ready-for-agent
- **Date:** 2026-11-21
- **Vocabulary:** [CONTEXT.md](../CONTEXT.md) — use these terms exactly, in code and in prose.

## Problem Statement

When a Player confirms a Map on Map Select to start a local Match, starts a Rematch from Match Result, or enters an online Match from Configure Match in a Room, the screen fades to black and freezes before the arena appears. During that black screen, the game loads the Map, builds the 3D mesh palette, instantiates the Floor, Walls, Crates, Portals, Powerup models, HUD, audio and Cats, and compiles the 3D shaders on the first rendered frame.

Because the Cats' drop-in animation onto their Spawn Points starts at the exact same moment the scene is added to the tree—while the screen is still black and before the first 3D frame stall has finished—the frame spike consumes a large portion of the 0.7-second drop tween. By the time the black curtain clears, the Cats appear to stutter or teleport partway down (or already bouncing on the Floor) rather than falling smoothly from the sky, and the Player is left staring at an unresponsive black screen with no indication of what the game is doing.

## Solution

Replace the black transition into a Match with an intermediate Match loading screen that reuses the visual identity of the game's initial Splash screen: the drifting clouds over the sky backdrop, the animated swaying Bomb with its flickering fuse spark and rotating burst, the BomberCat wordmark, and the yellow progress bar with its travelling shine, without the `"Made with Godot"` footer.

The Match loading screen appears immediately when a Match starts (from Map Select, a local Rematch, or when an online Match begins in a Room) so the Player never sees a black frame. Below the progress bar, an animated phase label with cycling ellipsis dots (`...`) tells the Player what is happening in English, matching the rest of the game's UI:

1. `"Loading map..."` while loading the Map scene, the Map mesh palette, the Map's Floor models, the models for the Map's Powerup Pool, and the Round music.
2. `"Building arena..."` while instantiating the Round view (and receiving the initial Round sync in an online Room), placing the Map, Crates, Portals, HUD and Cats at their initial drop height above their Spawn Points.
3. `"Warming up..."` while pre-warming the 3D shaders and rendering the fully built arena behind the loading screen for a couple of frames so all GPU uploads and shader compilations finish unseen.

While the Match loading screen covers the arena, the Cats wait at the top of their drop height, the Round music waits, and the countdown does not advance. Once progress reaches 100% and the arena has rendered behind the overlay, the Match loading screen fades out smoothly over ~0.25 seconds and releases the Round start gate: the Round music starts, the Cats fall smoothly from the sky onto their Spawn Points from the very beginning of their bounce curve, and the `"3, 2, 1, Go!"` countdown follows. Transitions between subsequent Rounds of the same Match (`Round 1` to `Round 2`, and so on) remain direct and do not show the loading screen.

## User Stories

### Visual design and immediate feedback

1. As a Player confirming a Map on Map Select, I want the Match loading screen to appear immediately without fading to a black screen first, so that the game never looks frozen or broken.
2. As a Player looking at the Match loading screen, I want it to share the visual design of the initial Splash screen (sky and drifting clouds, rotating burst, swaying Bomb with flickering fuse spark, wordmark, and yellow progress bar with a moving shine), so that the loading experience feels cohesive with the rest of the game.
3. As a Player looking at the Match loading screen, I want the `"Made with Godot"` footer omitted during in-game Match loading, so that engine credits are only shown once when launching the application.
4. As a Player watching the Match loading screen, I want the clouds, burst, Bomb sway, fuse spark and bar shine to keep animating smoothly across frames while loading progresses, so that I can see the game is alive and responsive.
5. As a Player watching the Match loading screen, I want the progress bar to advance smoothly from start to full without jumping backwards, so that I can gauge how close the Match is to starting.
6. As a Player watching the Match loading screen, I want the phase label below the progress bar to animate its trailing three dots (`...`) without shifting the centred text horizontally, so that the label matches the initial Splash screen's polish.

### Loading phases and progress reporting

7. As a Player entering a Match, I want the loading screen to display `"Loading map..."` while the Map scene, mesh library, Floor models, Powerup Pool models and Round music are being loaded, so that I know the Map's assets are being fetched.
8. As a Player entering a Match, I want the loading screen to advance to `"Building arena..."` while the 3D board, Crates, Portals, HUD and Cats are being assembled (and while the initial Round state is synced in an online Room), so that I can see loading move from asset fetching to scene setup.
9. As a Player entering a Match, I want the loading screen to advance to `"Warming up..."` while the 3D scene and effect shaders are rendered behind the overlay, so that shader compilation happens before the curtain opens.
10. As a Player, I want all phase labels on the Match loading screen to be written in English, so that they are consistent with every other screen in the game.

### Eliminating the black screen and the Cat drop-in stutter

11. As a Player entering a Match, I want the 3D arena (including the Map, Crates, Portals, Cats and hidden shader warm-up nodes for Bombs, Explosions, particles, glow and Powerups) to be added to the scene tree and drawn for at least two rendered frames behind the loading screen before the loading screen fades out, so that the first-frame GPU upload and shader compilation stall is completely hidden.
12. As a Player entering a Match, I want the Cats to stay held at their initial drop height (`DROP_HEIGHT`) while the Match loading screen is still preparing and warming up the arena, so that no part of their fall happens unseen behind the loading screen.
13. As a Player entering a Match, I want the Cats' drop-in animation to start at the moment the Match loading screen finishes and begins its fade-out, so that I see the entire fall and bounce onto the Spawn Points without any cut or frame skip.
14. As a Player entering a Match, I want the `"3, 2, 1, Go!"` countdown to wait until the Match loading screen releases the Round start gate and the Cats begin their drop-in, so that the countdown timing is never eaten by asset loading or shader compilation.
15. As a Player entering a Match, I want the Round music to start when the arena is revealed rather than blasting during an earlier stall, so that the audio cue lines up with the Cats dropping into the Round.
16. As a Player when the Match loading screen finishes, I want it to fade out smoothly over a short duration (~0.25 seconds) directly revealing the rendered 3D arena underneath, so that the transition into the Match feels seamless.

### Scope across local Matches, Rematches, online Rooms and multi-Round play

17. As a local Player starting a Match from Map Select on `backyard`, `living_room` or `rooftops`, I want the Match loading screen to guide the transition into the first Round, so that every Map enters smoothly regardless of how many furniture, roof or Portal meshes it uses.
18. As a local Player choosing Rematch on the Match Result screen, I want the transition back into the new Match to use the same smooth loading flow without a black screen or cut in the Cats' drop-in animation, so that rematches feel just as polished as the first Match.
19. As an online User in a Room when the Admin starts a Match from Configure Match (or starts a Rematch from the online Match Result screen), I want the Match loading screen to cover the transition while the client waits for the server's initial Round state, builds the arena and warms up shaders, so that online Matches never show an empty black viewport while waiting for the server sync.
20. As an online User in a Room whose client finishes loading and warming up the arena, I want my Cats to play their drop-in animation cleanly as the loading screen fades out while keeping the Round countdown aligned with the Room's server timer, so that the visual entrance is smooth and gameplay stays synchronised across Users.
21. As a Player finishing Round 1 of a Match and advancing automatically to Round 2 (or any subsequent Round within the same Match), I want the next Round to start directly inside the arena without showing the Match loading screen, so that multi-Round pacing stays fast once the Map and shaders are already in memory.
22. As a Player navigating between non-Match menu screens (Title screen, Cat Select, Map Select, Online Entry, Waiting Room, Configure Match, Match Result), I want normal menu transitions to remain quick and responsive without showing the Match loading screen, so that the loading screen is reserved for entering a Match.
23. As a Player pressing gameplay or pause keys while the Match loading screen is still active, I want gameplay inputs and pausing to be ignored until the loading screen releases the Round, so that a Player cannot open the Pause menu or buffer stray actions behind the loading overlay.

## Implementation Decisions

### Visual reuse of the Splash presentation

- The Match loading overlay shares the visual building blocks of the initial Splash screen:
  - Full-screen sky backdrop with drifting clouds.
  - Centred 1920×1080 design frame containing the rotating burst, the swaying Bomb with its additive radial-gradient fuse spark, and the BomberCat wordmark.
  - The bordered cream progress track with its hard ink shadow, yellow fill bar, and diagonally clipped moving shine polygon.
  - The centred phase label below the bar using the semibold UI font and `VC_CHARS_AFTER_SHAPING` character visibility so cycling the three trailing dots (`...`) never shifts the label horizontally.
- Unlike the startup Splash screen, the in-game Match loading screen omits the `"Made with Godot"` footer label, starts with the logo and Bomb already in their active loop (no multi-second startup pop-in intro or artificial 2-second minimum hold), and fades itself out directly over the live 3D arena instead of fading to a black curtain.

### Phased loading coordinator and real work distribution

- Entering a Match runs through a dedicated Match loading coordinator that drives the loading overlay across three explicit phases and advances a normalized progress value from `0.0` to `1.0`:
  1. **Phase 1 — `"Loading map..."`:**
     - Resolves the list of resources needed for the Match on the chosen Map: the Map scene, the Map mesh palette items, the Map's Floor models, the Powerup models referenced by the Map's Powerup Pool, the Cat models for the participating Players, and the Round music stream.
     - Steps through loading and preparing those resources across frames (or via threaded/incremental resource requests and palette item preparation) so the main loop continues running and the loading screen's animations and progress bar update smoothly every frame.
  2. **Phase 2 — `"Building arena..."`:**
     - Instantiates the Round view (`RoundView` locally or `OnlineRoundView` in an online Room) underneath the loading overlay while keeping the Round in its held pre-drop state.
     - For a local Match, builds the Map node, Floor multimeshes, Crates, Portals, HUD, shader warm-up stash, and places the Cat views at `DROP_HEIGHT` above their Spawn Points without starting their drop tween or the Round countdown.
     - For an online Match, waits until the client has received the initial Round state from the server (`roundStarted` or `synced`) and has constructed the 3D arena and Cat views in the same pre-drop state.
  3. **Phase 3 — `"Warming up..."`:**
     - With the 3D arena constructed and visible to the renderer behind the opaque 2D loading overlay (in a higher canvas layer), waits for at least two rendered frames (`frame_post_draw`) so the engine compiles all 3D materials, skinning shaders, lighting, particles and warm-up meshes while still covered by the loading screen.
- When Phase 3 completes and the progress bar reaches `1.0`, the coordinator releases the Round start gate on the Round view and fades the loading overlay's opacity to `0.0` over `0.25` seconds before freeing the overlay.

### Round start gate and Cat drop-in synchronisation

- The Round view supports a gated start for its first Round when entered through the Match loading screen:
  - Building the Round places every Cat model at `DROP_HEIGHT` (`9.0` m) above its Spawn Point and sets the initial countdown timer (`DROP_SECONDS + COUNTDOWN_SECONDS`), but while the start gate is held:
    - The Cat views do not start their `drop()` bounce tween yet (they remain posed at `DROP_HEIGHT`).
    - `_physics_process` does not decrement the countdown or step the Round rules.
    - Pause requests are ignored while the loading overlay is active.
  - When the Match loading screen completes Phase 3 and begins its `0.25`-second fade-out, it calls the Round view's release method:
    - Each Cat view starts its `drop()` tween from `DROP_HEIGHT` to `0.0` on a freshly warmed-up frame with normal frame delta.
    - The Round music begins playing.
    - The countdown begins ticking (locally from `DROP_SECONDS + COUNTDOWN_SECONDS`, or online synchronised with the server's countdown timer while ensuring the local Cat drop animation plays smoothly on entry).
- Subsequent Rounds within the same Match (`_after_result` advancing to the next Round) bypass the loading screen and release the drop-in, music and countdown immediately as before, because the Map, models and shaders are already loaded and compiled in the active scene.

### Architecture and layer boundaries (ADR 0002, ADR 0003)

- The rules layer (`Board`, `CatState`, `Movement`, `Bomb`, `Powerup`, `Round`, `Match`) and the online server rules remain completely untouched. The Match loading screen and the Round start gate live strictly in the presentation layer.

## Testing Decisions

- **What makes a good test:** A test drives the loading coordinator and Round start gate through their public interface—feeding phase transitions, resource steps, arena readiness, warm-up frame completions and time deltas—and asserts on observable outputs (current phase label, normalized progress value, whether loading is finished, Cat vertical position at `DROP_HEIGHT` versus dropping, and whether the countdown advances), without coupling to internal node hierarchies or private tween implementation details.
- **The single seam:** The Match loading progression state and Round start gate, tested headless through the existing test runner (`RulesTestCase`):
  1. **Ordered phase labels and monotonic progress:** Advancing through asset steps, arena build, and warm-up frames transitions the phase text strictly in order (`"Loading map..."` → `"Building arena..."` → `"Warming up..."`) and increases progress monotonically from `0.0` to `1.0`.
  2. **Completion gate conditions:** The loading coordinator does not report completion or release the Round while any asset step remains, while the arena (or online server sync) is not yet built, or before the required warm-up render frames have completed.
  3. **Held drop-in and countdown before release:** While a newly built Round view is held by the loading gate, every Cat remains at `DROP_HEIGHT` and stepping physics does not decrease the countdown timer.
  4. **Release starts drop-in and countdown:** Releasing the gate triggers the Cats' drop from `DROP_HEIGHT` toward the Floor and allows the countdown timer to advance on subsequent steps; advancing to a second Round in the same Match starts the drop-in and countdown immediately without waiting for the gate.
- **Prior art:** The headless rules tests, the Laser Pointer hunt state-machine tests, and the Bluetooth controller roster tests, all inheriting `RulesTestCase` and executed via the project's headless Godot test script.
- **Not automatically tested:** The visual appearance of the fade-out tween and GPU shader compilation frame times on specific hardware, which are verified by running the game on desktop and web.

## Out of Scope

- Changing the initial application startup Splash screen or the HTML/CSS web download splash bar.
- Showing a loading screen between Round 1, Round 2 and subsequent Rounds of the same ongoing Match.
- Showing a loading screen when navigating between 2D menu screens (such as Title to Cat Select or Cat Select to Map Select).
- Modifying server-side Room rules, network protocol messages or server countdown durations.
- Adding tips, lore text, or interactive minigames to the Match loading screen.
- Changing any 3D models, Map layouts or Cat animations in Blender.

## Further Notes

- Preparing `MapPalette` mesh items incrementally during `"Loading map..."` (if not already cached in memory) also prevents any main-thread hitch if a Match is started before all palette models have been instantiated.
- Keeping the loading overlay on a high `CanvasLayer` while the 3D `RoundView` sits in the tree underneath ensures Godot's Compatibility renderer actually draws the 3D viewport during the `"Warming up..."` frames rather than culling it as invisible.
