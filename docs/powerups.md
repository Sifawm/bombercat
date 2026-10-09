# Powerups

Catalogue of every Powerup considered for BomberCat, with its Bomberman origin and development status.
Terms follow [CONTEXT.md](../CONTEXT.md).

Status values: `todo` (not started), `wip`, `done`. Update the **Model** column when the Blender
model is exported and the **Game** column when the Powerup works in a Round.

## v1

| Powerup | Bomberman original | Effect | Model | Game |
|---|---|---|---|---|
| **Yarn Ball** | Bomb Up | +1 Bomb Capacity | done | done |
| **Tuna Can** | Fire Up | +1 Range | done | done |
| **Catnip** | Speed Up (Roller Skates) | Increases movement speed | done | done |
| **Paw Swipe** | Bomb Kick | Walking into a Bomb makes it slide until it hits something | done | done |
| **Nine Lives** | Heart | Absorbs one Explosion, then grants a brief invulnerability. Does not stack | done | done |
| **Cucumber** | Skull | Negative: applies a random Curse (inverted controls or slowness) for about 10 s | done | done |

Bomb Capacity and Range are capped by a tunable maximum (initially 8 each).

## Backlog (not planned for v1)

Ordered roughly by priority; the first three are the next candidates.

| Powerup | Bomberman original | Effect |
|---|---|---|
| **Laser Pointer** | Remote Control | Detonate own Bombs at will |
| **Claws** | Pierce Bomb | Explosions pass through Crates |
| **Scruff Grab** | Power Glove | Pick up and throw Bombs |
| **Golden Tuna** | Full Fire | Maximum Range |
| **Pounce** | Boxing Glove | Punch a Bomb so it hops over Tiles |
| **Big Fish** | Power Bomb | One Bomb with maximum Range |
| **Bouncy Ball** | Rubber Bomb | Bombs that bounce around |
| **Litter Box** | Land Mine | Hidden Bomb that detonates when stepped on |
| **Domino Paws** | Line Bomb | Places all available Bombs in a row |
| **Liquid Cat** | Soft Block Pass | Walk through Crates |
| **Tiptoe** | Bomb Pass | Walk through Bombs |
| **Cardboard Fort** | Fire Suit / Vest | Temporary invincibility |
| **Nap Time** | Clock | Freezes the other Cats briefly |
| **Bath Time** | Bomb Down / Fire Down | Negative: -1 Bomb Capacity or -1 Range |
| **Lasagna** | Speed Down (Geta) | Negative: decreases movement speed |
| **Roomba** | Louie (mount) | Rideable mount with its own ability |

## Original ideas (no Bomberman equivalent)

| Powerup | Effect |
|---|---|
| **Hairball** | Projectile that stuns the Cat it hits |
| **Mouse Toy** | Decoy that walks on its own and explodes |
| **Vacuum** | Map-wide event that scares every Cat |
