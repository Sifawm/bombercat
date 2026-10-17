# Maps

The Maps BomberCat ships and the Tiles they are made of. Terms follow [CONTEXT.md](../CONTEXT.md).
Crate densities and Powerup Pools are *tunable*: they are starting values for test-play.

## backyard

13 x 11, a garden by day. Brick border, pillars on a checkerboard, 4 corner Spawn Points, Crates
over about 75 % of the free Tiles with point symmetry. Pool: Yarn Ball 6, Tuna Can 6, Catnip 4,
Paw Swipe 2, Nine Lives 1, Cucumber 2.

## living_room

17 x 13, a living room. The Map for crowds: 6 Spawn Points (corners and the middle of the long
sides), so all five Cats fit online.

- **Walls are furniture** made of one-Tile pieces that rotate and chain: `sofa_left`,
  `sofa_middle` and `sofa_right` make sofas of any length (GridMap turns pieces but cannot mirror
  them, hence two ends), `bookshelf`, four turned `table_corner` make a 2 x 2 table, `cat_tree` is
  the lone pillar, `wall_room` the border and `wall_room_low` its south side, which must not hide
  the last row. The rug in the middle is decoration, not a Tile.
- **Layout:** furniture in blocks rather than a checkerboard, mirrored on both axes, around an
  open rug in the middle with few Crates. Lanes of different widths.
- **Crates** over about 60 % of the free Tiles.
- **Pool:** Yarn Ball 8, Tuna Can 9, Catnip 5, Paw Swipe 4, Nine Lives 2, Cucumber 2. Open
  space favours Range and pushed Bombs.

## rooftops

19 x 11, rooftops at night. Two roofs of 8 x 9 Tiles, left and right, split by an alley of Walls
and joined only by a one-Tile bridge on the middle row, and by two pairs of Portals.

- **Walls:** `chimney` and `chimney_antenna` as pillars on a sparse checkerboard, `wall_ridge` (a
  stone parapet) for the border and `wall_ridge_low` for its south side, `alley` for the drop
  between the roofs. Planks lie across the bridge as decoration. The Map is lit by a bluish moon
  (`light`) over a night `background`.
- **Layout:** each roof is the other turned 180 degrees. 4 Spawn Points in the corners, so two
  local Players start on different roofs.
- **Portals** cross diagonally (blue: top left to bottom right; orange: bottom left to top right),
  each on the column next to the outer border, about 3 Tiles from its corner and buried in Crates:
  the bridge is the way through the middle, the Portals the way round the outside.
- **Crates** over about 70 % of the free Tiles.
- **Pool:** Yarn Ball 5, Tuna Can 5, Catnip 3, Paw Swipe 4, Nine Lives 1, Cucumber 2. Pushed Bombs
  travel through Portals, so Paw Swipe is this Map's own weapon.

## Portal

A Floor Tile linked to the other Portal of its colour. Only Cats and pushed Bombs travel through
Portals; Explosions pass over them as over Floor.

- A Cat travels when its centre crosses the centre of a Portal: it is put on the centre of the
  other Portal, facing the same way, and keeps walking if its Player keeps the direction held.
  The Portal it arrives at does not send it back until it has left that Tile.
- A Bomb may be placed on a Portal. While the other Portal holds a Bomb, a Cat walks over this
  one as over Floor.
- A pushed Bomb that reaches a Portal comes out of the other one and keeps sliding the same way.
  If the other Portal holds a Bomb or any part of a Cat, the Bomb stops on the Portal it reached.
- Portals come in pairs by colour (blue, orange): each colour appears on a Map exactly twice or
  not at all. They are painted in Map Studio like any other item and exported as `1` and `2`.
- The Portal is a flat skylight lit from inside in its colour. Travelling is instant: both
  skylights flash, the traveller swells back to size, and it sounds. Nothing in the game explains
  Portals; the matching colours and the flash do.
