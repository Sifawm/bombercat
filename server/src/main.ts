import { join } from 'node:path';
import { createApp } from './app';

async function bootstrap() {
  const app = await createApp(process.env.WEB_ROOT ?? join(__dirname, '../../web/dist'));
  await app.listen(Number(process.env.PORT ?? 3000), '0.0.0.0');
}

void bootstrap();
