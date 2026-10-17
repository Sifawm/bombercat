import { balance, maps } from '@bombercat/shared';
import { expect, test } from 'vitest';
import { farthestSpawnPoints, mapFromRows, tileAt } from './map';
import { mapProblems } from './map-problems';
import type { GameConfig } from './config';
import { config } from './testing';

const FOUR_CORNERS = ['#######', '#S.x.S#', '#.....#', '#S...S#', '#######'];

test('rows describe Floor, Walls, Crates and Spawn Points', () => {
  const map = mapFromRows(FOUR_CORNERS);
  expect(map.size).toEqual({ x: 7, y: 5 });
  expect(tileAt(map, { x: 0, y: 0 })).toBe('wall');
  expect(tileAt(map, { x: 3, y: 1 })).toBe('crate');
  expect(tileAt(map, { x: 1, y: 1 })).toBe('floor'); // a Spawn Point is Floor
  expect(tileAt(map, { x: -1, y: 9 })).toBe('wall'); // outside the Map counts as Wall
  expect(map.spawnPoints).toHaveLength(4);
});

test('two Players get the Spawn Points farthest apart', () => {
  expect(farthestSpawnPoints(mapFromRows(FOUR_CORNERS), 2)).toEqual([
    { x: 1, y: 1 },
    { x: 5, y: 3 },
  ]);
});

test('more Players each get a Spawn Point of their own', () => {
  const map = mapFromRows(FOUR_CORNERS);
  expect(new Set(farthestSpawnPoints(map, 4))).toEqual(new Set(map.spawnPoints));
  expect(farthestSpawnPoints(map, 3)).toHaveLength(3);
});

const GOOD = ['#######', '#S.x.S#', '#.#x#.#', '#S.x.S#', '#######'];
const problems = (rows: string[], pool: Record<string, number> = {}) => mapProblems(mapFromRows(rows, pool));

test('a sound Map has no problems', () => {
  expect(problems(GOOD, { yarn_ball: 2, tuna_can: 1 })).toEqual([]);
});

test('a Map needs two Spawn Points', () => {
  expect(problems(['#####', '#S..#', '#.#.#', '#####'])).toEqual([expect.stringContaining('at least 2 Spawn Points')]);
});

test('a Spawn Point needs room to escape its first Bomb', () => {
  // The Cat on (1, 1) can only walk right: any Bomb it places there reaches it.
  expect(problems(['#####', '#S.S#', '###.#', '#####'])).toEqual([expect.stringMatching(/\(1, 1\).*escape/)]);
});

test('a Crate next to a Spawn Point is not room', () => {
  expect(problems(['######', '#S..S#', '#x##.#', '######'])).toEqual([expect.stringContaining('(1, 1)')]);
});

test('the Powerup Pool must fit in the Crates', () => {
  expect(problems(GOOD, { yarn_ball: 2, tuna_can: 2 })).toEqual([expect.stringMatching(/4 Powerups.*3 Crates/)]);
});

test('a Map must be enclosed by Walls', () => {
  expect(problems(['#####', '#S.S.', '#.#.#', '#####'])).toEqual([expect.stringMatching(/Wall.*\(4, 1\)/)]);
});

test('each Portal colour comes in a pair', () => {
  expect(problems(['#######', '#S1.2S#', '#.#1#.#', '#S.2.S#', '#######'])).toEqual([]);
  expect(problems(['#######', '#S1.1S#', '#.#1#.#', '#S.2.S#', '#######'])).toEqual([
    expect.stringContaining('3 Portals of colour 1'),
    expect.stringContaining('1 Portals of colour 2'),
  ]);
});

test('the Powerup Pool may only name known Powerups', () => {
  expect(problems(GOOD, { yarn_ball: 1, laser_pointer: 1 })).toEqual([expect.stringContaining('laser_pointer')]);
});

test('backyard, as the Godot project exports it, is a valid 13 by 11 Map', () => {
  const map = mapFromRows(maps.backyard.rows, maps.backyard.powerupPool);
  expect(map.size).toEqual({ x: 13, y: 11 });
  expect(map.spawnPoints).toEqual([
    { x: 1, y: 1 },
    { x: 11, y: 1 },
    { x: 1, y: 9 },
    { x: 11, y: 9 },
  ]);
  expect(tileAt(map, { x: 2, y: 2 })).toBe('wall'); // pillars on the checkerboard
  expect(map.tiles.filter((tile) => tile === 'crate')).toHaveLength(60);
  expect(map.tiles).toEqual([...map.tiles].reverse()); // point symmetry
  expect(map.powerupPool).toEqual({ yarn_ball: 6, tuna_can: 6, catnip: 4, paw_swipe: 2, nine_lives: 1, cucumber: 2 });
  expect(mapProblems(map)).toEqual([]);
});

test('living_room, as the Godot project exports it, is a valid 17 by 13 Map for six', () => {
  const map = mapFromRows(maps.living_room.rows, maps.living_room.powerupPool);
  expect(map.size).toEqual({ x: 17, y: 13 });
  expect(map.spawnPoints).toHaveLength(6);
  expect(map.tiles.filter((tile) => tile === 'crate')).toHaveLength(82);
  expect(map.tiles).toEqual([...map.tiles].reverse()); // point symmetry
  expect(mapProblems(map)).toEqual([]);
});

test('the balance values, as the Godot project exports them, are the ones the rules read', () => {
  const tuned: GameConfig = balance;
  expect(Object.keys(tuned).sort()).toEqual(Object.keys(config()).sort());
});
