const { chromium } = require('playwright');
(async () => {
  const [,, outDir, size, yaw, pitch, ...names] = process.argv;
  const b = await chromium.launch({ args: ['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist','--allow-file-access-from-files'] });
  const p = await b.newPage({ viewport: { width: +size, height: +size } });
  for (const n of names) {
    await p.goto(`http://localhost:8766/bake.html?m=${n}&s=${size}&yaw=${yaw}&pitch=${pitch}`);
    await p.waitForFunction(() => document.title !== '', null, { timeout: 20000 }).catch(()=>{});
    const t = await p.title();
    if (t !== 'done') { console.log(n, t); continue; }
    await p.locator('#c').screenshot({ path: `${outDir}/${n}.png`, omitBackground: true });
    console.log('baked', n);
  }
  await b.close();
})();
