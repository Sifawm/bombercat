import { type Board, type Cat, tileOf } from './board';
import { sameTile, type Vec } from './map';

export const EPSILON = 0.0001;

const moveToward = (from: number, to: number, delta: number) =>
  Math.abs(to - from) <= delta ? to : from + Math.sign(to - from) * delta;

/**
 * Moves a Cat along the grid. A Cat always has at least one coordinate on a whole number (it walks
 * along rows and columns), may move freely within Tiles it already overlaps, and may only start
 * overlapping a new Tile if that Tile is walkable. That alone gives the Bomb rule: its owner
 * overlaps the Bomb's Tile until fully off it, and then cannot re-enter. A Cat whose centre reaches the
 * centre of a Portal goes on from the other one.
 *
 * Returns the Tile that stopped the Cat walking straight ahead, or null. This is the twin of
 * `movement.gd`, which a client predicts with: the two must move a Cat in the same way (ADR 0004).
 * A position there is a Vector2, whose coordinates are 32-bit, so every coordinate written here is
 * rounded to 32 bits too. Without it the two disagree where a Cat is exactly at the reach of the
 * corner assist or halfway between two Tiles.
 */
export function move(cat: Cat, board: Board, direction: Vec, distance: number, cornerAssist: number): Vec | null {
  if (cat.portalArrival && !sameTile(tileOf(cat.position), cat.portalArrival)) cat.portalArrival = null;
  if (direction.x === 0 && direction.y === 0) return null;
  cat.facing = direction;
  const along = direction.x !== 0 ? 'x' : 'y';
  const across = along === 'x' ? 'y' : 'x';
  const step = direction[along];
  const position = { ...cat.position };
  const tileOn = (alongValue: number, acrossValue: number): Vec =>
    along === 'x' ? { x: alongValue, y: acrossValue } : { x: acrossValue, y: alongValue };

  // Corner assist: off the row or column it wants to walk along, the Cat first slides to the
  // nearest one (within reach) from which the way ahead is open.
  if (Math.abs(position[across] - Math.round(position[across])) > EPSILON) {
    const ahead = Math.round(position[along]) + step;
    const lanes = [Math.floor(position[across]), Math.ceil(position[across])];
    if (position[across] - lanes[0] > lanes[1] - position[across]) lanes.reverse();
    const target = lanes.find(
      (lane) => Math.abs(lane - position[across]) <= cornerAssist && board.isWalkable(tileOn(ahead, lane)),
    );
    // Stopped by whatever is ahead on the nearest row or column.
    if (target === undefined) return tileOn(ahead, lanes[0]);
    const slide = Math.min(distance, Math.abs(target - position[across]));
    position[across] = Math.fround(moveToward(position[across], target, slide));
    distance -= slide;
    if (Math.abs(position[across] - target) > EPSILON) {
      cat.position = position;
      return null;
    }
    position[across] = target;
    arrive(cat, board, position);
  }

  while (distance > EPSILON) {
    const onCentre = Math.abs(position[along] - Math.round(position[along])) < EPSILON;
    if (onCentre) position[along] = Math.round(position[along]);
    // The next Tile centre ahead. Between centres the Cat already overlaps that Tile.
    const next = onCentre ? position[along] + step : step > 0 ? Math.ceil(position[along]) : Math.floor(position[along]);
    const tile = tileOn(next, Math.round(position[across]));
    if (onCentre && !board.isWalkable(tile)) {
      cat.position = position;
      return tile;
    }
    const travelled = Math.min(distance, Math.abs(next - position[along]));
    position[along] = Math.fround(moveToward(position[along], next, travelled));
    distance -= travelled;
    // Steps of a 32-bit length can end a hair short of the centre: that is reaching it.
    if (Math.abs(position[along] - next) < EPSILON) {
      position[along] = next;
      arrive(cat, board, position);
    }
  }
  cat.position = position;
  return null;
}

/** A Cat whose centre has just reached a Tile centre, `position`, goes on from the other Portal if that Tile is one that may send it there. */
function arrive(cat: Cat, board: Board, position: Vec): void {
  const tile = tileOf(position);
  const exit = board.portalExit(tile);
  if (!exit || (cat.portalArrival && sameTile(tile, cat.portalArrival))) return;
  cat.portalArrival = exit;
  position.x = exit.x;
  position.y = exit.y;
}
