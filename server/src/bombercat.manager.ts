import {
  AdminOnly,
  AnyTime,
  type CanStart,
  type CreateMemory,
  type GameContext,
  GameManager,
  type GameManager as Manager,
  handlersOf,
  type OnContinue,
  type OnEnd,
  type OnPause,
  type OnStart,
  type OnTick,
  type OnUserDisconnected,
  type OnUserLeft,
  type UserOf,
} from '@porterkit/nestjs';
import {
  balance,
  bombercat,
  type Games,
  type Input,
  isInput,
  isSettings,
  maps,
  type MatchState,
  type RoundSnapshot,
  type Settings,
  TICK_RATE,
  type Vec,
} from '@bombercat/shared';
import { mapFromRows, tileOfKey } from './rules/map';
import { Match } from './rules/match';
import type { Round } from './rules/round';

const On = handlersOf<Games, 'bombercat'>();

interface Memory {
  /** Null until `onStart`. */
  match: Match | null;
  /** A Round is counted down to, played, and then left on screen for a moment; the last one stays, with the result. */
  phase: 'countdown' | 'playing' | 'over' | 'ended';
  paused: boolean;
  /** By Player index: the Inputs still to apply, the direction of the last one and its number. */
  inputs: Input[][];
  held: Vec[];
  applied: number[];
  /** The Players whose User left the Room. */
  gone: Set<number>;
  /** By Player index: when its last meow was, on the clock. */
  meowed: number[];
}

type Ctx = GameContext<Games, typeof bombercat, Memory>;
type MatchUser = UserOf<Games, typeof bombercat>;

/** How long each part of a Match around its Rounds lasts, in milliseconds. */
export const pacing = {
  /** The Cats drop in and "3, 2, 1" is counted: `CatView.DROP_SECONDS` plus the three seconds. */
  countdown: 3700,
  /** A finished Round stays on screen before the next one, or the result of the Match. */
  roundOver: 3000,
};

/** Inputs a Player may have waiting. One more and the oldest is dropped, so a Cat never lags far behind its keys. */
const MAX_WAITING = 3;
/** Milliseconds between two meows of the same Cat that the Room hears. */
const MEOW_EVERY = 400;
const STOP: Vec = { x: 0, y: 0 };
const SYMBOLS = { wall: '#', crate: 'x', floor: '.' };

