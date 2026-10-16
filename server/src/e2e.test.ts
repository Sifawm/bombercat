import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join as joinPath } from 'node:path';
import type { INestApplication } from '@nestjs/common';
import { bombercat, type Games, type Moved, type Profile, type RoundEvent } from '@bombercat/shared';
import { createPorter, defineGame, type Porter } from '@porterkit/client';
import { afterEach, beforeEach, expect, test } from 'vitest';
import { createApp } from './app';
import { pacing } from './bombercat.manager';

// No test waits for a countdown.
Object.assign(pacing, { countdown: 40, roundOver: 40 });

// A page built for the occasion, where the server looks for the real one.
const WEB_ROOT = mkdtempSync(joinPath(tmpdir(), 'bombercat-web-'));
writeFileSync(joinPath(WEB_ROOT, 'index.html'), '<title>BomberCat</title>');

let app: INestApplication;
let port: number;
const clients: Porter<Games, Profile>[] = [];

beforeEach(async () => {
  app = await createApp(WEB_ROOT, false);
  await app.listen(0, '127.0.0.1');
  port = app.getHttpServer().address().port;
});
afterEach(async () => {
  for (const client of clients.splice(0)) client.leave();
  await app.close();
});

/** The real client, as the page creates it, with nothing mounted. */
function client() {
  const stored = new Map<string, string>();
  const porter = createPorter<Games, Profile>({
    httpUrl: `http://127.0.0.1:${port}`,
    wsUrl: `ws://127.0.0.1:${port}/porter/ws`,
    storage: {
      getItem: (key) => stored.get(key) ?? null,
      setItem: (key, value) => void stored.set(key, value),
      removeItem: (key) => void stored.delete(key),
    },
    games: {
      bombercat: defineGame<Games, 'bombercat'>(bombercat, {
        roundStarted: (game, state) => ({ ...game, state }),
        scored: (game, state) => ({ ...game, state }),
        synced: (game, state) => ({ ...game, state }),
        configuring: (game, configuring) => ({ ...game, state: { ...game.state, configuring } }),
        resultClosed: (game) => ({ ...game, state: { ...game.state, round: null } }),
      }),
    },
  });
  clients.push(porter);
  return porter;
}

/** Resolves once the client's state satisfies the check. */
function until(porter: Porter<Games, Profile>, check: () => boolean) {
  return new Promise<void>((resolve) => {
    if (check()) return resolve();
    const stop = porter.subscribe(() => {
      if (!check()) return;
      stop();
      resolve();
    });
  });
}

async function createRoom(admin: Porter<Games, Profile>) {
  const created = await admin.login({ name: 'Ana', profile: { cat: 0 } });
  if (!created.ok) throw new Error(created.reason);
  await until(admin, () => admin.connection.status === 'connected');
  return created.roomId;
}

test('a Room takes five Users, each with a Cat, and the Admin runs it', async () => {
  const [ana, bea] = [client(), client()];
  const roomId = await createRoom(ana);

  // A Profile that is not valid, or whose Cat is brought, is swapped for the first Cat free.
  expect(await bea.login({ name: 'Bea', profile: { cat: 0 }, roomId })).toMatchObject({ ok: true });
  await until(bea, () => bea.connection.status === 'connected');
  expect(await client().login({ name: 'Cleo', profile: { cat: '1' } as never, roomId })).toMatchObject({ ok: true });
  await until(bea, () => bea.room!.users.length === 3);
  expect(bea.room!.users.map((user) => user.profile)).toEqual([{ cat: 0 }, { cat: 1 }, { cat: 2 }]);

  expect(await client().login({ name: 'Dani', profile: { cat: 2 }, roomId })).toMatchObject({ ok: true });
  expect(await client().login({ name: 'Eva', profile: { cat: 3 }, roomId })).toMatchObject({ ok: true });
  // A sixth finds no Cat free before it finds the Room full.
  expect(await client().login({ name: 'Fran', profile: { cat: 4 }, roomId })).toMatchObject({ ok: false });

  ana.send('porter:lockRoom', { locked: true });
  await until(bea, () => bea.room!.locked);
  ana.send('porter:kickUser', { name: 'Bea' });
  await until(bea, () => bea.connection.status === 'closed');
  expect(bea.connection).toEqual({ status: 'closed', reason: 'kicked' });
});

test('a User changes its Cat for one nobody brings', async () => {
  const { ana, rest } = await room('Bea');
  const [bea] = rest;
  const rejected = new Promise((resolve) => bea.on('porter:messageRejected', resolve));
  bea.send('porter:updateProfile', { profile: { cat: 0 } });
  expect(await rejected).toEqual({ rejected: 'porter:updateProfile', reason: 'invalidProfile' });

  bea.send('porter:updateProfile', { profile: { cat: 4 } });
  await until(ana, () => ana.room!.users[1].profile.cat === 4);
  // Ana takes the Cat Bea left.
  ana.send('porter:updateProfile', { profile: { cat: 1 } });
  await until(bea, () => bea.room!.users[0].profile.cat === 1);
});

