# Laser Pointer

On the title screen and wherever Cats are chosen, the mouse pointer becomes a laser dot and the
Cats hunt it. This document is the spec of the first iteration and of the two that followed,
which replaced the first's hops, swats and bites near the Cat: where they differ, the last section
stands.

## Problem Statement

The Cats on the title screen and on the screens where they are chosen only loop their idle
animation. They stand there like pictures: nothing on those screens answers the person in front
of them, and the menus feel static next to how lively the Cats are in a Match.

## Solution

While on those screens, the mouse pointer is a red laser dot. Every Cat turns to watch it; a Cat
the dot comes near hunts it with small hops and paw swats, the hops lower the nearer the dot is,
and bites at it when the dot is right on it. When the mouse rests or leaves the window the dot
goes out and the Cats return to idle. The laser is decoration only: it chooses nothing.

## User Stories

1. As a person on the title screen, I want the mouse pointer to be a red laser dot, so that the screen invites me to play with the Cats.
2. As a person on the title screen, I want the laser dot to still press the Play, Play Online, How to Play and Quit buttons, so that the dot does not get in the way of using the menu.
3. As a person on the title screen, I want all five Cats to turn their body and head towards the dot, so that the Cats feel alive and aware of me.
4. As a person on the title screen, I want a Cat to look up or down at the dot, so that its gaze follows the dot wherever it is on screen, not only sideways.
5. As a person moving the dot near a Cat, I want that Cat to hop at it, so that it looks like a cat chasing a laser.
6. As a person moving the dot near a Cat, I want its hops to get lower the closer the dot is, so that the hunt reads as the Cat closing in.
7. As a person moving the dot near a Cat, I want it to swat at the dot with the paw on the dot's side, so that the Cat tries to grab it the way a cat would.
8. As a person holding the dot still near a Cat, I want the Cat to stop hopping and keep watching the dot, so that it behaves like a cat waiting for the dot to move.
9. As a person putting the dot right on a Cat, I want the Cat to bite at it, so that the closest moment of the hunt has its own payoff.
10. As a person moving the dot far from every Cat, I want the Cats only to watch it, so that the screen stays calm when I am not playing with them.
11. As a person sweeping the dot along the row of Cats, I want only the Cats it comes near to hunt it, so that the five Cats never jump all at once.
12. As a person who stops moving the mouse, I want the dot to go out after a few seconds and the Cats to return to idle, so that a resting mouse does not leave the Cats staring.
13. As a person whose mouse leaves the window, I want the dot to go out and the Cats to return to idle, so that the Cats do not stare at the edge of the screen.
14. As a person who moves the mouse again, I want the dot to come back at once and the Cats to pick it up, so that the play resumes without delay.
15. As a person watching a Cat change between watching, hunting, biting and idle, I want the changes to blend smoothly, so that the Cats never snap between poses.
16. As a person watching a Cat hunt, I want its hops, swats and bites to stay inside its place on the stage or on its card, so that no Cat is cut off by its frame.
17. As a Player in Cat Select, I want the Cats on the cards to hunt the dot too, so that choosing my Cat is as lively as the title screen.
18. As a Player in Cat Select, I want to keep choosing with my keys or gamepad, the mouse choosing nothing, so that the laser never changes which Cat I pick.
19. As a Player in Cat Select, I want a Cat to hunt the dot whether its card is free, claimed by a cursor or confirmed, so that the card and its tags alone tell its state.
20. As a Player in Cat Select playing only with keys or a gamepad, I want no dot on screen while the mouse rests, so that a laser nobody moves does not distract me.
21. As a User in a Room's WaitingRoom, I want the Cats on its cards to hunt the dot, so that waiting for the Match is as lively as the local Cat Select.
22. As a person playing in a browser, I want the laser to work the same as on the desktop, so that the web build is not the lesser one.
23. As a person on a touch screen, I want touching the screen to do nothing to the Cats, so that tapping buttons does not set them off.
24. As a person leaving those screens for a Match or Map Select, I want the normal pointer back, so that the laser belongs only to the Cats' screens.
25. As the creator, I want the distances, angles, hop height, fade times and the dot's look to be constants, so that I can tune the hunt on screen without reworking it.
26. As the creator, I want the new hop, swat and bite motions made in Blender like the Cats' other animations, so that the Cats keep one look and one pipeline.

## Implementation Decisions

- **Screens.** The laser is shown on the title screen and on every screen that shows CatCards:
  the local Cat Select and the online WaitingRoom. Match Result, Map Select and the Match do not
  have it.