/** The rules of BomberCat for one Room: it runs the Match and tells the Users what happens in it. */
@GameManager(bombercat)
export class BombercatManager
  implements
    Manager<Ctx>,
    CreateMemory<Ctx>,
    CanStart<Ctx>,
    OnStart<Ctx>,
    OnTick<Ctx>,
    OnPause<Ctx>,
    OnContinue<Ctx>,
    OnEnd<Ctx>,
    OnUserDisconnected<Ctx>,
    OnUserLeft<Ctx>
{
  defaultSettings(): Settings {
    return { map: 'backyard', roundsToWin: balance.roundsToWin, roundTime: balance.roundTime };
  }

  updateSettings(ctx: Ctx, next: unknown) {
    if (!isSettings(next)) throw ctx.reject('invalidSettings');
    ctx.game.settings.set(next);
  }

  createMemory(): Memory {
    return { match: null, phase: 'over', paused: false, inputs: [], held: [], applied: [], gone: new Set(), meowed: [] };
  }

  /**
   * Everyone connected plays, so they must fit on the Map and be enough for a Match. Porter's own
   * minimum also counts a User whose connection dropped, which would not play.
   */
  canStart(ctx: Ctx) {
    const { rows } = maps[ctx.game.settings.map];
    if (ctx.room.connected.length > mapFromRows(rows).spawnPoints.length) throw ctx.reject('tooManyUsers');
    if (ctx.room.connected.length < bombercat.minPlayers) throw ctx.reject('tooFewUsers');
  }

  onStart(ctx: Ctx) {
    const { map, roundsToWin, roundTime } = ctx.game.settings;
    const players = ctx.room.connected.map((user) => user.name);
    ctx.game.state.players = players;
    ctx.memory.match = new Match(
      mapFromRows(maps[map].rows, maps[map].powerupPool),
      { ...balance, roundsToWin, roundTime },
      players.length,
    );
    this.startRound(ctx);
  }

  onTick(ctx: Ctx) {
    const { memory, room } = ctx;
    const match = memory.match;
    if (match === null || memory.phase !== 'playing') return;
    const round = match.currentRound;
    round.cats.forEach((_cat, player) => {
      const input = memory.inputs[player].shift();
      if (input !== undefined) {
        memory.held[player] = { x: input.x, y: input.y };
        memory.applied[player] = input.seq;
        if (input.bomb) round.placeBomb(player);
      }
      // Without an Input the Cat keeps doing what the last one said.
      round.setMove(player, memory.held[player]);
    });
    const events = match.step(1 / TICK_RATE);
    this.writeState(ctx);
    // What happened goes first: a Bomb is on its new Tile before `moved` says how it slides on.
    if (events.length > 0) room.broadcast('happened', events.filter((event) => event.type !== 'matchEnded'));
    room.broadcast('moved', {
      timeLeft: round.timeLeft,
      cats: round.cats.map((cat, player) => ({
        x: cat.position.x,
        y: cat.position.y,
        fx: cat.facing.x,
        fy: cat.facing.y,
        seq: memory.applied[player],
        arrival: cat.portalArrival && { ...cat.portalArrival },
      })),
      sliding: round.bombs
        .filter((bomb) => bomb.slide.x !== 0 || bomb.slide.y !== 0)
        .map((bomb) => ({ ...bomb.tile, sx: bomb.slide.x, sy: bomb.slide.y, progress: bomb.slideProgress })),
    });
    if (!round.finished) return;
    room.broadcast('scored', ctx.game.state);
    memory.phase = 'over';
    ctx.timers.set('roundOver', pacing.roundOver, () => {
      if (match.finished) ctx.endMatch({ winner: match.winner });
      else this.startRound(ctx);
    });
  }

  onPause(ctx: Ctx) {
    ctx.memory.paused = true;
  }

  onContinue(ctx: Ctx) {
    ctx.memory.paused = false;
  }

  onEnd(ctx: Ctx) {
    ctx.memory.phase = 'ended';
  }

  /** Its Cat stands still, where an Explosion can reach it, until its User is back. */
  onUserDisconnected(ctx: Ctx, user: MatchUser) {
    const player = ctx.game.state.players.indexOf(user.name);
    if (player === -1) return;
    ctx.memory.inputs[player] = [];
    ctx.memory.held[player] = STOP;
  }

  /** Its Cat is out of this Round and of the rest of the Match. A Match with one Player left has no winner. */
  onUserLeft(ctx: Ctx, user: MatchUser) {
    const { memory } = ctx;
    const { players } = ctx.game.state;
    const player = players.indexOf(user.name);
    if (player === -1 || memory.match === null) return;
    memory.gone.add(player);
    ctx.game.state.gone = [...memory.gone];
    memory.match.currentRound.forfeit(player);
    if (players.length - memory.gone.size < 2) ctx.endMatch({ winner: null });
  }

  @On('input', isInput)
  input(ctx: Ctx, input: Input, user: MatchUser) {
    const waiting = ctx.memory.inputs[this.playerOf(ctx, user)];
    if (waiting === undefined || ctx.memory.phase !== 'playing') return;
    waiting.push(input);
    if (waiting.length <= MAX_WAITING) return;
    // The Bomb of a dropped Input is not lost: the next one places it.
    if (waiting.shift()!.bomb) waiting[0].bomb = true;
  }

  /** Any Player, and the Admin, may stop the Match for everyone and set it going again. */
  @On('pause')
  pause(ctx: Ctx, _data: undefined, user: MatchUser) {
    this.mayPause(ctx, user);
    ctx.pauseMatch(null);
  }

  @On('resume')
  resume(ctx: Ctx, _data: undefined, user: MatchUser) {
    this.mayPause(ctx, user);
    ctx.continueMatch();
  }

  /** A meow is for show only, and a Cat has only so many in it. */
  @On('meow')
  meow(ctx: Ctx, _data: undefined, user: MatchUser) {
    const player = this.playerOf(ctx, user);
    if (player === -1 || Date.now() - (ctx.memory.meowed[player] ?? 0) < MEOW_EVERY) return;
    ctx.memory.meowed[player] = Date.now();
    ctx.room.broadcast('meowed', { player });
  }

  @On('sync')
  sync(ctx: Ctx, _data: undefined, user: MatchUser) {
    user.send('synced', ctx.game.state);
  }

  /** The Admin takes everyone to the settings of the next Match, until it goes back or starts it. */
  @AdminOnly()
  @AnyTime()
  @On('configure')
  configure(ctx: Ctx) {
    if (ctx.room.connected.length < bombercat.minPlayers) throw ctx.reject('tooFewUsers');
    this.setConfiguring(ctx, true);
  }

  /** The Admin takes everyone back to choosing Cats: from the settings, or from the result of the last Match. */
  @AdminOnly()
  @AnyTime()
  @On('backToRoom')
  backToRoom(ctx: Ctx) {
    this.setConfiguring(ctx, false);
    if (ctx.memory.phase !== 'ended') return;
    // A Match without its Round has no result to show.
    ctx.game.state.round = null;
    ctx.room.broadcast('resultClosed', null);
  }

  private setConfiguring(ctx: Ctx, configuring: boolean) {
    ctx.game.state.configuring = configuring;
    ctx.room.broadcast('configuring', configuring);
  }

  /** The Player a User is in this Match, or -1: it watches, or it took the name of a Player that left. */
  private playerOf(ctx: Ctx, user: MatchUser): number {
    const player = ctx.game.state.players.indexOf(user.name);
    return ctx.memory.gone.has(player) ? -1 : player;
  }

  private mayPause(ctx: Ctx, user: MatchUser) {
    if (this.playerOf(ctx, user) === -1 && user.name !== ctx.room.admin) throw ctx.reject('notAPlayer');
  }

  private startRound(ctx: Ctx) {
    const { memory } = ctx;
    const round = memory.match!.startRound([...memory.gone]);
    memory.phase = 'countdown';
    memory.inputs = round.cats.map(() => []);
    memory.held = round.cats.map(() => STOP);
    memory.applied = round.cats.map(() => 0);
    this.writeState(ctx);
    ctx.room.broadcast('roundStarted', ctx.game.state);
    ctx.timers.set('countdown', pacing.countdown, () => {
      memory.phase = 'playing';
    });
  }

  /** Keeps the state current, so a User that joins or comes back gets the Match as it is. */
  private writeState(ctx: Ctx) {
    const match = ctx.memory.match!;
    const state: Omit<MatchState, 'players' | 'configuring'> = {
      gone: [...ctx.memory.gone],
      wins: [...match.wins],
      bombsPlaced: [...match.bombsPlaced],
      cratesDestroyed: [...match.cratesDestroyed],
      powerupsCollected: [...match.powerupsCollected],
      roundNumber: match.roundNumber,
      round: snapshotOf(match.currentRound),
    };
    Object.assign(ctx.game.state, state);
  }
}

