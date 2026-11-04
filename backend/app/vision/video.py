from pathlib import Path
import cv2
from app.vision.quality import assess_image
IMAGE_EXTS={'.jpg','.jpeg','.png','.webp'}
def extract_frames(path:str,out_dir:str,target_fps:float=1.5,max_frames:int=40)->list[dict]:
    out=Path(out_dir);out.mkdir(parents=True,exist_ok=True);ext=Path(path).suffix.lower()
    if ext in IMAGE_EXTS:
        img=cv2.imread(path)
        if img is None:return []
        p=out/'frame_0000.jpg';cv2.imwrite(str(p),img);h,w=img.shape[:2];q=assess_image(str(p))
        return [{'path':str(p),'timestamp_ms':0,'index':0,'width':w,'height':h,'sharpness':q.get('sharpness',0)}]
    cap=cv2.VideoCapture(path)
    if not cap.isOpened():return []
    fps=cap.get(cv2.CAP_PROP_FPS) or 25.;total=int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    n=min(max_frames,max(1,int(total/fps*target_fps))) if total else max_frames
    indices=sorted(set(int(i*max(total-1,0)/max(n-1,1)) for i in range(n))) if total else list(range(n))
    result=[]
    for k,idx in enumerate(indices):
        cap.set(cv2.CAP_PROP_POS_FRAMES,idx);ok,frame=cap.read()
        if not ok:continue
        p=out/f'frame_{k:04d}.jpg';cv2.imwrite(str(p),frame);h,w=frame.shape[:2];q=assess_image(str(p))
        result.append({'path':str(p),'timestamp_ms':int(idx/fps*1000),'index':idx,'width':w,'height':h,'sharpness':q.get('sharpness',0)})
    cap.release();return result