- **The pointer.** On those screens the system pointer is hidden and a laser dot is drawn above
  everything, at the mouse position: a red core of about 14 px in the design's 1920×1080 space,
  a soft translucent glow (not additive: added onto the pale sky, red washes out to white), and a
  slight tremor as of a hand holding it. The dot is the hot spot, so
  buttons stay usable. Leaving those screens restores the system pointer.
- **The dot's state.** The dot is visible while the mouse has moved in the last 3 s and is
  inside the window; touch input never shows it. Its state, as the Cats read it, is its position,
  whether it is visible and whether it is moving.
- **The hunt decision** is a pure module, with no nodes or scene: from a Cat's centre on screen
  and the dot's state it returns what that Cat does:
  - its band: **watch** when the dot is over 420 px away, **hunt** from 110 to 420 px, **bite**
    under 110 px, or **idle** when the dot is not visible;
  - the body's yaw towards the dot, up to ±35°, the head's yaw on top of it, up to ±30° more, and
    the head's pitch up or down;
  - in the hunt band and while the dot moves: the hop height, from 1 at the band's far edge down
    towards 0 at its near edge, and the swatting paw, the one on the dot's side; while the dot is
    still, the Cat only watches;
  - in the bite band: the bite.

  Each Cat decides on its own distance, so all of them watch and only those the dot is near hunt
  or bite.
- **The Cats stay in their place.** No Cat leaves its slot on the title stage or its card. Every
  motion happens in place: the Cat keeps its size and its spot, but its 3D view reaches beyond its
  slot, on each side for its turns and above it for its hops, so neither is cut off. A hop may pass
  over what stands above the Cat, such as the title's logo or the card's edge.
- **New animations** are added to the Cat builder in Blender and exported with the Cats' models:
  `pounce` (a crouch and a short hop with the paws up), `swat` (one paw thrown out to the side and
  across the front, one clip per paw) and `bite` (the head drawn back, a lunge forward with the
  paws out, and two squashing chomps). Seen from the front, leaning forward reads far stronger than
  its angle, so the clips lean little. The swat is not the Paw
  Swipe Powerup; the word is kept apart on purpose.
- **Hop height.** `pounce` is baked once at the highest hop, the same as `win`'s (0.3 up). The
  hunt decision's hop height scales the Root's lift at run time.
- **Gaze by code.** The body and head turns towards the dot are applied in Godot to the Body and
  Head bones, on top of whichever clip is playing, since the dot moves every frame.
- **Blending.** Changes between idle, watch, hunt and bite blend over 0.3 s. The idle loops keep
  their out-of-step phases.
- **A hunting Cat** wraps a ModelView, which gains room around the size it is framed at. The
  hunting Cat plays the clips one after another, the hop then the swat, blends them, and turns the
  Body and Head bones through a skeleton modifier that runs after the animation. The title screen
  and CatCard give each of their Cats the screen's dot, and each Cat measures from its own centre
  on screen, so CatCard brings the hunt to Cat Select and the WaitingRoom alike.
- **Input.** The laser chooses nothing. Cat Select keeps ignoring the mouse; on the title screen
  the dot is simply the pointer that presses the buttons.
- **Tuning.** The band distances, angles, hop height, timeout, blend time and the dot's size,
  glow and tremor are named constants, set to the values above as a starting point and tuned once
  seen on screen.
- **Pictures.** The portraits, faces and icons are unchanged: they show the Cats standing idle,
  and the new clips do not change the models' look (ADR 0006).

## Testing Decisions

- A good test drives a module through what it takes and checks what it gives back, never how it
  works inside; a test that breaks when the module is reorganised without changing its answers is
  a bad test.
- **The one seam is the hunt decision**, the pure module above, together with the dot's state
  (visible, moving), which is computed from the time passed and the mouse's events as data. It is
  tested headless by the existing runner, with the same test case as the rules tests. The checks:
  - each band by distance, and its edges;
  - the hop height falling from the band's far edge to its near edge;
  - the swatting paw on each side of the Cat;
  - no hop or swat while the dot is still in the hunt band;
  - the body and head turns capped at ±35° and ±30°, and the pitch up and down;
  - the dot going out after 3 s still and on leaving the window, coming back on a move, and never
    shown by touch;
  - idle for every Cat when the dot is not visible.
- **Prior art:** the rules tests, which build their state in code and check pure results the same
  way.
