import { expect, test } from 'vitest';
import { DRAW } from './round';
import { config, expectPosition, LEFT, makeRound, RIGHT } from './testing';

const FACE_TO_FACE = ['####', '#SS#', '####'];
const CORRIDOR = ['#########', '#S.....S#', '#########'];

test('the last Cat alive wins the Round', () => {
  const round = makeRound(CORRIDOR);
  round.placeBomb(0);
  round.advance(3.1);
  expect(round.named('roundEnded')).toEqual([]); // not decided while the Explosion is still lethal
  round.advance(0.5);
  expect(round.named('roundEnded')).toEqual([{ type: 'roundEnded', winner: 1 }]);
  expect(round.finished).toBe(true);
});

test('both Cats dying in the same Explosion is a Draw', () => {
  const round = makeRound(FACE_TO_FACE);
  round.placeBomb(0);
  round.advance(3.1);
  expect(round.named('catEliminated')).toHaveLength(2);
  expect(round.named('roundEnded')).toEqual([{ type: 'roundEnded', winner: DRAW }]);
});

test('walking into the Explosion that killed the other Cat is a Draw', () => {
  const round = makeRound(['#######', '#S..S.#', '#######']);
  round.placeBomb(0);
  round.advance(3.1); // Player 0 died; Player 1 at (4, 1) is one Tile outside Range
  round.setMove(1, LEFT);
  round.advance(0.5);
  expect(round.named('catEliminated')).toHaveLength(2);
  expect(round.named('roundEnded')).toEqual([{ type: 'roundEnded', winner: DRAW }]);
});

test('running out of time is a Draw', () => {
  const round = makeRound(CORRIDOR, config({ roundTime: 1 }));
  round.advance(0.9);
  expect(round.named('roundEnded')).toEqual([]);
  round.advance(0.2);
  expect(round.named('roundEnded')).toEqual([{ type: 'roundEnded', winner: DRAW }]);
});

test('a finished Round ignores further steps', () => {
  const round = makeRound(CORRIDOR);
  round.placeBomb(0);
  round.advance(3.6);
  round.setMove(1, LEFT);
  round.advance(1);
  expectPosition(round.cats[1], { x: 7, y: 1 }); // the winner no longer moves
  expect(round.named('roundEnded')).toHaveLength(1);
});

test('the same commands produce the same Round', () => {
  const play = () => {
    const round = makeRound(CORRIDOR);
    round.setMove(0, RIGHT);
    round.advance(0.3);
    round.placeBomb(0);
    round.setMove(1, LEFT);
    round.advance(0.7);
    round.setMove(0, LEFT);
    round.advance(3);
    return [round.events, round.cats, round.timeLeft];
  };
  expect(play()).toEqual(play());
});

test('more than two Cats: the Round goes on until one is left', () => {
  const round = makeRound(['#########', '#S..S..S#', '#########']);
  round.placeBomb(0);
  round.advance(3.6);
  expect(round.named('catEliminated')).toEqual([{ type: 'catEliminated', player: 0 }]);
  expect(round.finished).toBe(false); // two Cats are still alive
  round.placeBomb(1);
  round.advance(3.6);
  expect(round.named('roundEnded')).toEqual([{ type: 'roundEnded', winner: 2 }]);
});

test('more than two Cats: the last ones dying together is a Draw', () => {
  const round = makeRound(['#######', '#SS..S#', '#######']);
  round.placeBomb(0); // reaches Players 0 and 1
  round.setMove(2, LEFT);
  round.advance(3.1); // Player 2 has walked up to the Bomb, into the same Explosion
  expect(round.named('catEliminated')).toHaveLength(3);
  expect(round.named('roundEnded')).toEqual([{ type: 'roundEnded', winner: DRAW }]);
});

test('four Cats: the last one walking into the Explosion that killed the third is a Draw', () => {
  const round = makeRound(['############', '#S..S..S..S#', '############']);
  for (const player of [0, 1]) {
    round.placeBomb(player); // each dies alone on its own Bomb
    round.advance(3.6);
    expect(round.finished).toBe(false);
  }
  expect(round.named('catEliminated')).toHaveLength(2);
  round.placeBomb(2);
  round.advance(3.1); // Player 2 died; Player 3 on (10, 1) is one Tile outside Range
  expect(round.finished).toBe(false); // one Cat left, but the Explosion is still lethal
  round.setMove(3, LEFT);
  round.advance(0.5);
  expect(round.named('catEliminated')).toHaveLength(4);
  expect(round.named('roundEnded')).toEqual([{ type: 'roundEnded', winner: DRAW }]);
});
