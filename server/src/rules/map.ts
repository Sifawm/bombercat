import type { Vec } from '@bombercat/shared';

export type { Vec };

export type Tile = 'floor' | 'wall' | 'crate';

/** Plain description of a Map: the data a Board is built from. */
export interface MapData {
  size: Vec;
  /** Row by row, `size.x` Tiles per row. */
  tiles: Tile[];
  spawnPoints: Vec[];
  /** How many of each Powerup (by id) the Map hides in its Crates every Round. */
  powerupPool: Record<string, number>;
}

/** What tells one Tile from another where a Tile is a key. */
export const tileKey = (tile: Vec) => `${tile.x},${tile.y}`;

/** The Tile a key was made from. */
export const tileOfKey = (key: string): Vec => {
  const [x, y] = key.split(',').map(Number);
  return { x, y };
};

export const sameTile = (a: Vec, b: Vec) => a.x === b.x && a.y === b.y;

const SYMBOLS: Record<string, Tile> = { '#': 'wall', x: 'crate' };

/** Builds a Map from text rows: "#" Wall, "x" Crate, "S" Spawn Point, anything else Floor. */
export function mapFromRows(rows: readonly string[], powerupPool: Record<string, number> = {}): MapData {
  const map: MapData = { size: { x: rows[0].length, y: rows.length }, tiles: [], spawnPoints: [], powerupPool };
  for (let y = 0; y < map.size.y; y++) {
    for (let x = 0; x < map.size.x; x++) {
      map.tiles.push(SYMBOLS[rows[y][x]] ?? 'floor');
      if (rows[y][x] === 'S') map.spawnPoints.push({ x, y });
    }
  }
  return map;
}

/** Anything outside the Map counts as Wall. */
export function tileAt(map: Pick<MapData, 'size' | 'tiles'>, tile: Vec): Tile {
  if (tile.x < 0 || tile.y < 0 || tile.x >= map.size.x || tile.y >= map.size.y) return 'wall';
  return map.tiles[tile.y * map.size.x + tile.x];
}

const distanceSquared = (a: Vec, b: Vec) => (a.x - b.x) ** 2 + (a.y - b.y) ** 2;

/**
 * The `count` Spawn Points farthest apart: the farthest pair first, then whichever remaining one
 * is farthest from those already chosen.
 */
export function farthestSpawnPoints(map: MapData, count: number): Vec[] {
  let chosen: Vec[] = [];
  let best = -1;
  for (const a of map.spawnPoints) {
    for (const b of map.spawnPoints) {
      if (distanceSquared(a, b) > best) {
        best = distanceSquared(a, b);
        chosen = [a, b];
      }
    }
  }
  while (chosen.length < Math.min(count, map.spawnPoints.length)) {
    const nearestChosen = (point: Vec) => Math.min(...chosen.map((other) => distanceSquared(point, other)));
    const remaining = map.spawnPoints.filter((point) => !chosen.includes(point));
    chosen.push(remaining.reduce((far, point) => (nearestChosen(point) > nearestChosen(far) ? point : far)));
  }
  return chosen.slice(0, count);
}
