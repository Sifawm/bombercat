import type { Cat } from './board';
import type { GameConfig, RandomInt } from './config';
import { tileKey, type Vec } from './map';

/**
 * What a Curse does to its Cat's commands while it lasts. It changes nothing on the Cat itself, so
 * there is nothing to undo when it ends.
 */
export interface CurseEffect {
  /** The direction the Cat actually walks when its Player commands `direction`. */
  redirect?(direction: Vec): Vec;
  /** Multiplier on the Cat's speed. */
  speedFactor?(config: GameConfig): number;
}

export const CURSES: Record<string, CurseEffect> = {
  inverted_controls: { redirect: (direction) => ({ x: -direction.x, y: -direction.y }) },
  slowness: { speedFactor: (config) => config.slownessFactor },
};

/** Something a Cat gains by walking over it. */
export interface Powerup {
  /** Changes `cat` for the rest of the Round. `random` is the Round's only source of chance. */
  apply(cat: Cat, config: GameConfig, random: RandomInt): void;
  /** Whether a Cat that collected this Powerup still has it. Most last the whole Round. */
  isHeldBy?(cat: Cat): boolean;
}

/** Every Powerup by id. Adding a Powerup means adding an entry here (and its model in the game). */
export const POWERUPS: Record<string, Powerup> = {
  yarn_ball: {
    apply: (cat, config) => void (cat.bombCapacity = Math.min(cat.bombCapacity + 1, config.maxBombCapacity)),
  },
  tuna_can: {
    apply: (cat, config) => void (cat.bombRange = Math.min(cat.bombRange + 1, config.maxBombRange)),
  },
  catnip: {
    apply: (cat, config) => void (cat.speed = Math.min(cat.speed + config.catnipSpeedGain, config.maxCatSpeed)),
  },
  paw_swipe: { apply: (cat) => void (cat.pawSwipe = true) },
  // A flag, not a count: Nine Lives does not stack.
  nine_lives: { apply: (cat) => void (cat.nineLives = true), isHeldBy: (cat) => cat.nineLives },
  cucumber: {
    apply(cat, config, random) {
      const curses = Object.keys(CURSES);
      cat.curse = { id: curses[random(0, curses.length - 1)], timeLeft: config.curseDuration };
    },
    isHeldBy: (cat) => cat.curse !== null,
  },
};

/** The ids of the Powerups `cat` collected and still has, in the order it collected them. */
export const heldBy = (cat: Cat): string[] => cat.collected.filter((id) => POWERUPS[id].isHeldBy?.(cat) ?? true);

/**
 * Hides a Map's Powerup Pool in its Crates: the quantities are fixed, the Crates are random.
 * Returns which Powerup (by id) each chosen Crate holds, keyed with `tileKey`. A pool larger than
 * `crates` fills them all.
 */
export function distributePowerups(pool: Record<string, number>, crates: readonly Vec[], random: RandomInt): Map<string, string> {
  const shuffled = [...crates];
  // Fisher-Yates, on the injected random source.
  for (let index = shuffled.length - 1; index > 0; index--) {
    const other = random(0, index);
    [shuffled[index], shuffled[other]] = [shuffled[other], shuffled[index]];
  }
  const hidden = new Map<string, string>();
  for (const [powerup, quantity] of Object.entries(pool)) {
    for (let count = 0; count < quantity && hidden.size < shuffled.length; count++) {
      hidden.set(tileKey(shuffled[hidden.size]), powerup);
    }
  }
  return hidden;
}
