import { bombercat, type Games, type Profile } from '@bombercat/shared';
import { createPorter, defineGame } from '@porterkit/client';
import { exposeToGodot } from '@porterkit/godot';

/** Godot's loader, from the classic script of `index.html`. */
declare const Engine: new (config: object) => { startGame(): Promise<void> };

const porter = createPorter<Games, Profile>({
  httpUrl: location.origin,
  wsUrl: `${location.origin.replace(/^http/, 'ws')}/porter/ws`,
  games: {
    // Only the start and the end of a Round go through the state, whole. What comes on every Tick,
    // and what happens in a Round, has no Applier: it goes straight to the scene that draws (ADR 0004).
    bombercat: defineGame<Games, 'bombercat'>(bombercat, {
      roundStarted: (game, state) => ({ ...game, state }),
      scored: (game, state) => ({ ...game, state }),
      synced: (game, state) => ({ ...game, state }),
    }),
  },
});

// Before the engine starts: the addon looks for the facade when it loads.
exposeToGodot(porter);

await new Engine({
  executable: '/godot/index',
  canvas: document.getElementById('canvas'),
  canvasResizePolicy: 2,
  focusCanvas: true,
}).startGame();