test('the Admin takes everyone to configure the Match and back, and a Match brings them back', async () => {
  const alone = await room();
  const refused = new Promise((resolve) => alone.ana.on('porter:messageRejected', resolve));
  alone.ana.send('configure');
  expect(await refused).toEqual({ rejected: 'configure', reason: { code: 'game', reason: 'tooFewUsers' } });

  const { roomId, ana, rest } = await room('Bea');
  const [bea] = rest;
  const rejected = new Promise((resolve) => bea.on('porter:messageRejected', resolve));
  bea.send('configure');
  expect(await rejected).toEqual({ rejected: 'configure', reason: 'notAdmin' });

  ana.send('configure');
  await until(bea, () => state(bea).configuring);
  // Whoever comes in meanwhile is in it too.
  const cleo = await join('Cleo', roomId);
  expect(state(cleo).configuring).toBe(true);
  ana.send('backToRoom');
  await until(cleo, () => !state(cleo).configuring);

  ana.send('configure');
  await until(bea, () => state(bea).configuring);
  ana.send('porter:startMatch');
  await until(bea, () => status(bea) === 'running');
  expect(state(bea).configuring).toBe(false);
});

/** Ana, the Admin, and whoever else is named, in a Room together. */
async function room(...others: string[]) {
  const ana = client();
  const roomId = await createRoom(ana);
  const rest = [];
  for (const name of others) rest.push(await join(name, roomId));
  await until(ana, () => ana.room!.users.length === 1 + others.length);
  return { roomId, ana, rest };
}

async function join(name: string, roomId: string) {
  const user = client();
  expect(await user.login({ name, profile: { cat: 1 }, roomId })).toMatchObject({ ok: true });
  await until(user, () => user.connection.status === 'connected');
  return user;
}

const state = (user: Porter<Games, Profile>) => user.game('bombercat').state;
const status = (user: Porter<Games, Profile>) => user.game().match.status;

/** Everything that happens in the Match from now on, as this User hears it. */
function heard(user: Porter<Games, Profile>) {
  const events: RoundEvent[] = [];
  user.on('happened', (happened) => events.push(...happened));
  return events;
}

test('a Match: Inputs move a Cat a Tick each, its Bomb kills it and the other Player wins', async () => {
  const { ana, rest } = await room('Bea');
  const [bea] = rest;
  ana.send('porter:updateSettings', { map: 'backyard', roundsToWin: 1, roundTime: 120 });
  ana.send('porter:startMatch');
  await until(bea, () => state(bea).round !== null);
  expect(state(bea).players).toEqual(['Ana', 'Bea']);
  expect(state(bea).roundNumber).toBe(1);
  expect(state(bea).round!.cats.map(({ x, y }) => ({ x, y }))).toEqual([
    { x: 1, y: 1 },
    { x: 11, y: 9 },
  ]);
  expect(state(bea).round!.rows[1]).toBe('#...xxxxx...#');

  // One Input for each Tick heard, as a client sends them: 30 to the right, then a Bomb.
  const events = heard(bea);
  let last: Moved | undefined;
  let seq = 0;
  ana.on('moved', (moved) => {
    last = moved;
    if (seq < 31) ana.send('input', { seq: ++seq, x: seq <= 30 ? 1 : 0, y: 0, bomb: seq === 31 });
  });
  await until(ana, () => status(ana) === 'ended');

  expect(last!.cats[0]).toMatchObject({ x: expect.closeTo(3, 3), y: 1, fx: 1, fy: 0, seq: 31 }); // speed 4 for half a second
  expect(events).toContainEqual({ type: 'bombPlaced', tile: { x: 3, y: 1 }, owner: 0, range: 2 });
  expect(events).toContainEqual({ type: 'catEliminated', player: 0 });
  expect(events.at(-1)).toEqual({ type: 'roundEnded', winner: 1 });
  expect(ana.game('bombercat').match).toEqual({ status: 'ended', reason: { by: 'game', reason: { winner: 1 } } });
  expect(state(bea)).toMatchObject({ wins: [0, 1], bombsPlaced: [1, 0] }); // those who played know the score
  // The state of an ended Match is what a User that joins now gets.
  const cleo = await join('Cleo', ana.room!.id);
  expect(state(cleo)).toMatchObject({ wins: [0, 1], bombsPlaced: [1, 0], players: ['Ana', 'Bea'] });
  expect(state(cleo).round!.finished).toBe(true);

  // Only the Admin takes everyone from the result back to choosing Cats.
  const rejected = new Promise((resolve) => bea.on('porter:messageRejected', resolve));
  bea.send('backToRoom');
  expect(await rejected).toEqual({ rejected: 'backToRoom', reason: 'notAdmin' });
  ana.send('backToRoom');
  await until(cleo, () => state(cleo).round === null);
  await until(bea, () => state(bea).round === null);
}, 15_000);

