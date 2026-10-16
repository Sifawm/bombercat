/**
 * The page's copy of the game's Splash (game/presentation/splash.gd): it fills the first part of
 * the bar while the game downloads, and goes once the game's own Splash is on screen.
 */

/** The share of the bar the download fills; the game fills the rest as it loads. */
const DOWNLOAD_SHARE = 0.8;
const FRAME = { width: 1920, height: 1080 };
/** The clouds of the design, in the frame; each drifts right at a twelfth of its width a second. */
const CLOUDS = [
  [120, 120, 352, 132],
  [1500, 80, 288, 108],
  [1640, 560, 224, 84],
  [40, 640, 192, 72],
  [760, 40, 160, 60],
];

const splash = document.getElementById('splash')!;
const stage = document.getElementById('splash-stage')!;
const clouds = [...stage.querySelectorAll<HTMLElement>('.cloud')];
const fill = splash.querySelector<HTMLElement>('.fill')!;
const dots = [...splash.querySelectorAll<HTMLElement>('.label span')];

/** The view in the game's units: the frame, grown on one side to the window's shape. */
let view = { ...FRAME };

function fit(): void {
  const scale = Math.min(innerWidth / FRAME.width, innerHeight / FRAME.height);
  view = { width: innerWidth / scale, height: innerHeight / scale };
  stage.style.width = `${view.width}px`;
  stage.style.height = `${view.height}px`;
  stage.style.transform = `scale(${scale})`;
}

let last = performance.now();
function animate(now: number): void {
  const delta = (now - last) / 1000;
  last = now;
  clouds.forEach((cloud, i) => {
    const [, y, width, height] = CLOUDS[i];
    cloudX[i] += (width / 12) * delta;
    if (cloudX[i] > view.width) cloudX[i] = -width;
    cloud.style.cssText = `left:${cloudX[i]}px;top:${(view.height - FRAME.height) / 2 + y}px;width:${width}px;height:${height}px`;
  });
  const shown = 1 + (Math.floor((now / 1000) * 3) % 3);
  dots.forEach((dot, i) => (dot.style.visibility = i < shown ? 'visible' : 'hidden'));
  if (splash.isConnected) requestAnimationFrame(animate);
}

fit();
// From where they stand in the design, whatever the window.
const cloudX = CLOUDS.map(([x]) => (view.width - FRAME.width) / 2 + x);
addEventListener('resize', fit);
requestAnimationFrame(animate);

/** For Godot's `onProgress`: how much of the game has downloaded. */
export function showDownload(current: number, total: number): void {
  // A total of 0 is unknown: the bar waits, and the loops still show life.
  if (total > 0) fill.style.width = `${32 + 592 * DOWNLOAD_SHARE * Math.min(1, current / total)}px`;
}

// Called by the game's Splash once it is on screen.
Object.assign(window, {
  hideSplash(): void {
    splash.classList.add('gone');
    splash.addEventListener('transitionend', () => splash.remove(), { once: true });
  },
});
