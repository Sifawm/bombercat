import { Board, type Bomb, type Cat, tileOf } from './board';
import type { GameConfig, RandomInt } from './config';
import { randomInt } from './config';
import { type MapData, sameTile, tileAt, tileKey, type Vec } from './map';
import { EPSILON, move } from './movement';
import type { RoundEvent } from '@bombercat/shared';
import { CURSES, distributePowerups, POWERUPS } from './powerups';

export type { RoundEvent };

export const DRAW = -1;

const ZERO: Vec = { x: 0, y: 0 };
const DIRECTIONS: Vec[] = [
  { x: 0, y: -1 },
  { x: 0, y: 1 },
  { x: -1, y: 0 },
  { x: 1, y: 0 },
];

/**
 * One fight on a fresh Board. The whole simulation: Players issue commands, `step` advances
 * everything by a fixed delta and returns what happened, and `board`, `cats` and `bombs` are there
 * to be read. The same commands on the same steps always give the same Round.
 */
export class Round {
  readonly board: Board;
  /** One per Player, by Player index. */
  readonly cats: Cat[] = [];
  /** In the order they were placed. */
  readonly bombs: Bomb[] = [];
  timeLeft: number;
  finished = false;

  private readonly moves: Vec[] = [];
  private readonly bombRequests: boolean[] = [];
  private readonly forfeits = new Set<number>();
  /**
   * Crates reached by this step's Explosions. They stay on the Board until every Bomb of the step
   * has detonated, so a Chain Reaction still clears a single layer of Crates. Each goes with the
   * Player whose Bomb reached it first.
   */
  private readonly doomedCrates = new Map<string, { tile: Vec; owner: number }>();
  private happened: RoundEvent[] = [];

  /**
   * `spawnPoints` holds one Spawn Point per Player. `random` decides everything left to chance;
   * pass a seeded one to get a reproducible Round. The Players in `absent` have no Cat to fight
   * with: theirs is out from the start.
   */
  constructor(
    map: MapData,
    readonly config: GameConfig,
    spawnPoints: readonly Vec[],
    private readonly random: RandomInt = randomInt,
    absent: readonly number[] = [],
  ) {
    this.board = new Board(map);
    const crates: Vec[] = [];
    for (let y = 0; y < map.size.y; y++) {
      for (let x = 0; x < map.size.x; x++) {
        if (tileAt(map, { x, y }) === 'crate') crates.push({ x, y });
      }
    }
    for (const [tile, powerup] of distributePowerups(map.powerupPool, crates, random)) {
      // An unknown id is a problem of the Map; a Round just leaves it out.
      if (Object.hasOwn(POWERUPS, powerup)) this.board.hiddenPowerups.set(tile, powerup);
    }
    this.timeLeft = config.roundTime;
    for (const tile of spawnPoints) {
      this.cats.push({
        position: { ...tile },
        facing: { x: 0, y: 1 },
        alive: !absent.includes(this.cats.length),
        speed: config.catSpeed,
        bombCapacity: config.bombCapacity,
        bombRange: config.bombRange,
        activeBombs: 0,
        bombsPlaced: 0,
        cratesDestroyed: 0,
        collected: [],
        pawSwipe: false,
        nineLives: false,
        invulnerableLeft: 0,
        curse: null,
      });
      this.moves.push(ZERO);
      this.bombRequests.push(false);
    }
  }

  /** Command: the Player's Cat walks in `direction` (a unit axis vector) until told otherwise; zero stops it. */
  setMove(player: number, direction: Vec): void {
    // Reduced to one unit axis step, whatever a controller sends.
    this.moves[player] = direction.x !== 0 ? { x: Math.sign(direction.x), y: 0 } : { x: 0, y: Math.sign(direction.y) };
  }

  /** Command: the Player's Cat places a Bomb on its Tile at the next step, if it can. */
  placeBomb(player: number): void {
    this.bombRequests[player] = true;
  }

  /** Command: the Player gives up its Cat, which is out of the Round at the next step. */
  forfeit(player: number): void {
    this.forfeits.add(player);
  }

