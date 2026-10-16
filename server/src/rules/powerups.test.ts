import { expect, test } from 'vitest';
import type { GameConfig } from './config';
import type { Vec } from './map';
import { distributePowerups } from './powerups';
import { seededRandomInt } from './config';
import { config, DOWN, expectPosition, LEFT, makeRound, RIGHT, STEP, STOP, type TestRound, UP } from './testing';

/**
 * Player 0 breaks the Crate on (3, 1) from (2, 1) and shelters on (1, 2). Player 1 waits on (6, 1),
 * out of reach of a Bomb on the Crate's Tile.
 */
const ONE_CRATE = ['########', '#S.x..S#', '#.######', '########'];
const TWO_CRATES = ['##########', '#S.xx...S#', '#.########', '##########'];
const HOME_X = 1;

const quick = (changes: Partial<GameConfig> = {}) => config({ fuse: 1, ...changes });

/** Walks Player 0 along `path`, one Tile per entry, at the default speed. */
function walk(round: TestRound, path: Vec[]): void {
  for (const direction of path) {
    round.setMove(0, direction);
    round.advance(0.25);
  }
  round.setMove(0, STOP);
}

/**
 * Player 0 goes from its Spawn Point to column `bombX` along row 1, places a Bomb, shelters on
 * (1, 2) until the Explosion is over, and comes back.
 */
function bombFrom(round: TestRound, bombX: number): void {
  const steps = bombX - HOME_X;
  walk(round, new Array<Vec>(steps).fill(RIGHT));
  round.placeBomb(0);
  walk(round, [...new Array<Vec>(steps).fill(LEFT), DOWN]);
  round.advance(2);
  walk(round, [UP]);
}

/** A Round where the Crate on (3, 1) has just revealed the given Powerup and Player 0 is back home. */
function roundWithRevealed(powerup: string, gameConfig = quick(), seed = 0): TestRound {
  const round = makeRound(ONE_CRATE, gameConfig, { [powerup]: 1 }, seed);
  bombFrom(round, 2);
  return round;
}

/** The same, with Player 0 having walked onto (3, 1) and collected it on the way. */
function roundWithCollected(powerup: string, gameConfig = quick(), seed = 0): TestRound {
  const round = roundWithRevealed(powerup, gameConfig, seed);
  walk(round, [RIGHT, RIGHT]);
  return round;
}

/**
 * The same, but Player 0 stops on the very step it collects the Powerup (as it enters the Tile),
 * for Powerups that change how it walks.
 */
function roundWithJustCollected(powerup: string, gameConfig = quick(), seed = 0): TestRound {
  const round = roundWithRevealed(powerup, gameConfig, seed);
  round.setMove(0, RIGHT);
  while (round.named('powerupCollected').length === 0) round.step(STEP);
  round.setMove(0, STOP);
  return round;
}

function roundWithCurse(curse: string, gameConfig = quick()): TestRound {
  for (let seed = 0; seed < 64; seed++) {
    const round = roundWithJustCollected('cucumber', gameConfig, seed);
    if (round.cats[0].curse?.id === curse) return round;
  }
  throw new Error(`no seed below 64 gave the Curse ${curse}`);
}

test('a destroyed Crate reveals its Powerup', () => {
  const round = roundWithRevealed('yarn_ball');
  expect(round.named('powerupRevealed')).toEqual([{ type: 'powerupRevealed', tile: { x: 3, y: 1 }, powerup: 'yarn_ball' }]);
  expect(round.board.powerups.get('3,1')).toBe('yarn_ball'); // lying on the Floor
  expect(round.named('powerupDestroyed')).toHaveLength(0); // not by the Explosion that revealed it
});

test('a Crate without a Powerup reveals nothing', () => {
  const round = makeRound(ONE_CRATE, quick());
  bombFrom(round, 2);
  expect(round.named('crateDestroyed')).toHaveLength(1);
  expect(round.named('powerupRevealed')).toHaveLength(0);
});

test('walking over a Powerup collects it', () => {
  const round = roundWithCollected('yarn_ball');
  expect(round.named('powerupCollected')).toEqual([{ type: 'powerupCollected', player: 0, tile: { x: 3, y: 1 }, powerup: 'yarn_ball' }]);
  expect(round.board.powerups.size).toBe(0); // gone from the Floor
  expect(round.cats[0].collected).toEqual(['yarn_ball']);
});

test('an Explosion destroys a Powerup on the Floor', () => {
  const round = roundWithRevealed('yarn_ball');
  bombFrom(round, 2);
  expect(round.named('powerupDestroyed')).toEqual([{ type: 'powerupDestroyed', tile: { x: 3, y: 1 }, powerup: 'yarn_ball' }]);
  expect(round.board.powerups.size).toBe(0);
});

test('Yarn Ball raises Bomb Capacity', () => {
  expect(roundWithCollected('yarn_ball').cats[0].bombCapacity).toBe(2);
});

