import { Module } from '@nestjs/common';
import { PorterModule } from '@porterkit/nestjs';
import { type Games, isProfile } from '@bombercat/shared';
import { BombercatManager, BridgeProbeManager } from './managers';

@Module({ providers: [BombercatManager, BridgeProbeManager] })
export class GamesModule {}

@Module({
  imports: [
    PorterModule.forRoot<Games>({
      initialGame: 'bombercat',
      // ponytail: the Spawn Points of `backyard`, the only Map. Raise it with the first larger Map.
      capacity: 4,
      gracePeriod: 15_000,
      validateProfile: isProfile,
    }),
    GamesModule,
  ],
})
export class AppModule {}
