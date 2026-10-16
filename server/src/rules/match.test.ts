import { expect, test } from 'vitest';
import type { GameConfig } from './config';
import { mapFromRows } from './map';
import { Match, type MatchEvent } from './match';
import { advance, config } from './testing';

const CORRIDOR = ['#########', '#S.....S#', '#########'];

const makeMatch = (rows = CORRIDOR, gameConfig: GameConfig = config(), players = 2) =>
  new Match(mapFromRows(rows), gameConfig, players);

/** Plays a Round in which `loser` stands on its own Bomb. Returns what happened. */
function playRoundLostBy(match: Match, loser: number): MatchEvent[] {
  match.startRound().placeBomb(loser);
  return advance(match, 3.6);
}

const winners = (events: MatchEvent[]) => events.flatMap((event) => (event.type === 'matchEnded' ? [event.winner] : []));

test('winning a Round counts for the winner', () => {
  const match = makeMatch();
  expect(winners(playRoundLostBy(match, 0))).toEqual([]);
  expect(match.wins).toEqual([0, 1]);
  expect(match.finished).toBe(false); // one Round does not decide the Match
});

test('the first Cat to win two Rounds wins the Match', () => {
  const match = makeMatch();
  playRoundLostBy(match, 0);
  expect(winners(playRoundLostBy(match, 1))).toEqual([]); // 1-1 is not decided
  expect(winners(playRoundLostBy(match, 0))).toEqual([1]);
  expect(match.wins).toEqual([1, 2]);
  expect(match.winner).toBe(1);
  expect(match.finished).toBe(true);
});

test('a Draw awards no win and is replayed', () => {
  const match = makeMatch(CORRIDOR, config({ roundTime: 1 }));
  match.startRound();
  advance(match, 1.1);
  expect(match.wins).toEqual([0, 0]);
  for (let round = 0; round < 2; round++) {
    match.startRound();
    advance(match, 1.1);
  }
  expect(match.finished).toBe(false); // Draws never end a Match
  expect(match.roundNumber).toBe(3); // a replayed Draw is another Round
});

test('the number of Rounds to win is tunable', () => {
  const match = makeMatch(CORRIDOR, config({ roundsToWin: 1 }));
  expect(winners(playRoundLostBy(match, 1))).toEqual([0]);
});

test('Cats start every Round on the Spawn Points farthest apart', () => {
  const match = makeMatch(['#########', '#S.S...S#', '#########']);
  for (let attempt = 0; attempt < 2; attempt++) {
    const round = match.startRound();
    expect(round.cats.map((cat) => cat.position)).toEqual([
      { x: 1, y: 1 },
      { x: 7, y: 1 },
    ]);
  }
});

test('every Round starts on the restored Map', () => {
  const match = makeMatch(['#########', '#Sx....S#', '#########']);
  playRoundLostBy(match, 0);
  const round = match.startRound();
  expect(round.board.tileAt({ x: 2, y: 1 })).toBe('crate');
  expect(round.bombs).toHaveLength(0);
});

test('the Match adds up what each Player did in every Round', () => {
  const match = makeMatch(['#########', '#Sx....S#', '#########']);
  playRoundLostBy(match, 0);
  playRoundLostBy(match, 0);
  expect(match.bombsPlaced).toEqual([2, 0]);
  expect(match.cratesDestroyed).toEqual([2, 0]);
  expect(match.powerupsCollected).toEqual([0, 0]);
});

test('a Match of four Cats gives each its own Spawn Point', () => {
  const match = makeMatch(['#######', '#S...S#', '#.....#', '#S...S#', '#######'], config(), 4);
  const tiles = match.startRound().cats.map((cat) => `${cat.position.x},${cat.position.y}`);
  expect(new Set(tiles).size).toBe(4);
  expect(match.wins).toEqual([0, 0, 0, 0]);
});

test('a Match takes no more Players than its Map has Spawn Points', () => {
  expect(() => makeMatch(CORRIDOR, config(), 3)).toThrow('Spawn Points');
});
