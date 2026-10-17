import { expect, test } from 'vitest';
import { Board, type Bomb, type Cat } from './board';
import { mapFromRows, tileKey, type Vec } from './map';
import { move } from './movement';
import { expectPosition, LEFT, makeRound, RIGHT, STEP } from './testing';

/** Two corridors that only the Portals of colour 1 join. */
const TWO_CORRIDORS = ['########', '#S.1...#', '########', '#...1.S#', '########'];

function walker(position: Vec): [Cat, Board] {
  const cat = { position, facing: { x: 0, y: 1 }, portalArrival: null } as Cat;
  return [cat, new Board(mapFromRows(TWO_CORRIDORS))];
}

test('a Cat reaching the centre of a Portal comes out of the other', () => {
  const [cat, board] = walker({ x: 2, y: 1 });
  move(cat, board, RIGHT, 0.8, 0.7);
  expectPosition(cat, { x: 2.8, y: 1 }); // short of the centre, it has not gone through
  move(cat, board, RIGHT, 0.7, 0.7);
  expectPosition(cat, { x: 4.5, y: 3 }); // on from the other Portal, the same way, by what was left of its step
});

test('a Cat is not sent back until it has left the Portal it came out of', () => {
  const [cat, board] = walker({ x: 2, y: 1 });
  move(cat, board, RIGHT, 1, 0.7);
  expectPosition(cat, { x: 4, y: 3 });
  move(cat, board, RIGHT, 0.3, 0.7);
  move(cat, board, LEFT, 0.3, 0.7);
  expectPosition(cat, { x: 4, y: 3 }); // back on the centre without leaving the Tile: it stays
  move(cat, board, RIGHT, 0.6, 0.7);
  move(cat, board, LEFT, 0.6, 0.7);
  expectPosition(cat, { x: 3, y: 1 }); // having left the Tile, it goes back through
});

test('a Bomb on the other Portal lets a Cat walk over this one', () => {
  const [cat, board] = walker({ x: 2, y: 1 });
  board.bombs.set(tileKey({ x: 4, y: 3 }), {} as Bomb);
  move(cat, board, RIGHT, 1.5, 0.7);
  expectPosition(cat, { x: 3.5, y: 1 }); // over the Portal as over Floor
});

test('a pushed Bomb goes through a Portal and slides on', () => {
  const round = makeRound(TWO_CORRIDORS);
  round.placeBomb(0);
  round.advance(STEP);
  round.bombs[0].slide = RIGHT;
  round.advance(1);
  expect(round.named('bombMoved').map(({ from, to }) => [from, to])).toEqual([
    [{ x: 1, y: 1 }, { x: 2, y: 1 }],
    [{ x: 2, y: 1 }, { x: 3, y: 1 }],
    [{ x: 3, y: 1 }, { x: 4, y: 3 }],
    [{ x: 4, y: 3 }, { x: 5, y: 3 }],
  ]);
  expect(round.bombs[0].tile).toEqual({ x: 5, y: 3 }); // stopped beside the other Cat
});

test('a pushed Bomb stops on a Portal whose other one is taken', () => {
  const round = makeRound(TWO_CORRIDORS);
  round.board.bombs.set(tileKey({ x: 4, y: 3 }), {} as Bomb);
  round.placeBomb(0);
  round.advance(STEP);
  round.bombs[0].slide = RIGHT;
  round.advance(1);
  expect(round.bombs[0].tile).toEqual({ x: 3, y: 1 }); // stopped on the Portal it reached
  expect(round.bombs[0].slide).toEqual({ x: 0, y: 0 });
});
