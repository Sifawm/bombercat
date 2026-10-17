import { type MapData, tileAt, type Vec } from './map';
import { POWERUPS } from './powerups';

const UP = { x: 0, y: -1 };
const DOWN = { x: 0, y: 1 };
const LEFT = { x: -1, y: 0 };
const RIGHT = { x: 1, y: 0 };
const add = (a: Vec, b: Vec) => ({ x: a.x + b.x, y: a.y + b.y });
const written = (tile: Vec) => `(${tile.x}, ${tile.y})`;

/** Finds what would make a Map unplayable. */
export function mapProblems(map: MapData): string[] {
  const found: string[] = [];
  if (map.spawnPoints.length < 2) {
    found.push(`A Map needs at least 2 Spawn Points; this one has ${map.spawnPoints.length}.`);
  }

  // A Cat escapes its first Bomb around a corner, so it needs an L of free Tiles.
  const isFree = (tile: Vec) => tileAt(map, tile) === 'floor';
  for (const point of map.spawnPoints) {
    const sideways = isFree(add(point, LEFT)) || isFree(add(point, RIGHT));
    const upright = isFree(add(point, UP)) || isFree(add(point, DOWN));
    if (!(sideways && upright)) {
      found.push(
        `The Spawn Point at ${written(point)} has no room to escape its first Bomb: ` +
          'it needs a free Tile beside it and another above or below it.',
      );
    }
  }

  let powerups = 0;
  for (const [powerup, quantity] of Object.entries(map.powerupPool)) {
    powerups += quantity;
    if (!Object.hasOwn(POWERUPS, powerup)) found.push(`The Powerup Pool names "${powerup}", which is not a Powerup.`);
  }
  const crates = map.tiles.filter((tile) => tile === 'crate').length;
  if (powerups > crates) {
    found.push(`The Powerup Pool holds ${powerups} Powerups but the Map has only ${crates} Crates.`);
  }

  const portals = new Map<number, number>();
  for (const colour of map.portals.values()) portals.set(colour, (portals.get(colour) ?? 0) + 1);
  for (const [colour, count] of portals) {
    if (count !== 2) found.push(`There are ${count} Portals of colour ${colour}; a colour needs exactly 2.`);
  }

  const openBorder: Vec[] = [];
  for (let y = 0; y < map.size.y; y++) {
    for (let x = 0; x < map.size.x; x++) {
      const onBorder = x === 0 || y === 0 || x === map.size.x - 1 || y === map.size.y - 1;
      if (onBorder && tileAt(map, { x, y }) !== 'wall') openBorder.push({ x, y });
    }
  }
  if (openBorder.length > 0) {
    found.push(
      `The Map is not enclosed: ${openBorder.length} border Tiles are not a Wall, the first at ${written(openBorder[0])}.`,
    );
  }
  return found;
}