test('Bomb Capacity has a maximum', () => {
  const round = roundWithCollected('yarn_ball', quick({ maxBombCapacity: 1 }));
  expect(round.cats[0].bombCapacity).toBe(1);
  expect(round.named('powerupCollected')).toHaveLength(1); // still collected
});

test('Tuna Can raises Range', () => {
  expect(roundWithCollected('tuna_can').cats[0].bombRange).toBe(3);
});

test('Range has a maximum', () => {
  expect(roundWithCollected('tuna_can', quick({ maxBombRange: 2 })).cats[0].bombRange).toBe(2);
});

test('Catnip makes a Cat faster', () => {
  const round = roundWithJustCollected('catnip', quick({ catnipSpeedGain: 2 }));
  const start = round.cats[0].position;
  round.setMove(0, LEFT);
  round.advance(0.25);
  expectPosition(round.cats[0], { x: start.x - 1.5, y: start.y }); // speed 6 for a quarter of a second
});

test('a Cat\'s speed has a maximum', () => {
  const round = roundWithCollected('catnip', quick({ catnipSpeedGain: 5, maxCatSpeed: 4.5 }));
  expect(round.cats[0].speed).toBe(4.5);
});

test('Nine Lives absorbs one Explosion', () => {
  const round = roundWithCollected('nine_lives');
  expect(round.cats[0].nineLives).toBe(true);
  round.placeBomb(0);
  round.advance(1.6); // the Explosion has come and gone around the Cat
  expect(round.named('nineLivesConsumed')).toEqual([{ type: 'nineLivesConsumed', player: 0 }]);
  expect(round.cats[0].alive).toBe(true); // survived the whole Explosion
  expect(round.cats[0].nineLives).toBe(false); // Nine Lives is spent
  round.advance(1); // the invulnerability is over too
  round.placeBomb(0);
  round.advance(1.1);
  expect(round.cats[0].alive).toBe(false); // the next Explosion kills
});

test('Nine Lives does not stack', () => {
  const round = makeRound(TWO_CRATES, quick(), { nine_lives: 2 });
  bombFrom(round, 2);
  bombFrom(round, 3); // collects the first on the way, reveals the second
  walk(round, [RIGHT, RIGHT, RIGHT]);
  expect(round.named('powerupCollected')).toHaveLength(2);
  round.placeBomb(0);
  round.advance(2.6); // first Explosion absorbed, invulnerability over
  expect(round.cats[0].alive).toBe(true);
  round.placeBomb(0);
  round.advance(1.1);
  expect(round.cats[0].alive).toBe(false); // there was no second Nine Lives
});

test('Cucumber puts a Curse on the Cat', () => {
  const round = roundWithCollected('cucumber');
  expect(round.named('curseStarted')).toHaveLength(1);
  expect(round.cats[0].curse).not.toBeNull();
});

test('inverted controls reverse the Cat\'s direction', () => {
  const round = roundWithCurse('inverted_controls');
  const start = round.cats[0].position;
  round.setMove(0, RIGHT);
  round.advance(0.25);
  expectPosition(round.cats[0], { x: start.x - 1, y: start.y }); // commanded right, walked a Tile left
});

test('slowness slows the Cat', () => {
  const round = roundWithCurse('slowness', quick({ slownessFactor: 0.5 }));
  const start = round.cats[0].position;
  round.setMove(0, LEFT);
  round.advance(0.25);
  expectPosition(round.cats[0], { x: start.x - 0.5, y: start.y }); // half a Tile at half speed
});

test('a Curse ends after its duration', () => {
  const round = roundWithCurse('inverted_controls', quick({ curseDuration: 1 }));
  round.advance(1.1);
  expect(round.named('curseEnded')).toEqual([{ type: 'curseEnded', player: 0, curse: 'inverted_controls' }]);
  expect(round.cats[0].curse).toBeNull();
  const start = round.cats[0].position;
  round.setMove(0, LEFT);
  round.advance(0.25);
  expectPosition(round.cats[0], { x: start.x - 1, y: start.y }); // controls are back to normal
});

test('Paw Swipe pushes a Bomb until it hits a Wall', () => {
  const round = roundWithCollected('paw_swipe');
  round.placeBomb(0); // on (3, 1)
  walk(round, [RIGHT, LEFT]); // off the Bomb, then into it
  round.advance(0.4);
  expect(round.bombs[0].tile).toEqual({ x: 1, y: 1 }); // the last Tile before the Wall
  expect(round.named('bombMoved')).toEqual([
    { type: 'bombMoved', from: { x: 3, y: 1 }, to: { x: 2, y: 1 } },
    { type: 'bombMoved', from: { x: 2, y: 1 }, to: { x: 1, y: 1 } },
  ]);
});

