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
      // Every Cat: no two Users bring the same one. `living_room` has a Spawn Point for each.
      capacity: 5,
      gracePeriod: 15_000,
      validateProfile: isFreeProfile,
      fallbackProfile: freeProfile,
    }),
    GamesModule,
  ],
})
export class AppModule {}