test('any Player pauses the Match and sets it going again; a User that only watches does not', async () => {
  const { roomId, ana, rest } = await room('Bea');
  const [bea] = rest;
  ana.send('porter:startMatch');
  await until(bea, () => status(bea) === 'running');
  bea.send('pause');
  bea.send('pause'); // as when two Players ask at once: it stays paused
  await until(ana, () => status(ana) === 'paused');
  bea.send('resume');
  await until(ana, () => status(ana) === 'running');

  const cleo = await join('Cleo', roomId); // it finds the Match as it is, and its Cats
  expect(state(cleo).round!.cats).toHaveLength(2);
  const rejected = new Promise((resolve) => cleo.on('porter:messageRejected', resolve));
  cleo.send('pause');
  expect(await rejected).toEqual({ rejected: 'pause', reason: { code: 'game', reason: 'notAPlayer' } });
  ana.send('pause'); // the Admin plays too
  await until(cleo, () => status(cleo) === 'paused');
});

test('a Player that leaves loses its Cat, and a Match left with one Player has no winner', async () => {
  const { ana, rest } = await room('Bea', 'Cleo');
  const events = heard(ana);
  ana.send('porter:startMatch');
  await new Promise((resolve) => ana.on('moved', resolve)); // the Round is being played
  ana.send('porter:kickUser', { name: 'Cleo' });
  await until(rest[1], () => rest[1].connection.status === 'closed');
  await new Promise((resolve) => setTimeout(resolve, 100));
  expect(events).toEqual([{ type: 'catEliminated', player: 2 }]);
  expect(status(ana)).toBe('running');

  await join('Dani', ana.room!.id); // it watches, so the Room keeps its minimum of Users
  ana.send('porter:kickUser', { name: 'Bea' });
  await until(ana, () => status(ana) === 'ended');
  expect(ana.game('bombercat').match).toEqual({ status: 'ended', reason: { by: 'game', reason: { winner: null } } });
});

test('the Admin changes the settings within their limits', async () => {
  const { ana } = await room();
  const rejected = new Promise((resolve) => ana.on('porter:messageRejected', resolve));
  ana.send('porter:updateSettings', { map: 'attic', roundsToWin: 2, roundTime: 120 } as never);
  expect(await rejected).toMatchObject({ rejected: 'porter:updateSettings', reason: { code: 'game', reason: 'invalidSettings' } });
  // Whatever else comes with them is left out, a `set` that would replace the settings' own included.
  ana.send('porter:updateSettings', { map: 'backyard', roundsToWin: 3, roundTime: 90, set: 1 } as never);
  await until(ana, () => ana.game('bombercat').settings.roundsToWin === 3);
  expect(ana.game('bombercat').settings).toEqual({ map: 'backyard', roundsToWin: 3, roundTime: 90 });
  ana.send('porter:updateSettings', { map: 'backyard', roundsToWin: 4, roundTime: 90 });
  await until(ana, () => ana.game('bombercat').settings.roundsToWin === 4);
});

test('the server gives the page and Porter from the same origin', async () => {
  const page = await fetch(`http://127.0.0.1:${port}/`);
  expect(page.headers.get('content-type')).toContain('text/html');
  expect(await page.text()).toBe('<title>BomberCat</title>');
  expect((await fetch(`http://127.0.0.1:${port}/../../etc/passwd`)).status).toBe(404);
  expect(await client().roomExists('nosuchroom')).toBe(false);
});

test('a client that starts drawing a Round late asks for it as it is, and a name left behind plays no more', async () => {
  const { ana, rest } = await room('Bea', 'Cleo');
  ana.send('porter:startMatch');
  await new Promise((resolve) => ana.on('moved', resolve));
  ana.send('porter:kickUser', { name: 'Cleo' });
  await until(rest[1], () => rest[1].connection.status === 'closed');
  await new Promise((resolve) => ana.on('moved', resolve)); // the Tick in which Cleo's Cat goes

  // Someone else comes in as Cleo: it watches, and what it asks of Cleo's Cat goes nowhere.
  const other = await join('Cleo', ana.room!.id);
  const synced = new Promise((resolve) => other.on('synced', resolve));
  other.send('sync');
  expect(await synced).toMatchObject({ players: ['Ana', 'Bea', 'Cleo'], gone: [2] });
  expect(state(other).round!.cats[2].alive).toBe(false);
  const rejected = new Promise((resolve) => other.on('porter:messageRejected', resolve));
  other.send('pause');
  expect(await rejected).toMatchObject({ rejected: 'pause', reason: { reason: 'notAPlayer' } });
});

test('a Match does not start with one User connected, whoever else is on its way back', async () => {
  const ana = client();
  const roomId = await createRoom(ana);
  // Bea, on a connection of its own that then drops: it stays in the Room, reconnecting.
  const login = await fetch(`http://127.0.0.1:${port}/porter/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ name: 'Bea', profile: { cat: 1 }, roomId }),
  });
  const { token } = (await login.json()) as { token: string };
  const socket = new WebSocket(`ws://127.0.0.1:${port}/porter/ws?token=${token}`);
  await until(ana, () => ana.room!.users.length === 2);
  socket.close();
  await until(ana, () => ana.room!.users[1].status === 'reconnecting');

  const rejected = new Promise((resolve) => ana.on('porter:messageRejected', resolve));
  ana.send('porter:startMatch');
  expect(await rejected).toEqual({ rejected: 'porter:startMatch', reason: { code: 'game', reason: 'tooFewUsers' } });
});