function snapshotOf(round: Round): RoundSnapshot {
  const { board } = round;
  return {
    timeLeft: round.timeLeft,
    rows: Array.from({ length: board.size.y }, (_, y) =>
      board.tiles
        .slice(y * board.size.x, (y + 1) * board.size.x)
        .map((tile) => SYMBOLS[tile])
        .join(''),
    ),
    bombs: round.bombs.map((bomb) => ({
      ...bomb.tile,
      owner: bomb.owner,
      range: bomb.range,
      fuseLeft: bomb.fuseLeft,
      sx: bomb.slide.x,
      sy: bomb.slide.y,
      progress: bomb.slideProgress,
    })),
    powerups: [...board.powerups].map(([key, id]) => ({ ...tileOfKey(key), id })),
    cats: round.cats.map((cat) => ({
      x: cat.position.x,
      y: cat.position.y,
      fx: cat.facing.x,
      fy: cat.facing.y,
      alive: cat.alive,
      speed: cat.speed,
      bombCapacity: cat.bombCapacity,
      bombRange: cat.bombRange,
      activeBombs: cat.activeBombs,
      bombsPlaced: cat.bombsPlaced,
      cratesDestroyed: cat.cratesDestroyed,
      collected: [...cat.collected],
      pawSwipe: cat.pawSwipe,
      nineLives: cat.nineLives,
      invulnerableLeft: cat.invulnerableLeft,
      curse: cat.curse && { ...cat.curse },
      arrival: cat.portalArrival && { ...cat.portalArrival },
    })),
    finished: round.finished,
  };
}
