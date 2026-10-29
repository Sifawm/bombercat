# Every picture of a game thing is rendered from its game model

A Cat, a Bomb, a Powerup or a Map also appears outside the Round: in the Cats of the title screen and Cat Select, the portraits of Configure Match, the faces of the HUD and the Match Result, the Powerup icons, the Bomb of the splash, the pictures of the Maps. All of them come from the same models the Round draws (`game/assets/models/*.glb`), with the game's own look, never from a separate drawing or a render with other lighting. Where a 3D view is affordable (`ModelView`) it shows the model itself; a still picture is rendered from it by a script in the repository:

- Cat portraits and faces: `game/tools/render_pictures.tscn`, through `ModelView`, so they are lit and outlined as the Cats in the menus.
- Map pictures: the same tool, from the Map scenes, under the sun and the light of a Round.

When a model or the look of the game is redesigned, every picture made from it is rendered again: in the same commit, or in a commit of its own once the redesign is accepted.

## Considered Options

- **Pictures drawn or rendered apart, from the design file or in Blender** — rejected: drawn with other colours and light, they drifted from the Cats and Maps being played, and nothing showed it.

## Consequences

A redesign is not finished until its pictures are rendered again. Pictures that a script cannot render yet stay on the list of things to redo with it:

- The Powerup and Bomb icons (`game/assets/icons/`) and the splash Bomb (`game/assets/splash/bomb.png`) still come from the design file.
