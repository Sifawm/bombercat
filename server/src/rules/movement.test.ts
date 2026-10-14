import { expect, test } from 'vitest';
import { config, DOWN, expectPosition, LEFT, makeRound, RIGHT, STOP } from './testing';

const CORRIDOR = ['#######', '#S...S#', '#######'];
const CORNER = ['#####', '#S..#', '#.#.#', '#..S#', '#####'];

test('a Cat walks at its speed', () => {
  const round = makeRound(CORRIDOR);
  round.setMove(0, RIGHT);
  round.advance(0.5);
  expectPosition(round.cats[0], { x: 3, y: 1 }); // speed 4 for half a second
  expect(round.cats[0].facing).toEqual(RIGHT);
});

test('a Cat stops when the command stops', () => {
  const round = makeRound(CORRIDOR);
  round.setMove(0, RIGHT);
  round.advance(0.25);
  round.setMove(0, STOP);
  round.advance(0.5);
  expectPosition(round.cats[0], { x: 2, y: 1 });
});

test('a Wall blocks a Cat', () => {
  const round = makeRound(CORRIDOR);
  round.setMove(0, LEFT);
  round.setMove(1, RIGHT);
  round.advance(0.5);
  expectPosition(round.cats[0], { x: 1, y: 1 });
  expectPosition(round.cats[1], { x: 5, y: 1 });
});

test('a Crate blocks a Cat', () => {
  const round = makeRound(['#######', '#S.x.S#', '#######']);
  round.setMove(0, RIGHT);
  round.advance(1);
  expectPosition(round.cats[0], { x: 2, y: 1 });
});

test('Cats do not block each other', () => {
  const round = makeRound(CORRIDOR);
  round.setMove(0, RIGHT);
  round.advance(2);
  expectPosition(round.cats[0], { x: 5, y: 1 }); // walked onto the other Cat's Tile
});

test('turning late slides back into the corridor', () => {
  const round = makeRound(CORNER);
  round.setMove(0, DOWN);
  round.advance(0.1); // 0.4 Tiles past the corridor of row 1
  round.setMove(0, RIGHT);
  round.advance(0.25); // one Tile of travel: 0.4 back up, 0.6 right
  expectPosition(round.cats[0], { x: 1.6, y: 1 });
});

test('turning early slides on to the far corridor', () => {
  const round = makeRound(CORNER);
  round.setMove(0, DOWN);
  round.advance(0.35); // at y 2.4: row 2 is nearest but (2, 2) is a Wall; row 3 is 0.6 away
  round.setMove(0, RIGHT);
  round.advance(0.25);
  expectPosition(round.cats[0], { x: 1.4, y: 3 });
});

test('no corner assist beyond its reach', () => {
  const round = makeRound(CORNER, config({ cornerAssist: 0.5 }));
  round.setMove(0, DOWN);
  round.advance(0.35);
  round.setMove(0, RIGHT);
  round.advance(0.25);
  expectPosition(round.cats[0], { x: 1, y: 2.4 }); // row 3 is out of reach, so the Cat stays
});

test('the owner leaves its Bomb\'s Tile but cannot return', () => {
  const round = makeRound(CORRIDOR);
  round.placeBomb(0);
  round.setMove(0, RIGHT);
  round.advance(0.5);
  expectPosition(round.cats[0], { x: 3, y: 1 });
  round.setMove(0, LEFT);
  round.advance(1);
  expectPosition(round.cats[0], { x: 2, y: 1 }); // the Bomb's Tile is closed behind it
});

test('a Bomb blocks the other Cat', () => {
  const round = makeRound(['#######', '#S.S..#', '#######']);
  round.placeBomb(0);
  round.setMove(1, LEFT);
  round.advance(1);
  expectPosition(round.cats[1], { x: 2, y: 1 });
});

test('a malformed direction cannot push a Cat through a Wall', () => {
  const round = makeRound(CORRIDOR);
  round.setMove(0, { x: -2, y: 3 });
  round.advance(0.5);
  expectPosition(round.cats[0], { x: 1, y: 1 }); // treated as LEFT, into the Wall
});
