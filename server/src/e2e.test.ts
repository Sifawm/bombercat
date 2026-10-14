import 'reflect-metadata';
import type { INestApplication } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter } from '@nestjs/platform-fastify';
import { WsAdapter } from '@nestjs/platform-ws';
import { bombercat, bridgeProbe, type Games, type Profile, TICK_RATE } from '@bombercat/shared';
import { createPorter, defineGame, type Porter } from '@porterkit/client';
import { afterEach, beforeEach, expect, test } from 'vitest';
import { AppModule } from './app.module';

let app: INestApplication;
let port: number;
const clients: Porter<Games, Profile>[] = [];

beforeEach(async () => {
  app = await NestFactory.create(AppModule, new FastifyAdapter(), { logger: false });
  app.useWebSocketAdapter(new WsAdapter(app));
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
      bombercat: defineGame<Games, 'bombercat'>(bombercat, {}),
      bridgeProbe: defineGame<Games, 'bridgeProbe'>(bridgeProbe, {}),
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

test('a Room takes four Users, each with a Cat, and the Admin runs it', async () => {
  const [ana, bea] = [client(), client()];
  const roomId = await createRoom(ana);

  for (const profile of [null, { cat: 5 }, { cat: 1.5 }, { cat: '1' }]) {
    expect(await bea.login({ name: 'Bea', profile: profile as Profile, roomId })).toEqual({
      ok: false,
      reason: 'invalidProfile',
    });
  }
  // Two Users may bring the same Cat.
  expect(await bea.login({ name: 'Bea', profile: { cat: 0 }, roomId })).toMatchObject({ ok: true });
  await until(bea, () => bea.connection.status === 'connected');
  expect(bea.room!.users.map((user) => user.profile)).toEqual([{ cat: 0 }, { cat: 0 }]);

  for (const name of ['Cleo', 'Dani']) {
    expect(await client().login({ name, profile: { cat: 2 }, roomId })).toMatchObject({ ok: true });
  }
  expect(await client().login({ name: 'Eva', profile: { cat: 3 }, roomId })).toEqual({ ok: false, reason: 'roomFull' });

  ana.send('porter:lockRoom', { locked: true });
  await until(bea, () => bea.room!.locked);
  ana.send('porter:kickUser', { name: 'Bea' });
  await until(bea, () => bea.connection.status === 'closed');
  expect(bea.connection).toEqual({ status: 'closed', reason: 'kicked' });
});

test('the bridge probe sends a snapshot on every Tick', async () => {
  const ana = client();
  await createRoom(ana);
  ana.send('porter:changeGame', { game: 'bridgeProbe' });
  await until(ana, () => ana.game().name === 'bridgeProbe');

  const ticks: number[] = [];
  ana.on('moved', (snapshot) => ticks.push(snapshot.tick));
  ana.send('porter:startMatch');
  await new Promise((resolve) => setTimeout(resolve, 500));
  ana.send('porter:endMatch');
  await until(ana, () => ana.game().match.status === 'ended');

  expect(ticks).toEqual(ticks.map((_, index) => index + 1));
  expect(ticks.length).toBeGreaterThan(TICK_RATE / 2 - 10);
  expect(ticks.length).toBeLessThanOrEqual(TICK_RATE / 2 + 1);
});
