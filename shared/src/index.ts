import type { GameDefinition } from '@porterkit/contracts';

/** How many Cats there are to choose from: the length of `Roster.CATS` in the Godot project. */
export const CAT_COUNT = 5;

/** What a User brings into the Room: the index of its Cat. */
export type Profile = { cat: number };

export const isProfile = (profile: unknown): profile is Profile => {
  const cat = (profile as { cat?: unknown } | null)?.cat;
  return Number.isInteger(cat) && (cat as number) >= 0 && (cat as number) < CAT_COUNT;
};

/** The Game itself. It has no Match yet: a Room is only somewhere to meet. */
export type Bombercat = {
  settings: object;
  state: object;
  userData: object;
  client: {};
  server: {};
  pauseReason: null;
  endReason: never;
  rejectReason: never;
};

/** Where everything is after one Tick, the size of what a full Round will send. */
export type ProbeSnapshot = {
  tick: number;
  cats: { x: number; y: number; seq: number }[];
  bombs: { x: number; y: number; fuse: number }[];
};

/** Measures what the bridge to Godot costs at the rate a Match will run. Not part of the game. */
export type BridgeProbe = {
  settings: object;
  state: object;
  userData: object;
  client: {};
  server: { moved: ProbeSnapshot };
  pauseReason: null;
  endReason: never;
  rejectReason: never;
};

export type Games = { bombercat: Bombercat; bridgeProbe: BridgeProbe };

/** Ticks a second, of the server and of a client's Prediction (ADR 0004). */
export const TICK_RATE = 60;

const nothing = () => ({});
const noSettings = () => ({ set(_settings: object) {} });

export const bombercat = {
  name: 'bombercat',
  minPlayers: 2,
  createSettings: noSettings,
  createState: nothing,
  createUserData: nothing,
} satisfies GameDefinition<Games, 'bombercat'>;

export const bridgeProbe = {
  name: 'bridgeProbe',
  minPlayers: 1,
  tickRate: TICK_RATE,
  createSettings: noSettings,
  createState: nothing,
  createUserData: nothing,
} satisfies GameDefinition<Games, 'bridgeProbe'>;
