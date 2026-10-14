import { expect } from 'vitest';
import type { Cat } from './board';
import { type GameConfig, seededRandomInt } from './config';
import { mapFromRows, type Vec } from './map';
import type { MatchEvent } from './match';
import { Round, type RoundEvent } from './round';

export const STEP = 1 / 60;
export const UP: Vec = { x: 0, y: -1 };
export const DOWN: Vec = { x: 0, y: 1 };
export const LEFT: Vec = { x: -1, y: 0 };
export const RIGHT: Vec = { x: 1, y: 0 };
export const STOP: Vec = { x: 0, y: 0 };

/** The values the tests are written for, whatever the game is tuned to. */
export const config = (changes: Partial<GameConfig> = {}): GameConfig => ({
  catSpeed: 4,
  cornerAssist: 0.7,
  bombCapacity: 1,
  bombRange: 2,
  maxBombCapacity: 8,
  maxBombRange: 8,
  maxCatSpeed: 7,
  fuse: 3,
  explosionLifetime: 0.5,
  bombSlideSpeed: 8,
  catnipSpeedGain: 0.75,
  nineLivesInvulnerability: 1.5,
  curseDuration: 10,
  slownessFactor: 0.5,
  roundTime: 120,
  roundsToWin: 2,
  ...changes,
});

/** A Round that keeps everything that happened in it. */
export class TestRound extends Round {
  readonly events: RoundEvent[] = [];

  override step(delta: number): RoundEvent[] {
    const events = super.step(delta);
    this.events.push(...events);
    return events;
  }

  advance(seconds: number): void {
    advance(this, seconds);
  }

  named<Type extends RoundEvent['type']>(type: Type): Extract<RoundEvent, { type: Type }>[] {
    return this.events.filter((event): event is Extract<RoundEvent, { type: Type }> => event.type === type);
  }
}

/**
 * Cats start on the "S" Tiles in reading order: Player 0 on the first, Player 1 on the second.
 * `seed` fixes every random choice of the Round.
 */
export function makeRound(rows: readonly string[], gameConfig = config(), pool: Record<string, number> = {}, seed = 0) {
  const map = mapFromRows(rows, pool);
  return new TestRound(map, gameConfig, map.spawnPoints, seededRandomInt(seed));
}

export function advance(stepped: { step(delta: number): MatchEvent[] }, seconds: number): MatchEvent[] {
  const events: MatchEvent[] = [];
  for (let index = 0; index < Math.round(seconds / STEP); index++) events.push(...stepped.step(STEP));
  return events;
}

export function expectPosition(cat: Cat, expected: Vec): void {
  expect(Math.hypot(cat.position.x - expected.x, cat.position.y - expected.y), JSON.stringify(cat.position)).toBeLessThan(0.001);
}
