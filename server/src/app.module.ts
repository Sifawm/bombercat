import { Module } from '@nestjs/common';
import { PorterModule } from '@porterkit/nestjs';
import { freeProfile, type Games, isFreeProfile } from '@bombercat/shared';
import { BombercatManager } from './bombercat.manager';

@Module({ providers: [BombercatManager] })
export class GamesModule {}

@Module({
  imports: [
    PorterModule.forRoot<Games>({
      initialGame: 'bombercat',
      // ponytail: the Spawn Points of `backyard`, the only Map. Raise it with the first larger Map.
      capacity: 4,
      gracePeriod: 15_000,
      validateProfile: isFreeProfile,
      fallbackProfile: freeProfile,
    }),
    GamesModule,
  ],
})
export class AppModule {}
