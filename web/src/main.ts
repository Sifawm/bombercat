import { bombercat, bridgeProbe, type Games, type Profile } from '@bombercat/shared';
import { createPorter, defineGame } from '@porterkit/client';
import { exposeToGodot } from '@porterkit/godot';

/** Godot's loader, from the classic script of `index.html`. */
declare const Engine: new (config: object) => { startGame(): Promise<void> };

const porter = createPorter<Games, Profile>({
  httpUrl: location.origin,
  wsUrl: `${location.origin.replace(/^http/, 'ws')}/porter/ws`,
  games: {
    bombercat: defineGame<Games, 'bombercat'>(bombercat, {}),
    // `moved` has no Applier: it comes on every Tick and goes straight to whoever draws.
    bridgeProbe: defineGame<Games, 'bridgeProbe'>(bridgeProbe, {}),
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
