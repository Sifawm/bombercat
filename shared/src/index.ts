import type { GameDefinition } from '@porterkit/contracts';
import config from './config.json' with { type: 'json' };
import backyard from './maps/backyard.json' with { type: 'json' };

/** The balance values, as the Godot project exports them (ADR 0003). */
export const balance = config;

/** Every Map by name, as the Godot project exports them: text rows and a Powerup Pool. */
export const maps = { backyard };

/** How many Cats there are to choose from: the length of `Roster.CATS` in the Godot project. */
export const CAT_COUNT = 5;

/** What a User brings into the Room: the index of its Cat. */
export type Profile = { cat: number };

export const isProfile = (profile: unknown): profile is Profile => {
  const cat = (profile as { cat?: unknown } | null)?.cat;
  return Number.isInteger(cat) && (cat as number) >= 0 && (cat as number) < CAT_COUNT;
};

export type MapName = keyof typeof maps;

/** A Tile's coordinates, or a continuous position in Tile units: Tile centres are at whole numbers. */
export interface Vec {
  x: number;
  y: number;
}

/** What the Admin may change between Matches. */
export interface Settings {
  map: MapName;
  /** Round wins that win a Match. */
  roundsToWin: number;
  /** Seconds before a Round ends in a Draw. */
  roundTime: number;
}

export const isSettings = (settings: unknown): settings is Settings => {
  const { map, roundsToWin, roundTime } = (settings ?? {}) as Record<string, unknown>;
  const whole = (value: unknown, from: number, to: number) =>
    Number.isInteger(value) && (value as number) >= from && (value as number) <= to;
  return typeof map === 'string' && Object.hasOwn(maps, map) && whole(roundsToWin, 1, 5) && whole(roundTime, 30, 300);
};

/** What happened in a step of a Round. Tiles are copies: they stay as they were when it happened. */
export type RoundEvent =
  | { type: 'bombPlaced'; tile: Vec; owner: number; range: number }
  /** A pushed Bomb slid from the Tile `from` onto `to`. */
  | { type: 'bombMoved'; from: Vec; to: Vec }
  | { type: 'bombDetonated'; tile: Vec; tiles: Vec[] }
  /** `owner` is the Player whose Bomb reached the Crate first. */
  | { type: 'crateDestroyed'; tile: Vec; owner: number }
  | { type: 'powerupRevealed'; tile: Vec; powerup: string }
  | { type: 'powerupCollected'; player: number; tile: Vec; powerup: string }
  | { type: 'powerupDestroyed'; tile: Vec; powerup: string }
  | { type: 'curseStarted'; player: number; curse: string }
  | { type: 'curseEnded'; player: number; curse: string }
  | { type: 'nineLivesConsumed'; player: number }
  | { type: 'catEliminated'; player: number }
  /** `winner` is a Player index or -1 for a Draw. */
  | { type: 'roundEnded'; winner: number };

export interface CatSnapshot {
  x: number;
  y: number;
  /** The direction it faces. */
  fx: number;
  fy: number;
  alive: boolean;
  speed: number;
  bombCapacity: number;
  bombRange: number;
  activeBombs: number;
  bombsPlaced: number;
  cratesDestroyed: number;
  collected: string[];
  pawSwipe: boolean;
  nineLives: boolean;
  invulnerableLeft: number;
  curse: { id: string; timeLeft: number } | null;
}

export interface BombSnapshot {
  x: number;
  y: number;
  owner: number;
  range: number;
  fuseLeft: number;
  /** The direction it is sliding in, and how far (0 to 1) towards the next Tile. */
  sx: number;
  sy: number;
  progress: number;
}

/** Everything about a Round that every User may know: not what its Crates still hide. */
export interface RoundSnapshot {
  timeLeft: number;
  /** The Map as it is now, in the text rows a Map is exported as: "#" Wall, "x" Crate, "." Floor. */
  rows: string[];
  bombs: BombSnapshot[];
  powerups: { x: number; y: number; id: string }[];
  cats: CatSnapshot[];
  finished: boolean;
}

/** The Game's state: the Match as far as it has got. Arrays go by Player index. */
export interface MatchState {
  /** The name of each Player's User. A User that is not here watches. */
  players: string[];
  wins: number[];
  bombsPlaced: number[];
  cratesDestroyed: number[];
  powerupsCollected: number[];
  round: RoundSnapshot | null;
}

/** What a Player asks of its Cat for one Tick. `seq` numbers them, for Prediction (ADR 0004). */
export interface Input {
  seq: number;
  x: number;
  y: number;
  bomb: boolean;
}

export const isInput = (input: unknown): input is Input => {
  const { seq, x, y, bomb } = (input ?? {}) as Record<string, unknown>;
  const axis = (value: unknown) => value === -1 || value === 0 || value === 1;
  return Number.isSafeInteger(seq) && axis(x) && axis(y) && typeof bomb === 'boolean';
};

/** Where everything that moves is after a Tick. `seq` is the last Input of that Player that was applied. */
export interface Moved {
  timeLeft: number;
  cats: { x: number; y: number; fx: number; fy: number; seq: number }[];
  /** The Bombs that are sliding, by the Tile each is on. */
  sliding: { x: number; y: number; sx: number; sy: number; progress: number }[];
}

/** The Game itself. */
export type Bombercat = {
  settings: Settings;
  state: MatchState;
  userData: object;
  client: { input: Input; meow: undefined; togglePause: undefined };
  server: {
    /** A Round is about to start, after a countdown: the whole state, which replaces the client's. */
    roundStarted: MatchState;
    /** A Round has ended: the whole state again, with the Round counted. */
    scored: MatchState;
    moved: Moved;
    happened: RoundEvent[];
    meowed: { player: number };
  };
  pauseReason: null;
  /** `winner` is a Player index, or null when the Match was left without one. */
  endReason: { winner: number | null };
  rejectReason: 'invalidSettings' | 'tooManyUsers' | 'notAPlayer';
};

export type Games = { bombercat: Bombercat };

/** Ticks a second, of the server and of a client's Prediction (ADR 0004). */
export const TICK_RATE = 60;

const nothing = () => ({});

class MatchSettings implements Settings {
  map: MapName = 'backyard';
  roundsToWin = balance.roundsToWin;
  roundTime = balance.roundTime;

  set(settings: Settings) {
    Object.assign(this, settings);
  }
}

export const bombercat = {
  name: 'bombercat',
  minPlayers: 2,
  tickRate: TICK_RATE,
  createSettings: () => new MatchSettings(),
  createState: (): MatchState => ({
    players: [],
    wins: [],
    bombsPlaced: [],
    cratesDestroyed: [],
    powerupsCollected: [],
    round: null,
  }),
  createUserData: nothing,
} satisfies GameDefinition<Games, 'bombercat'>;
