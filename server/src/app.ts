import 'reflect-metadata';
import { existsSync } from 'node:fs';
import fastifyStatic from '@fastify/static';
import type { INestApplication } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { FastifyAdapter } from '@nestjs/platform-fastify';
import { WsAdapter } from '@nestjs/platform-ws';
import { AppModule } from './app.module';

/**
 * The whole server: Porter and, when `webRoot` holds the built page, the page itself, from the
 * same origin (ADR 0005). Without it only Porter answers, as in development, where Vite serves
 * the page.
 */
export async function createApp(webRoot: string, logger?: false): Promise<INestApplication> {
  const adapter = new FastifyAdapter();
  // The plugin and the adapter each bring their own copy of Fastify's types.
  if (existsSync(webRoot)) await adapter.register(fastifyStatic as never, { root: webRoot });
  const app = await NestFactory.create(AppModule, adapter, { logger });
  app.useWebSocketAdapter(new WsAdapter(app));
  return app;
}
