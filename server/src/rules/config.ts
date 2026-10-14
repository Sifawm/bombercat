/** Every tunable balance value. The rules receive it and never hard-code numbers. */
export interface GameConfig {
  /** Tiles per second. */
  catSpeed: number;
  /** How far (in Tiles) a Cat may be from a corridor and still slide into it when turning. */
  cornerAssist: number;
  bombCapacity: number;
  bombRange: number;
  maxBombCapacity: number;
  maxBombRange: number;
  maxCatSpeed: number;
  /** Seconds between placing a Bomb and its detonation. */
  fuse: number;
  /** Seconds an Explosion stays lethal. */
  explosionLifetime: number;
  /** Tiles per second of a Bomb pushed with Paw Swipe. */
  bombSlideSpeed: number;
  /** Tiles per second added by each Catnip. */
  catnipSpeedGain: number;
  /** Seconds a Cat cannot be hurt after Nine Lives absorbs an Explosion. */
  nineLivesInvulnerability: number;
  /** Seconds a Curse lasts. */
  curseDuration: number;
  /** Speed multiplier under the slowness Curse. */
  slownessFactor: number;
  /** Seconds before a Round ends in a Draw. */
  roundTime: number;
  /** Round wins that win a Match. */
  roundsToWin: number;
}

/** The Round's only source of chance: a whole number from `from` to `to`, both included. */
export type RandomInt = (from: number, to: number) => number;

export const randomInt: RandomInt = (from, to) => from + Math.floor(Math.random() * (to - from + 1));

/** The same numbers for the same seed, for a reproducible Round. */
export function seededRandomInt(seed: number): RandomInt {
  let state = seed >>> 0;
  return (from, to) => {
    // mulberry32
    state = (state + 0x6d2b79f5) >>> 0;
    let mixed = Math.imul(state ^ (state >>> 15), state | 1);
    mixed ^= mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61);
    return from + Math.floor((((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296) * (to - from + 1));
  };
}
