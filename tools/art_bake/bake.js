// Usage: node bake.js bake_all [outDir]        regenerate the whole set (default outDir: ../../game/assets/sprites)
//        node bake.js bake <outDir> <name>...  bake some sprites from recipes.json (+ generated bots)
// Needs: npm install three@0.170.0, models symlink, and `python3 -m http.server 8766` in this folder (see README).
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const R = JSON.parse(fs.readFileSync(path.join(__dirname, 'recipes.json'), 'utf8'));
const cfg = R.camera; // {yaw,pitch,ppu,...}
const sprites = { ...R.sprites };
// bots + panic variants are generated from game/data/bots.json (same colours as the game)
const bj = JSON.parse(fs.readFileSync(path.join(__dirname, '../../game/data/bots.json'), 'utf8'));
const bots = [...bj.bots, ...(bj.rookies || [])];
for (const b of bots) for (const panic of [false, true]) {
  sprites['bot_' + b.name.toLowerCase() + (panic ? '_panic' : '')] = { canvas: R.bot_canvas, parts: [{ proc: 'bot', color: b.color, panic, rot_y_deg: 0, scale: R.bot_scale }] };
}
(async () => {
  const [,, cmd, a1, ...rest] = process.argv;
  const all = cmd === 'bake_all';
  const out = all ? (a1 || path.join(__dirname, '../../game/assets/sprites')) : a1;
  const names = all ? Object.keys(sprites) : rest;
  fs.mkdirSync(out, { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist'] });
  const p = await b.newPage();
  p.on('pageerror', e => console.log('pageerror', e.message));
  await p.goto('http://localhost:8766/bake.html');
  await p.waitForFunction(() => document.title === 'ready', null, { timeout: 20000 });
  for (const n of names) {
    const s = sprites[n]; if (!s) { console.log('unknown', n); continue; }
    const [W, H, ax, ay] = s.canvas;
    const url = await p.evaluate(([c, r]) => window.bake(c, r), [{ W, H, ax, ay, ppu: cfg.ppu, yaw: cfg.yaw, pitch: cfg.pitch }, s]);
    fs.writeFileSync(path.join(out, n + '.png'), Buffer.from(url.split(',')[1], 'base64'));
    console.log('baked', n, W + 'x' + H);
  }
  await b.close();
})();
