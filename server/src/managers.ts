import { type GameContext, GameManager, type GameManager as Manager, type OnTick } from '@porterkit/nestjs';
import { bombercat, bridgeProbe, type Games, type ProbeSnapshot } from '@bombercat/shared';

/** The Game has no Match yet, so there is nothing to manage. */
@GameManager(bombercat)
export class BombercatManager implements Manager<GameContext<Games, typeof bombercat>> {
  defaultSettings() {
    return {};
  }

  updateSettings() {}
}

type ProbeCtx = GameContext<Games, typeof bridgeProbe, { tick: number }>;

const CATS = 4;
const BOMBS = 8;

/** What a Tick of a full Round would send: every Cat and every Bomb, with fractional positions. */
export const probeSnapshot = (tick: number): ProbeSnapshot => ({
  tick,
  cats: Array.from({ length: CATS }, (_, cat) => ({ x: 1 + ((tick + cat * 40) % 660) / 60, y: 1 + cat * 3, seq: tick })),
  bombs: Array.from({ length: BOMBS }, (_, bomb) => ({ x: 1 + bomb, y: 5, fuse: 3 - (tick % 180) / 60 })),
});

@GameManager(bridgeProbe)
export class BridgeProbeManager implements Manager<ProbeCtx>, OnTick<ProbeCtx> {
  defaultSettings() {
    return {};
  }

  updateSettings() {}

  createMemory() {
    return { tick: 0 };
  }

  onTick(ctx: ProbeCtx) {
    ctx.room.broadcast('moved', probeSnapshot(++ctx.memory.tick));
  }
}
