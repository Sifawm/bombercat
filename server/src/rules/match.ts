import type { GameConfig, RandomInt } from './config';
import { randomInt } from './config';
import { farthestSpawnPoints, type MapData, type Vec } from './map';
import { DRAW, Round, type RoundEvent } from './round';

export type MatchEvent = RoundEvent | { type: 'matchEnded'; winner: number };

/**
 * A Battle between the same Cats: Rounds on one Map until a Player has won enough of them. A Draw
 * awards nothing, so it is simply followed by another Round.
 */
export class Match {
  /** Rounds won, by Player index. */
  readonly wins: number[];
  /** Totals over every Round played so far, by Player index. */
  readonly bombsPlaced: number[];
  readonly cratesDestroyed: number[];
  readonly powerupsCollected: number[];
  currentRound!: Round;
  finished = false;
  /** The Player who won the Match, once it is finished. */
  winner = -1;

  private readonly spawnPoints: Vec[];

  /** `random` is handed to every Round; pass a seeded one to get a reproducible Match. */
  constructor(
    private readonly map: MapData,
    readonly config: GameConfig,
    players = 2,
    private readonly random: RandomInt = randomInt,
  ) {
    if (players > map.spawnPoints.length) throw new Error(`${players} Players on a Map with ${map.spawnPoints.length} Spawn Points`);
    this.spawnPoints = farthestSpawnPoints(map, players);
    const tally = () => new Array<number>(players).fill(0);
    [this.wins, this.bombsPlaced, this.cratesDestroyed, this.powerupsCollected] = [tally(), tally(), tally(), tally()];
  }

  /**
   * Starts the next Round on the restored Map; every Cat is back to its starting abilities. The
   * Round takes the commands, but it is the Match that is stepped, or the Round is never counted.
   * The Players in `absent` take no part in it.
   */
  startRound(absent: readonly number[] = []): Round {
    this.currentRound = new Round(this.map, this.config, this.spawnPoints, this.random, absent);
    return this.currentRound;
  }

  /** Advances the current Round and counts it once it ends. */
  step(delta: number): MatchEvent[] {
    const events: MatchEvent[] = [...this.currentRound.step(delta)];
    const ended = events.find((event) => event.type === 'roundEnded');
    if (ended === undefined) return events;
    this.currentRound.cats.forEach((cat, player) => {
      this.bombsPlaced[player] += cat.bombsPlaced;
      this.cratesDestroyed[player] += cat.cratesDestroyed;
      this.powerupsCollected[player] += cat.collected.length;
    });
    if (ended.winner === DRAW) return events;
    this.wins[ended.winner] += 1;
    if (this.wins[ended.winner] >= this.config.roundsToWin) {
      this.finished = true;
      this.winner = ended.winner;
      events.push({ type: 'matchEnded', winner: this.winner });
    }
    return events;
  }
}
