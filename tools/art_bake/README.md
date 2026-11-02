# art_bake: render 3D models to 2D sprites (dev tool, not shipped)

Renders glTF/GLB models from a fixed isometric camera (yaw 45, pitch 35.264, orthographic, light from the top-left) to transparent PNGs, using three.js in headless Chromium (Playwright). Used to turn the CC0 Kenney Conveyor Kit (`art_source/kenney_conveyor_kit/`) into game sprites. Nothing here is part of the game build.

## Run
```
cd tools/art_bake
npm init -y >/dev/null && npm install three@0.170.0     # fetched at run time, NOT committed (node_modules is git-ignored)
ln -sfn ../../art_source/kenney_conveyor_kit/glb models
python3 -m http.server 8766 &                           # serves bake.html, models/, node_modules/
node bake.js <outDir> <sizePx> <yaw> <pitch> <modelName>...
# e.g. node bake.js /tmp/out 384 45 35.264 conveyor-long cover-hopper robot-arm-a box-large
```
`require('playwright')` must resolve (preinstalled in the cloud sessions; locally `npm i -D playwright`). Model names are the GLB file names without `.glb` (61 pieces: conveyor*, cover*, box*, robot-arm-a/b, scanner-*, structure-*, door*, floor*, top*, arrow*).

## Notes
- Output is fitted to the model's bounding box with a small margin; use the same `sizePx` and a shared scale factor if sprites must keep their relative sizes (see ART-1 issue).
- Kit licence: CC0 (see `art_source/kenney_conveyor_kit/License.txt`). Credit is optional; log it in `docs/ART_LOG.md`.
