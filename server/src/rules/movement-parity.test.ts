import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { expect, test } from 'vitest';
import { Board, type Bomb, type Cat } from './board';
import { mapFromRows, tileKey, type Vec } from './map';
import { move } from './movement';

/**
 * A walk: a Cat that starts on `start` and makes each of `moves`, a direction held for a number of
 * steps of a 60th of a second, around the Bombs on `bombs`. `expected` is where it ends, the
 * Tile that stopped its last step, if any, and the Portal it came out of and has not left, if any.
 */
interface Walk {
  rows: string[];
  bombs: [number, number][];
  start: [number, number];
  speed: number;
  cornerAssist: number;
  moves: [number, number, number][];
  expected?: { position: [number, number]; blocked: [number, number] | null; arrival: [number, number] | null };
}

// The same file is walked by `test_movement_parity.gd` with `movement.gd` (ADR 0004).
const CASES = join(__dirname, '../../../shared/src/movement-cases.json');

function walked(walk: Walk): Walk['expected'] {
  const board = new Board(mapFromRows(walk.rows));
  for (const [x, y] of walk.bombs) board.bombs.set(tileKey({ x, y }), {} as Bomb);
  const cat = { position: { x: walk.start[0], y: walk.start[1] }, facing: { x: 0, y: 1 }, portalArrival: null } as Cat;
  let blocked: Vec | null = null;
  for (const [x, y, steps] of walk.moves) {
    for (let step = 0; step < steps; step++) blocked = move(cat, board, { x, y }, walk.speed / 60, walk.cornerAssist);
  }
  const arrival = cat.portalArrival;
  return { position: [cat.position.x, cat.position.y], blocked: blocked && [blocked.x, blocked.y], arrival: arrival && [arrival.x, arrival.y] };
}

/**
 * Walks that turn at every distance from a corridor, at every speed a Cat can have, with and without
 * a Bomb behind; and walks through a pair of Portals and back, with and without a Bomb on the far one.
 */
function walks(): Walk[] {
  const rows = ['#######', '#.....#', '#.#.#.#', '#..x..#', '#.#.#.#', '#.....#', '#######'];
  const portals = ['#######', '#..1..#', '#.#.#.#', '#.....#', '#.#.#.#', '#..1..#', '#######'];
  const all: Walk[] = [];
  for (const speed of [2, 4, 4.75, 5.5, 6.25, 7]) {
    for (const cornerAssist of [0.7, 0.3]) {
      for (let down = 1; down < 60; down += 2) {
        const moves: Walk['moves'] = [[0, 1, down], [1, 0, 20], [0, -1, 9], [-1, 0, 13]];
        all.push({ rows, bombs: down % 4 === 1 ? [[1, 1]] : [], start: [1, 1], speed, cornerAssist, moves });
      }
      for (let right = 1; right < 40; right += 3) {
        const moves: Walk['moves'] = [[1, 0, right], [0, -1, 7], [-1, 0, 11], [1, 0, 5], [0, 1, 9], [-1, 0, 8]];
        all.push({ rows: portals, bombs: right % 6 === 4 ? [[3, 5]] : [], start: [1, 1], speed, cornerAssist, moves });
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