test('a pushed Bomb stops at a Cat', () => {
  const round = roundWithCollected('paw_swipe');
  round.placeBomb(0); // on (3, 1)
  walk(round, [LEFT, RIGHT]);
  round.advance(0.4);
  expect(round.bombs[0].tile).toEqual({ x: 5, y: 1 }); // next to Player 1 on (6, 1)
});

test('without Paw Swipe a Bomb does not move', () => {
  const round = roundWithCollected('yarn_ball');
  round.placeBomb(0);
  walk(round, [RIGHT, LEFT]);
  round.advance(0.4);
  expect(round.bombs[0].tile).toEqual({ x: 3, y: 1 });
  expect(round.named('bombMoved')).toHaveLength(0);
});

test('Paw Swipe works when the Cat is slightly off the Bomb\'s row', () => {
  const round = roundWithCollected('paw_swipe');
  walk(round, [LEFT]);
  round.placeBomb(0); // on (2, 1)
  walk(round, [LEFT]);
  round.setMove(0, DOWN);
  round.advance(0.075); // 0.3 Tiles below row 1
  round.setMove(0, RIGHT);
  round.advance(0.5);
  expect(round.bombs[0].tile).toEqual({ x: 5, y: 1 }); // pushed all the way to Player 1
});

test('a pushed Bomb stops before a Tile a Cat overlaps', () => {
  const round = roundWithCollected('paw_swipe');
  round.setMove(1, LEFT);
  round.advance(0.1); // Player 1 at x 5.6, overlapping Tiles 5 and 6
  round.setMove(1, STOP);
  round.placeBomb(0);
  walk(round, [LEFT, RIGHT]);
  round.advance(0.4);
  expect(round.bombs[0].tile).toEqual({ x: 4, y: 1 }); // short of the Cat's body
});

test('an Explosion destroys the Powerup under its own Bomb', () => {
  // Player 1 is walled in on the right, so a Bomb pushed right stops on (4, 1).
  const rows = ['########', '#S.xx#S#', '#.######', '########'];
  const seeds = Array.from({ length: 64 }, (_, seed) => seed);
  const seed = seeds.find((candidate) =>
    makeRound(rows, quick(), { paw_swipe: 1, yarn_ball: 1 }, candidate).board.hiddenPowerups.get('3,1') === 'paw_swipe',
  );
  const round = makeRound(rows, quick(), { paw_swipe: 1, yarn_ball: 1 }, seed);
  bombFrom(round, 2);
  bombFrom(round, 3); // collects Paw Swipe on the way, reveals the Yarn Ball on (4, 1)
  walk(round, [RIGHT]);
  round.placeBomb(0);
  walk(round, [LEFT, RIGHT, LEFT, DOWN]); // step back, push the Bomb onto the Yarn Ball, shelter
  round.advance(0.5);
  expect(round.named('powerupDestroyed')).toEqual([{ type: 'powerupDestroyed', tile: { x: 4, y: 1 }, powerup: 'yarn_ball' }]);
});

test('a Curse ends when its Cat dies', () => {
  const round = roundWithCurse('slowness');
  round.placeBomb(0);
  round.advance(1.1);
  expect(round.named('catEliminated')).toHaveLength(1);
  expect(round.named('curseEnded')).toHaveLength(1);
});

test('an unknown Powerup in the pool is left out', () => {
  expect(makeRound(ONE_CRATE, quick(), { laser_pointer: 1 }).board.hiddenPowerups.size).toBe(0);
});

test('a Cat keeps count of its Bombs, Crates and Powerups', () => {
  const round = roundWithCollected('yarn_ball');
  expect(round.cats[0]).toMatchObject({ bombsPlaced: 1, cratesDestroyed: 1, collected: ['yarn_ball'] });
  expect(round.cats[1].cratesDestroyed).toBe(0);
});

const POOL = { yarn_ball: 3, tuna_can: 2, cucumber: 1 };
const crates = (count: number) => Array.from({ length: count }, (_, x) => ({ x, y: 0 }));
const distribute = (seed: number, crateCount = 20) => distributePowerups(POOL, crates(crateCount), seededRandomInt(seed));

test('every Powerup of the pool goes into its own Crate', () => {
  const hidden = [...distribute(1).values()];
  expect(hidden).toHaveLength(6);
  for (const [powerup, quantity] of Object.entries(POOL)) {
    expect(hidden.filter((id) => id === powerup)).toHaveLength(quantity);
  }
});

test('the same random source gives the same distribution', () => {
  expect(distribute(7)).toEqual(distribute(7));
});

test('positions change from Round to Round', () => {
  expect(distribute(1)).not.toEqual(distribute(2));
});

test('a pool larger than the Crates fills them all', () => {
  expect(distribute(1, 4).size).toBe(4);
});

test('a Round hides the Map\'s pool in its Crates', () => {
  const round = makeRound(['######', '#SxxS#', '######'], config(), { yarn_ball: 1, tuna_can: 1 });
  expect([...round.board.hiddenPowerups.values()].sort()).toEqual(['tuna_can', 'yarn_ball']);
});