  step(delta: number): RoundEvent[] {
    if (this.finished) return [];
    this.happened = [];
    for (const player of this.forfeits) if (this.cats[player].alive) this.eliminate(player);
    this.forfeits.clear();
    const { board, cats, config } = this;
    cats.forEach((cat, player) => {
      if (!cat.alive) return;
      if (this.bombRequests[player]) this.placeBombOf(player);
      let direction = this.moves[player];
      let speed = cat.speed;
      if (cat.curse !== null) {
        const effect = CURSES[cat.curse.id];
        direction = effect.redirect?.(direction) ?? direction;
        speed *= effect.speedFactor?.(config) ?? 1;
      }
      const blocked = move(cat, board, direction, speed * delta, config.cornerAssist);
      const pushed = blocked && board.bombs.get(tileKey(blocked));
      if (cat.pawSwipe && pushed && !sameTile(pushed.slide, direction)) {
        pushed.slide = direction;
        pushed.slideProgress = 0;
      }
      this.collect(player);
      this.tickEffects(player, delta);
    });
    this.bombRequests.fill(false);

    for (const bomb of [...this.bombs]) {
      if (!this.bombs.includes(bomb)) continue; // went off in a Chain Reaction earlier in this step
      this.slide(bomb, delta);
      bomb.fuseLeft -= delta;
      if (bomb.fuseLeft <= 0 || board.explosions.has(tileKey(bomb.tile))) this.detonate(bomb);
    }
    // Powerups come out only now, so the Explosion that broke a Crate cannot destroy what was in it.
    for (const [key, { tile, owner }] of this.doomedCrates) {
      board.destroyCrate(tile);
      cats[owner].cratesDestroyed += 1;
      this.happened.push({ type: 'crateDestroyed', tile, owner });
      const powerup = board.hiddenPowerups.get(key);
      if (powerup !== undefined) {
        board.hiddenPowerups.delete(key);
        board.powerups.set(key, powerup);
        this.happened.push({ type: 'powerupRevealed', tile, powerup });
      }
    }
    this.doomedCrates.clear();

    cats.forEach((cat, player) => {
      if (!cat.alive || cat.invulnerableLeft > 0 || !board.explosions.has(tileKey(tileOf(cat.position)))) return;
      if (cat.nineLives) {
        cat.nineLives = false;
        cat.invulnerableLeft = config.nineLivesInvulnerability;
        this.happened.push({ type: 'nineLivesConsumed', player });
      } else {
        this.eliminate(player);
      }
    });
    for (const [key, left] of board.explosions) {
      if (left - delta <= 0) board.explosions.delete(key);
      else board.explosions.set(key, left - delta);
    }

    this.timeLeft -= delta;
    const alive = cats.flatMap((cat, player) => (cat.alive ? [player] : []));
    // With one Cat left the Round waits for the Explosions to burn out: if they kill that Cat too,
    // both died in the same Explosion and it is a Draw.
    if (alive.length === 0) this.finish(DRAW);
    else if (alive.length === 1 && board.explosions.size === 0) this.finish(alive[0]);
    else if (this.timeLeft <= 0) this.finish(DRAW);
    return this.happened;
  }

  private eliminate(player: number): void {
    const cat = this.cats[player];
    cat.alive = false;
    if (cat.curse !== null) {
      this.happened.push({ type: 'curseEnded', player, curse: cat.curse.id });
      cat.curse = null;
    }
    this.happened.push({ type: 'catEliminated', player });
  }

  private collect(player: number): void {
    const cat = this.cats[player];
    const tile = tileOf(cat.position);
    const key = tileKey(tile);
    const powerup = this.board.powerups.get(key);
    if (powerup === undefined) return;
    const curseBefore = cat.curse;
    this.board.powerups.delete(key);
    cat.collected.push(powerup);
    POWERUPS[powerup].apply(cat, this.config, this.random);
    this.happened.push({ type: 'powerupCollected', player, tile, powerup });
    if (cat.curse !== null && cat.curse !== curseBefore) {
      if (curseBefore !== null) this.happened.push({ type: 'curseEnded', player, curse: curseBefore.id });
      this.happened.push({ type: 'curseStarted', player, curse: cat.curse.id });
    }
  }

