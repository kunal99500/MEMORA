from pathlib import Path
import cv2
from PIL import Image

def assess_image(path:str)->dict:
    img=cv2.imread(path)
    if img is None: return {'usable':False,'reason':'unreadable'}
    h,w=img.shape[:2]; gray=cv2.cvtColor(img,cv2.COLOR_BGR2GRAY)
    sharp=float(cv2.Laplacian(gray,cv2.CV_64F).var()); bright=float(gray.mean())
    issues=[]
    if min(w,h)<320: issues.append('low_resolution')
    if sharp<35: issues.append('possible_blur')
    if bright<35: issues.append('underexposed')
    if bright>225: issues.append('overexposed')
    return {'usable':min(w,h)>=160,'width':w,'height':h,'sharpness':round(sharp,2),'brightness':round(bright,2),'issues':issues}

def make_tiles(image_path:str,output_dir:str,tile_size:int=1024,overlap:int=128)->list[dict]:
    out=Path(output_dir);out.mkdir(parents=True,exist_ok=True); im=Image.open(image_path).convert('RGB');w,h=im.size
    step=max(1,tile_size-overlap); tiles=[]; y=0; idx=0
    while True:
        y0=min(y,max(0,h-tile_size)); y1=min(h,y0+tile_size); x=0
        while True:
            x0=min(x,max(0,w-tile_size));x1=min(w,x0+tile_size);p=out/f'tile_{idx:04d}.jpg'
            im.crop((x0,y0,x1,y1)).save(p,quality=92)
            tiles.append({'path':str(p),'x':x0,'y':y0,'width':x1-x0,'height':y1-y0});idx+=1
            if x1==w:break
            x+=step
        if y1==h:break
        y+=step
    return tiles