- **What is seen, not tested:** the dot's drawing, the new clips, the blends and whether every
  motion stays inside its frame are checked on screenshots of the title screen and Cat Select,
  taken through a fixed SubViewport.

## Out of Scope

- The second iteration below: stalking, the committed pounce and the missed catch.
- Cats leaving their place, or running across the screen after the dot.
- Choosing a Cat with the mouse in Cat Select or the WaitingRoom.
- The dot moving by itself (a demo mode) or being moved with a stick or the arrow keys.
- Touch input moving the dot.
- A sound for the bite or a reaction of the dot when it is bitten.
- The laser on Match Result, Map Select or in a Match.

## Further Notes

- Being decoration, the laser touches neither the rules nor the online Room: nothing about it
  reaches the server.
- A Cat whose head is already turned keeps the turn through a hop or a bite, so the gaze and the
  clips must add up rather than replace each other.

## Second Iteration: Stalk and the Missed Pounce

Built after the first iteration. A real cat commits to a pounce when it leaves the ground and
cannot correct it in the air; when the laser moves as it jumps, it lands where the dot was. Seen
on screen, the first iteration's alternating pounce and swat read as restless rather than cute,
and a Cat leaping at a dot below its feet made no sense, so the second iteration also replaced
them.

1. **Hops.** While the dot moves in the hunt band, above the Cat's feet, the Cat hops on the spot
   in a new looping clip, `hop_l` or `hop_r`: small steady hops (0.08 up), the paw nearer the dot
   stretched out at it the whole time. The paw changes only once the dot is 40 px over to the
   other side, so a dot wavering right above the Cat does not swap it back and forth. The hops no
   longer get lower as the dot comes nearer, and the swat clips are gone.
2. **Stalk.** When the dot has been still for 0.6 s inside the hunt band, or lies below the
   Cat's feet, the Cat crouches into a new looping clip, `stalk`: body low, rear
   wiggling, tail twitching, paws drawn in, eyes locked on the dot. It is lowered rather than
   squashed, since the Head inherits the Body's squash and a flattened head reads as seen from
   above. Stalking happens only in the hunt band.
3. **The pounce goes off** the moment a stalked dot moves again, or rises above the
   Cat's feet: `pounce`, from the stalk's crouch, at its full height (`win`'s 0.3 up).
4. **The aim is committed.** On take-off the body's and head's turns are frozen towards where the
   dot was; in the air the Cat no longer follows it, and the leap is not called off, not even when
   the dot goes out. As the Cat stays in its place, the miss is told by the Cat landing facing an
   empty spot.
5. **On landing:**
   - if the dot is within the bite distance of the spot the Cat aimed at, it is a **catch**: the
     paws pin it to the ground (`pin`), then the Cat bites;
   - otherwise it is a **miss**: the body keeps facing the empty spot while the head snaps to where
     the dot is now, one ear flicks back, a pause of 0.4 s, and the hunt carries on. The miss
     reaction is done by code, with no new clip.
6. **Looking down.** The head turns down at most 4° (up, still 25°): seen from above, the big head
   reads far more turned down than it is, and any further hides the Cat's face.
7. **The state machine.** The hunt decision keeps each Cat's state from one frame to the next
   (idle, watch, hop, stalk, pounce, pin, bite, miss): the hunting Cat calls it every frame and
   tells it when a one-shot clip (`pounce`, `pin`, `bite`) has ended, and it decides the catch or
   the miss. Its tests cover the hops, the stalk, the committed pounce, the catch and the miss.

## Third Iteration: Swats Within Reach

Built after the second. Seen on screen, a Cat biting at a dot that came near read as nibbling
rather than hunting: a cat whose paw can reach the laser tries to grab it.

1. **Swats.** From the moment the dot is within the Cat's reach (under 110 px from its centre, the
   old bite distance, renamed the reach), it swats at it with its feet planted, in a new looping
   clip, `swat_l` or `swat_r`: in 1 s the paw on the dot's side winds up beside the cheek and
   slaps out and down at the dot three times, the body dipping a little on each slap, while the
   other paw stays up. A little desperate, not frantic. Only the paw on the dot's side swats,
   chosen as for the hops.
2. **Swats in the screen's plane.** Seen from the front, a paw swung forward points at the camera
   and is lost, and one raised above about 110° hides behind the big head, so the swats go
   sideways and stay below the cheek.
3. **The bite is kept only for a catch**: after a pounce that lands within reach of the dot, the
   Cat pins it and bites it, as before.
