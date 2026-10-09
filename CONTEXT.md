# BomberCat

A Bomberman-style battle game where the combatants are cats. This glossary fixes the words we use for the game's concepts.

## Language

### Game modes

**Battle**:
The only game mode: cats fight each other on a map until one remains. There is no campaign.
_Avoid_: Versus, deathmatch, story mode

**Match**:
A full Battle between the same Cats, won by the first Cat to win 2 Rounds (best of 3).
_Avoid_: Game, session

**Round**:
One fight on a freshly reset map, ending when a single Cat is left alive or the time limit runs out.
_Avoid_: Set, level, stage

**Draw**:
A Round with no winner — the last Cats died in the same explosion or the time limit ran out. It awards no win and is replayed.
_Avoid_: Tie, timeout

### Map

**Tile**:
One cell of the map grid. Everything except a moving Cat occupies exactly one Tile; a Cat's Tile is the one under its centre.
_Avoid_: Cell, square, slot

**Map**:
A rectangular grid of Tiles describing where Floor, Walls, Crates and Spawn Points are.
_Avoid_: Level, stage, arena, board

**Map Studio**:
The creator-only workspace where Maps are painted, validated and test-played. It is not part of the game players receive.
_Avoid_: MapCreator, map editor, level editor

**Floor**:
A Tile that Cats can walk on.
_Avoid_: Ground, grass

**Wall**:
An indestructible Tile that blocks movement and Explosions. Its look (brick, pillar) is a visual variant, not a different concept.
_Avoid_: Solid block, hard block, pillar

**Crate**:
A destructible Tile that blocks movement, is destroyed by an Explosion (stopping it), and may drop a Powerup chosen at random when the Round starts.
_Avoid_: Box, soft block, brick

**Spawn Point**:
A Floor Tile where a Cat starts each Round. A Map declares several; a Match uses one per Player, picking the ones farthest apart.
_Avoid_: Start position, spawn

### Bombs

**Bomb**:
An object a Cat places on its own Tile that blocks movement and detonates when its Fuse ends or an Explosion reaches it.

**Fuse**:
The time between a Bomb being placed and its detonation.
_Avoid_: Timer, countdown

**Explosion**:
The cross-shaped set of Tiles a detonating Bomb makes lethal for a short time. It kills any Cat it touches, including the Bomb's owner, and destroys Powerups lying on the floor.
_Avoid_: Blast, fire, flame

**Range**:
How many Tiles an Explosion reaches in each direction from its Bomb.
_Avoid_: Power, radius, fire level

**Bomb Capacity**:
How many of a Cat's Bombs can be on the map at the same time.
_Avoid_: Bomb count, ammo

**Chain Reaction**:
A Bomb detonating immediately because another Bomb's Explosion reached it.

### Powerups

**Powerup**:
An item lying on a Floor Tile that changes a Cat's abilities when the Cat walks over it. Its effects last until the Round ends unless stated otherwise. The full catalogue lives in `docs/powerups.md`.
_Avoid_: Item, pickup, bonus, upgrade

**Powerup Pool**:
The fixed set of Powerups a Map hides in its Crates. The quantities are the same every Round; only which Crate holds which Powerup is random.
_Avoid_: Loot table, drop rate, drop chance

**Yarn Ball**:
The Powerup that adds 1 to Bomb Capacity.

**Tuna Can**:
The Powerup that adds 1 to Range.

**Catnip**:
The Powerup that increases a Cat's movement speed.

**Paw Swipe**:
The Powerup that lets a Cat push a Bomb by walking into it, making it slide until it hits something.
_Avoid_: Kick

**Nine Lives**:
The Powerup that lets a Cat survive one Explosion. It does not stack.
_Avoid_: Shield, heart, extra life

**Cucumber**:
The negative Powerup that puts a random Curse on the Cat that picks it up.
_Avoid_: Skull

**Curse**:
A temporary handicap on a Cat, such as inverted controls or slowness.
_Avoid_: Disease, debuff

### Cats

**Player**:
A participant in a Match who controls one Cat. Today always a human on the local machine; later also an AI or a remote human.
_Avoid_: User, gamer

**Cat**:
A selectable playable character. Cats differ only in appearance.
_Avoid_: Character, hero, bomber

**Turing**:
The siamese Cat.

**Berni**:
The tuxedo Cat.

**Aquiles**:
The grey tabby Cat.

**Hami**:
The calico (tricolor) Cat.

**Ada Lovelace**:
The white Cat with a chocolate mask (the "stray" model).
_Avoid_: Callejero
