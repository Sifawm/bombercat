# Spec: Bluetooth Controllers

- **Status:** ready-for-agent
- **Date:** 2026-11-21
- **Vocabulary:** [CONTEXT.md](../CONTEXT.md) — use these terms exactly, in code and in prose.

## Problem Statement

A Player who connects a Bluetooth controller to their computer or browser often finds that BomberCat ignores it completely. Many Bluetooth controllers (such as DualSense, DualShock 4, Switch Pro Controller, 8BitDo or generic Bluetooth gamepads on Linux and in web browsers) report a Bluetooth identifier that Godot does not recognise as a known joypad, and the game currently discards every unrecognised device to avoid mistaking keyboards for gamepads.

Even when two Bluetooth controllers are recognised, disconnecting one mid-Match causes a second problem: because controllers are assigned to Player 1 and Player 2 by their position in the list of connected devices, when Player 1's controller drops out (for example, when its battery dies or it goes to sleep), Player 2's controller immediately shifts to Player 1 and starts driving the wrong Cat. Meanwhile, the Round keeps running while a Player cannot move, and Cat Select always shows keyboard keys regardless of whether a Player has a controller connected.

## Solution

BomberCat accepts any real Bluetooth controller paired through the operating system or exposed by the browser's Gamepad API, on desktop (Linux and Windows) and on the web (in local Matches and online Rooms alike). Instead of rejecting every device unknown to Godot's built-in database, the control layer filters out non-gamepad peripherals (keyboards, mice, touchpads and system/consumer controls) by name and gives unrecognised Bluetooth controllers a standard fallback button and axis mapping so their physical controls work out of the box.

Each local Player keeps the controller assigned to them for as long as it stays connected: if Player 1's controller disconnects, Player 2's controller stays with Player 2 and Player 1's place waits for a controller to reconnect. On Cat Select, each Player's control prompts switch live between keyboard keys and gamepad controls as controllers connect and disconnect. During a local Round (including the countdown), if a Player's assigned controller disconnects, the Round pauses automatically and the Pause menu shows a notice naming the Player whose controller was lost. Online Matches in a Room never pause automatically when a controller disconnects.

## User Stories

### Connecting and recognising Bluetooth controllers

1. As a Player, I want to pair my Bluetooth controller in the operating system and have the game use it automatically without an in-game pairing menu, so that I can start playing immediately.
2. As a Player on Linux or Windows desktop, I want my Bluetooth controller to work whether I connect it before launching the game or while the game is already open, so that I never have to restart the game to use a controller.
3. As a Player in a web browser, I want my Bluetooth controller to work through the browser's Gamepad API in both local Matches and online Rooms, so that the web build supports controllers just like desktop.
4. As a Player with a Bluetooth controller whose identifier is not in Godot's built-in controller database, I want the game to still recognise and map my controller, so that standard and generic Bluetooth gamepads are not ignored.
5. As a Player with a keyboard, mouse, touchpad or media control device that the operating system exposes as a joypad device, I want the game to ignore that peripheral when assigning controllers, so that a phantom device never steals Player 1's controller place.
6. As a Player using an Xbox, PlayStation, Switch, 8BitDo or generic Bluetooth controller, I want the controls mapped by physical position (left stick or D-pad to move, south button `A` to place a Bomb or confirm, west button `X` to meow, east button `B` to cancel or go back, and `Start` to pause), so that every controller feels consistent without manual configuration.
7. As a Player, I want my keyboard controls to keep working alongside my Bluetooth controller at the same time, so that I can use either device whenever I want.

### Assigning controllers to Players and keeping assignments stable

