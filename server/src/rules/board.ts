import { type MapData, type Tile, tileAt, tileKey, type Vec } from './map';

export interface Bomb {
  tile: Vec;
  /** Index of the Player whose Cat placed it. */
  owner: number;
  range: number;
  /** Seconds until it detonates. */
  fuseLeft: number;
  /** Direction it is sliding in after a push, or zero at rest. */
  slide: Vec;
  /** How far (0 to 1) it has slid towards the next Tile. */
  slideProgress: number;
}

/** A temporary handicap on a Cat. What it does to the Cat's commands is in `CURSES`, by id. */
export interface Curse {
  id: string;
  timeLeft: number;
}

export interface Cat {
  /** Continuous position in Tile units; Tile centres are at whole numbers. */
  position: Vec;
  facing: Vec;
  alive: boolean;
  speed: number;
  bombCapacity: number;
  bombRange: number;
  /** How many of this Cat's Bombs are on the Map right now. */
  activeBombs: number;
  /** Tallies of this Round, for the Match summary. */
  bombsPlaced: number;
  cratesDestroyed: number;
  /** Ids of the Powerups collected this Round, in order. */
  collected: string[];
  pawSwipe: boolean;
  nineLives: boolean;
  /** Seconds left during which Explosions cannot hurt this Cat. */
  invulnerableLeft: number;
  /** The active Curse, if any. */
  curse: Curse | null;
}

/** The Tile under a position's centre. Positions are never negative, so halves round away from zero. */
export const tileOf = (position: Vec): Vec => ({ x: Math.round(position.x), y: Math.round(position.y) });

/** The grid of Tiles during a Round and what occupies each one. Its maps are keyed with `tileKey`. */
export class Board {
  readonly size: Vec;
  readonly bombs = new Map<string, Bomb>();
  /** Tiles under an active Explosion and the seconds each stays lethal. */
  readonly explosions = new Map<string, number>();
  /** Ids of the Powerups lying on the Floor. */
  readonly powerups = new Map<string, string>();
  /** Ids of the Powerups still inside their Crates. */
  readonly hiddenPowerups = new Map<string, string>();
  readonly tiles: Tile[];

  constructor(map: MapData) {
    this.size = map.size;
    this.tiles = [...map.tiles];
  }

  tileAt(tile: Vec): Tile {
    return tileAt(this, tile);
  }

  /** Whether a Cat that does not already overlap this Tile may enter it. */
  isWalkable(tile: Vec): boolean {
    return this.tileAt(tile) === 'floor' && !this.bombs.has(tileKey(tile));
  }

  destroyCrate(tile: Vec): void {
    this.tiles[tile.y * this.size.x + tile.x] = 'floor';
  }
}
