# Slice a horizontal sprite sheet (white background) into aligned transparent frames.
# Usage: python3 -I tools/slice_sheet.py <sheet.png> <out_dir>   (needs Pillow + numpy)
from PIL import Image
import numpy as np, sys
from collections import deque
src=sys.argv[1]; out=sys.argv[2]
im=Image.open(src).convert('RGB'); a=np.array(im).astype(int)
d=255-a.min(axis=2)
alpha=np.clip((d-6)*255/22,0,255).astype(np.uint8)
rgba=np.dstack([a.astype(np.uint8),alpha])
mask=alpha>40
H,W=mask.shape
lab=np.zeros((H,W),np.int32); n=0; comps=[]
for y in range(H):
    for x in np.nonzero(mask[y]&(lab[y]==0))[0]:
        if lab[y,x]: continue
        n+=1; q=deque([(y,int(x))]); lab[y,x]=n; pts=[]
        while q:
            cy,cx=q.popleft(); pts.append((cy,cx))
            for dy in (-2,-1,0,1,2):
                for dx in (-2,-1,0,1,2):
                    ny,nx=cy+dy,cx+dx
                    if 0<=ny<H and 0<=nx<W and mask[ny,nx] and not lab[ny,nx]:
                        lab[ny,nx]=n; q.append((ny,nx))
        comps.append((n,len(pts)))
big=[c for c in comps if c[1]>3000]
print(len(comps),big)
boxes=[]
for i,s in big:
    ys,xs=np.nonzero(lab==i); boxes.append((i,xs.min(),xs.max(),ys.min(),ys.max()))
boxes.sort(key=lambda b:b[1]); print(boxes)
# uniform canvas: max size, anchor = bottom-centre of machine body (use box centre x, box bottom)
w=max(b[2]-b[1]+1 for b in boxes); h=max(b[4]-b[3]+1 for b in boxes)
print("max",w,h)
import os; os.makedirs(out,exist_ok=True)
CW,CH=w+16,h+16
for k,(i,x0,x1,y0,y1) in enumerate(boxes):
    m=(lab==i)
    # keep soft edge px next to this component
    from PIL import ImageFilter
    mm=Image.fromarray((m*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    sel=np.array(mm)>0
    r=rgba.copy(); r[~sel,3]=0
    crop=Image.fromarray(r).crop((x0,y0,x1+1,y1+1))
    cv=Image.new('RGBA',(CW,CH),(0,0,0,0))
    # align by bottom edge and horizontal centre of the box
    cv.paste(crop,((CW-crop.width)//2,CH-8-crop.height),crop)
    cv.save(f'{out}/press_{k}.png')
print(CW,CH)