8. As Player 1, I want the first connected Bluetooth controller assigned to me and the second to Player 2, so that two local Players can play a Match together on two controllers.
9. As Player 2 playing a local Match with two Bluetooth controllers, I want my controller to stay assigned to Player 2 if Player 1's controller disconnects, so that I do not suddenly take over Player 1's Cat.
10. As Player 1 whose Bluetooth controller disconnected while Player 2's controller stayed connected, I want my controller to be assigned back to Player 1 when I turn it back on, so that I resume controlling my own Cat.
11. As Player 1 whose Bluetooth controller disconnected during a Match, I want to be able to fall back to my keyboard keys immediately if I choose not to reconnect the controller, so that a dead battery never traps the Match.
12. As a Player when a third Bluetooth controller is connected after Player 1 and Player 2 already have controllers, I want the existing two assignments to remain untouched and the third controller to take over only if one of the two Players' controllers disconnects, so that an extra device does not disrupt active Players.
13. As an online Player in a Room, I want any connected Bluetooth controller (as well as either local Player's keyboard bindings) to drive my Cat, so that I can play online with whichever controller is switched on.

### Navigating menus and Cat Select with Bluetooth controllers

14. As a Player, I want to move through the title screen, Map Select, Match Result, Pause menu, How to Play and online Room screens with my Bluetooth controller's stick or D-pad, confirm with `A` and go back with `B`, so that I never need the keyboard or mouse between Rounds.
15. As a Player on Cat Select, I want the footer for my Player to show `[Stick] [D-pad] Move` and `[A] Choose` whenever a Bluetooth controller is assigned to me, so that I can see at a glance that my controller is detected and what buttons to press.
16. As a Player on Cat Select without a controller assigned to me, I want my footer to show my keyboard keys (`[A] [D] Move` and `[Space] Choose` for Player 1; `[left] [right] Move` and `[Enter] Choose` for Player 2), so that the prompt matches the device I am using.
17. As a Player on Cat Select, I want the centre Back prompt to show `[Esc] [B] Back` when at least one Player has a controller connected and `[Esc] Back` when no controller is connected, so that controller Players know how to leave the screen.
18. As a Player on Cat Select who turns on or turns off a Bluetooth controller while looking at the screen, I want my footer prompts and the Back prompt to update immediately, so that I get instant visual confirmation that the connection changed.

### Disconnecting during a Round

19. As a Player in a local Round whose assigned Bluetooth controller disconnects while the Cats are dropping in, during the countdown, or during play, I want the Round to pause automatically, so that my Cat is not killed while my controller is off.
20. As a Player in a local Round that paused because a controller disconnected, I want the Pause menu to show a notice naming which Player's controller disconnected (for example, `"Player 1 controller disconnected"`), so that both Players immediately know why the Round stopped.
21. As a Player looking at the Pause menu after a controller disconnected, I want to be able to reconnect my Bluetooth controller or use the keyboard and press Resume (or `Start` / `Esc`), so that we can continue the Round when ready.
22. As a Player in a local Round that has already finished (while the winner banner is shown), I want a controller disconnecting not to pop open the Pause menu over the Round result, so that the transition to the next Round or Match Result is not interrupted.
23. As a User playing or watching an online Match in a Room, I want a Bluetooth controller disconnecting not to pause the Room's Match automatically, so that one User's wireless hiccup does not freeze the Match for everyone else in the Room.

## Implementation Decisions

### Control layer and architectural boundaries (ADR 0002)

- The rules layer remains completely unaware of input devices, gamepads and connection changes: it continues to receive only movement directions and Bomb placement commands per Player.
- The control layer owns controller detection, filtering, fallback mapping, per-Player assignment and connection-change notifications.
- No controller vibration (rumble) is added.

### Device filtering and fallback mapping for unrecognised Bluetooth controllers

- A connected joypad device is accepted as a valid gamepad if either:
  - Godot already knows its mapping in its internal controller database, and its device name does not match a known non-gamepad peripheral; or
  - Godot does not know its mapping, and its device name does not match a non-gamepad peripheral.
- Non-gamepad peripheral filtering checks the device name case-insensitively and excludes devices matching keyboard, mouse, touchpad, trackpad, consumer control, system control, hotkey, WMI or LED controller descriptors.
- When an accepted device is not known to Godot's internal controller database and has a non-empty GUID, the control layer registers a standard fallback mapping for its GUID so that its primary axes and buttons resolve to standard Godot joypad events:
  - Left stick horizontal and vertical axes (`a0`, `a1`) and D-pad hat/buttons.
  - South button (`b0` -> `JOY_BUTTON_A`), east button (`b1` -> `JOY_BUTTON_B`), west button (`b2` -> `JOY_BUTTON_X`), north button (`b3` -> `JOY_BUTTON_Y`), and start button (`b6` / `b7` / `b9` standard start mapping -> `JOY_BUTTON_START`).
- Because the fallback mapping is registered at the input level, Godot's built-in `ui_*` actions (used by menus) and the per-Player actions (`p1_*`, `p2_*`) both work with the unrecognised Bluetooth controller without custom event loops in every menu.

### Sticky per-Player controller assignment

- The control layer tracks the assigned device ID for each of the two local Players, initialised to an unassigned sentinel (`NO_DEVICE`).
- On startup and whenever a joypad connects or disconnects, the assignment updates as follows:
  1. **Release disconnected devices:** If a Player's assigned device is no longer in the list of connected valid gamepads, that Player's assignment is reset to `NO_DEVICE` and that Player's index is recorded as having just disconnected. The other Player's assignment is never moved to fill the gap.
  2. **Assign newly available devices:** For each Player whose assignment is currently `NO_DEVICE` (in order: Player 1, then Player 2), assign the first connected valid gamepad that is not already assigned to the other Player.
  3. **Rebind input events:** Update the joypad button and motion events of each Player's input actions so each Player listens only to their assigned device ID (or `NO_DEVICE` when unassigned).
- The control layer exposes:
  - Whether a given local Player currently has a gamepad assigned.
  - Whether any local Player currently has a gamepad assigned.
  - A signal emitted whenever controller assignments change, carrying the Player index (or `-1` if none) whose assigned controller just disconnected.
- Online play continues to read from both local Player controller slots so that a single User in a browser can play with whichever connected Bluetooth controller is active.

### Presentation updates

- **Cat Select footer:**
  - Listens to the control layer's assignment-changed notification.
  - Whenever assignments change (and on initial construction), rebuilds or updates each Player's footer control prompts:
    - With a gamepad assigned to that Player: `["Stick", "D-pad"]` for `"Move"` and `["A"]` for `"Choose"`.
    - Without a gamepad assigned to that Player: the existing keyboard keys (`["A", "D"]` and `["Space"]` for Player 1; `["left", "right"]` and `["Enter"]` for Player 2).
  - Updates the centre Back prompt to `["Esc", "B"]` for `"Back"` when any Player has a gamepad assigned, and `["Esc"]` for `"Back"` when no gamepad is assigned.
- **Local Round auto-pause and Pause menu notice:**
  - During a local Round (while the Round has not finished, including during the drop-in and `"3, 2, 1, Go!"` countdown), the local round view listens for a controller disconnection on an active Player.
  - When a Player's controller disconnects, the local round view opens the Pause menu and tells the Pause menu to display an informational/warning notice (`"Player 1 controller disconnected"` or `"Player 2 controller disconnected"`).
  - The online round view overrides or disables automatic pause on controller disconnection so that an online Room is never paused automatically by a local device disconnect.

## Testing Decisions

- **What makes a good test:** A test feeds connected device lists and connection/disconnection transitions into the control layer's assignment logic and asserts on the observable outcomes (which Player has a controller, which device each Player listens to, which unknown devices receive a fallback mapping, and which Player is reported as disconnected), without depending on physical Bluetooth hardware or instantiating presentation scenes.
- **The single seam:** The control layer's gamepad roster and slot-assignment logic, tested headless through the existing test runner. Passing a list of candidate device descriptors (device ID, device name, GUID, and whether Godot knows the device) into the roster/assignment seam verifies:
  1. **Peripheral filtering:** Devices named as keyboards, mice, touchpads or consumer/system controls are ignored, while known gamepads and unknown Bluetooth controllers are accepted.
  2. **Fallback mapping selection:** Accepted devices that are not known to Godot's database are flagged for fallback mapping registration.
  3. **Initial assignment:** Two connected controllers are assigned to Player 1 and Player 2 in order; a third connected controller is held in reserve without displacing them.
  4. **Sticky slot retention on disconnect:** When Player 1's controller disconnects while Player 2's controller stays connected, Player 1 becomes unassigned (`NO_DEVICE`), Player 2 keeps their controller on Player 2, and Player 1 is reported as the disconnected Player.
  5. **Reconnection and backfill:** When a controller connects while Player 1 is unassigned and Player 2 is assigned, the newly connected controller fills Player 1's open slot without disturbing Player 2.
- **Prior art:** The headless rules tests and the Laser Pointer hunt tests, which inherit the project's base test case and run via the headless Godot test script.
- **Not automatically tested:** Visual rendering of the updated KeyCaps in Cat Select and the notice inside the Pause menu during a Round, which are thin presentation bindings verified by running the game.

## Out of Scope

- In-game Bluetooth scanning, pairing or operating-system Bluetooth management UI.
- Controller vibration / haptic feedback (rumble).
- Custom button remapping or an options screen for controller bindings.
- Manual controller-to-Player assignment lobbies (such as "press A to join" controller reordering screens).
- Local Matches with more than 2 Players.
- Automatic Room pause in online Matches when a User's controller disconnects.
- Per-brand button glyphs (PlayStation cross/square or Switch B/A icons in place of standard `A`, `B`, `X` KeyCaps).

## Further Notes

- In browsers, the W3C Gamepad API exposes a connected Bluetooth controller to the page only after the user presses a button on it (a browser fingerprinting safeguard). Once any button is pressed, Godot receives the joypad connection signal and the live assignment updates Cat Select or the active screen immediately.