  /** Runs down the Cat's timed effects. */
  private tickEffects(player: number, delta: number): void {
    const cat = this.cats[player];
    cat.invulnerableLeft = Math.max(cat.invulnerableLeft - delta, 0);
    if (cat.curse === null) return;
    cat.curse.timeLeft -= delta;
    if (cat.curse.timeLeft <= 0) {
      this.happened.push({ type: 'curseEnded', player, curse: cat.curse.id });
      cat.curse = null;
    }
  }

  /** Advances a pushed Bomb Tile by Tile until something is in its way. */
  private slide(bomb: Bomb, delta: number): void {
    if (bomb.slide.x === 0 && bomb.slide.y === 0) return;
    bomb.slideProgress += this.config.bombSlideSpeed * delta;
    while (bomb.slide.x !== 0 || bomb.slide.y !== 0) {
      const next = { x: bomb.tile.x + bomb.slide.x, y: bomb.tile.y + bomb.slide.y };
      // A Cat is in the way if any part of it is on the Tile, not just its centre.
      const catInTheWay = this.cats.some(
        // The gap is a Vector2 in `round.gd`: 32-bit, like the positions (see `move`).
        (cat) =>
          cat.alive &&
          Math.fround(Math.max(Math.abs(cat.position.x - next.x), Math.abs(cat.position.y - next.y))) < 1 - EPSILON,
      );
      if (!this.board.isWalkable(next) || catInTheWay) {
        bomb.slide = ZERO;
        bomb.slideProgress = 0;
      } else if (bomb.slideProgress >= 1) {
        const from = bomb.tile;
        this.board.bombs.delete(tileKey(from));
        this.board.bombs.set(tileKey(next), bomb);
        bomb.tile = next;
        bomb.slideProgress -= 1;
        this.happened.push({ type: 'bombMoved', from, to: next });
      } else {
        break;
      }
    }
  }

  private placeBombOf(player: number): void {
    const cat = this.cats[player];
    const tile = tileOf(cat.position);
    if (cat.activeBombs >= cat.bombCapacity || this.board.bombs.has(tileKey(tile))) return;
    const bomb: Bomb = { tile, owner: player, range: cat.bombRange, fuseLeft: this.config.fuse, slide: ZERO, slideProgress: 0 };
    cat.activeBombs += 1;
    cat.bombsPlaced += 1;
    this.bombs.push(bomb);
    this.board.bombs.set(tileKey(tile), bomb);
    this.happened.push({ type: 'bombPlaced', tile, owner: player, range: bomb.range });
  }

  /** Detonates `first` and, as Chain Reactions, every Bomb its Explosion reaches. */
  private detonate(first: Bomb): void {
    const { board } = this;
    board.bombs.delete(tileKey(first.tile));
    const pending = [first];
    for (let bomb = pending.shift(); bomb !== undefined; bomb = pending.shift()) {
      this.bombs.splice(this.bombs.indexOf(bomb), 1);
      this.cats[bomb.owner].activeBombs -= 1;
      const tiles = [bomb.tile];
      for (const direction of DIRECTIONS) {
        for (let distance = 1; distance <= bomb.range; distance++) {
          const tile = { x: bomb.tile.x + direction.x * distance, y: bomb.tile.y + direction.y * distance };
          const kind = board.tileAt(tile);
          if (kind === 'wall') break;
          tiles.push(tile);
          const key = tileKey(tile);
          if (kind === 'crate') {
            if (!this.doomedCrates.has(key)) this.doomedCrates.set(key, { tile, owner: bomb.owner });
            break;
          }
          const reached = board.bombs.get(key);
          if (reached !== undefined) {
            pending.push(reached);
            board.bombs.delete(key);
          }
        }
      }
      for (const tile of tiles) {
        const key = tileKey(tile);
        board.explosions.set(key, this.config.explosionLifetime);
        const powerup = board.powerups.get(key);
        if (powerup !== undefined) {
          this.happened.push({ type: 'powerupDestroyed', tile, powerup });
          board.powerups.delete(key);
        }
      }
      this.happened.push({ type: 'bombDetonated', tile: bomb.tile, tiles });
    }
  }

  private finish(winner: number): void {
    this.finished = true;
    this.happened.push({ type: 'roundEnded', winner });
  }
}
