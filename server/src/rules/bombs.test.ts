import { expect, test } from 'vitest';
import { config, DOWN, LEFT, makeRound, RIGHT, STEP, STOP } from './testing';

const LONG_CORRIDOR = ['#########', '#S.....S#', '#########'];
/** Player 0 can hide at the bottom of the left column; Player 1 waits on the right. */
const SHELTER = ['########', '#S....S#', '#.######', '#.######', '#.######', '########'];

test('a Bomb is placed on the Cat\'s Tile', () => {
  const round = makeRound(LONG_CORRIDOR);
  round.placeBomb(0);
  round.advance(STEP);
  expect(round.named('bombPlaced')).toEqual([{ type: 'bombPlaced', tile: { x: 1, y: 1 }, owner: 0 }]);
  expect(round.bombs).toHaveLength(1);
});

test('Bomb Capacity limits Bombs on the Map', () => {
  const round = makeRound(LONG_CORRIDOR);
  round.placeBomb(0);
  round.setMove(0, RIGHT);
  round.advance(0.25);
  round.placeBomb(0);
  round.advance(STEP);
  expect(round.named('bombPlaced')).toHaveLength(1); // Bomb Capacity 1 allows a single Bomb
});

test('a Bomb explodes when its Fuse ends', () => {
  const round = makeRound(LONG_CORRIDOR);
  round.placeBomb(0);
  round.setMove(0, RIGHT);
  round.advance(2.9);
  expect(round.named('bombDetonated')).toHaveLength(0); // still fused at 2.9 s
  round.advance(0.2);
  const detonations = round.named('bombDetonated');
  expect(detonations).toHaveLength(1);
  // Range 2 along the corridor, stopped by the Walls around it.
  expect(detonations[0].tiles.sort((a, b) => a.x - b.x)).toEqual([1, 2, 3].map((x) => ({ x, y: 1 })));
  expect(round.cats[0].alive).toBe(true); // the owner escaped beyond Range
});

test('capacity is restored after the Explosion', () => {
  const round = makeRound(LONG_CORRIDOR);
  round.placeBomb(0);
  round.setMove(0, RIGHT);
  round.advance(3.1);
  round.placeBomb(0);
  round.advance(STEP);
  expect(round.named('bombPlaced')).toHaveLength(2);
});

test('an Explosion destroys the first Crate and stops', () => {
  const round = makeRound(['########', '#S.x..S#', '########'], config({ bombRange: 3 }));
  round.placeBomb(0);
  round.advance(3.1);
  expect(round.named('crateDestroyed')).toEqual([{ type: 'crateDestroyed', tile: { x: 3, y: 1 } }]);
  expect(round.board.tileAt({ x: 3, y: 1 })).toBe('floor');
  const { tiles } = round.named('bombDetonated')[0];
  expect(tiles).toContainEqual({ x: 3, y: 1 }); // the Crate's Tile is in the Explosion
  expect(tiles).not.toContainEqual({ x: 4, y: 1 }); // the Tile behind the Crate is not
});

test('an Explosion detonates other Bombs immediately', () => {
  const round = makeRound(LONG_CORRIDOR, config({ bombCapacity: 2 }));
  round.placeBomb(0);
  round.setMove(0, RIGHT);
  round.advance(0.25);
  round.placeBomb(0); // on (2, 1), a quarter of a second behind the first
  round.advance(2.8); // 3.05 s: only the first Fuse has ended
  expect(round.named('bombDetonated')).toHaveLength(2); // Chain Reaction
  expect(round.bombs).toHaveLength(0);
});

test('its own Explosion kills the owner', () => {
  const round = makeRound(LONG_CORRIDOR);
  round.placeBomb(0);
  round.advance(3.1);
  expect(round.named('catEliminated')).toEqual([{ type: 'catEliminated', player: 0 }]);
  expect(round.cats[0].alive).toBe(false);
});

test('an Explosion stays lethal for its lifetime', () => {
  const round = makeRound(SHELTER);
  round.placeBomb(0);
  round.setMove(0, DOWN);
  round.setMove(1, LEFT);
  round.advance(0.5); // Player 1 waits at (4, 1), just outside Range
  round.setMove(1, STOP);
  round.advance(2.6);
  expect(round.named('catEliminated')).toHaveLength(0); // nobody was in the Explosion
  round.setMove(1, LEFT);
  round.advance(0.2);
  expect(round.named('catEliminated')).toEqual([{ type: 'catEliminated', player: 1 }]); // walked into a fresh Explosion
});

test('an Explosion is safe after its lifetime', () => {
  const round = makeRound(SHELTER);
  round.placeBomb(0);
  round.setMove(0, DOWN);
  round.advance(3.7); // detonation at 3.0 s plus the 0.5 s lifetime
  round.setMove(1, LEFT);
  round.advance(1);
  expect(round.named('catEliminated')).toHaveLength(0);
});

test('a Chain Reaction still clears one layer of Crates', () => {
  const round = makeRound(['########', '#S.xx.S#', '########'], config({ bombCapacity: 2 }));
  round.placeBomb(0);
  round.setMove(0, RIGHT);
  round.advance(0.25);
  round.placeBomb(0); // Bombs on (1, 1) and (2, 1); both Explosions reach the Crate on (3, 1)
  round.advance(2.8);
  expect(round.named('crateDestroyed')).toEqual([{ type: 'crateDestroyed', tile: { x: 3, y: 1 } }]);
  expect(round.board.tileAt({ x: 4, y: 1 })).toBe('crate'); // the Crate behind it survives
  expect(round.cats[0].activeBombs).toBe(0); // Bomb Capacity is free again
});

test('a Wall stops an Explosion within Range', () => {
  const round = makeRound(['########', '#S#...S#', '#.######', '#.######', '########']);
  round.placeBomb(0);
  round.advance(3.1);
  const { tiles } = round.named('bombDetonated')[0];
  expect(tiles).not.toContainEqual({ x: 2, y: 1 });
  expect(tiles).not.toContainEqual({ x: 3, y: 1 });
});
