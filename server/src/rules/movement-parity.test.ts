import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test } from 'vitest';
import { Board, type Bomb, type Cat } from './board';
import { mapFromRows, tileKey, type Vec } from './map';
import { move } from './movement';

/**
 * A walk: a Cat that starts on `start` and makes each of `moves`, a direction held for a number of
 * steps of a 60th of a second, around the Bombs on `bombs`. `expected` is where it ends and the
 * Tile that stopped its last step, if any.
 */
interface Walk {
  rows: string[];
  bombs: [number, number][];
  start: [number, number];
  speed: number;
  cornerAssist: number;
  moves: [number, number, number][];
  expected?: { position: [number, number]; blocked: [number, number] | null };
}

// The same file is walked by `test_movement_parity.gd` with `movement.gd` (ADR 0004).
const CASES = join(__dirname, '../../../shared/src/movement-cases.json');

function walked(walk: Walk): Walk['expected'] {
  const board = new Board(mapFromRows(walk.rows));
  for (const [x, y] of walk.bombs) board.bombs.set(tileKey({ x, y }), {} as Bomb);
  const cat = { position: { x: walk.start[0], y: walk.start[1] }, facing: { x: 0, y: 1 } } as Cat;
  let blocked: Vec | null = null;
  for (const [x, y, steps] of walk.moves) {
    for (let step = 0; step < steps; step++) blocked = move(cat, board, { x, y }, walk.speed / 60, walk.cornerAssist);
  }
  return { position: [cat.position.x, cat.position.y], blocked: blocked && [blocked.x, blocked.y] };
}

/** Walks that turn at every distance from a corridor, at every speed a Cat can have, with and without a Bomb behind. */
function walks(): Walk[] {
  const rows = ['#######', '#.....#', '#.#.#.#', '#..x..#', '#.#.#.#', '#.....#', '#######'];
  const all: Walk[] = [];
  for (const speed of [2, 4, 4.75, 5.5, 6.25, 7]) {
    for (const cornerAssist of [0.7, 0.3]) {
      for (let down = 1; down < 60; down += 2) {
        const moves: Walk['moves'] = [[0, 1, down], [1, 0, 20], [0, -1, 9], [-1, 0, 13]];
        all.push({ rows, bombs: down % 4 === 1 ? [[1, 1]] : [], start: [1, 1], speed, cornerAssist, moves });
      }
    }
  }
  return all;
}

test('movement walks every shared case to where the file says, as movement.gd must', () => {
  // UPDATE_CASES=1 writes the file again from this implementation; then the GDScript must agree.
  if (process.env.UPDATE_CASES) {
    const cases = walks().map((walk) => ({ ...walk, expected: walked(walk) }));
    writeFileSync(CASES, `[\n${cases.map((walk) => JSON.stringify(walk)).join(',\n')}\n]\n`);
  }
  const cases: Walk[] = JSON.parse(readFileSync(CASES, 'utf8'));
  expect(cases.length).toBeGreaterThan(100);
  for (const walk of cases) expect(walked(walk), JSON.stringify(walk.moves)).toEqual(walk.expected);
});
