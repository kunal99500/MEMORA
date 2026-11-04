from app.core.config import get_settings

def yolo_detect(path:str,confidence:float=.25)->list[dict]:
    s=get_settings()
    if not s.yolo_enabled or not s.yolo_model_path:return []
    try: from ultralytics import YOLO
    except ImportError as e: raise RuntimeError('Install requirements-vision-optional.txt for YOLO') from e
    model=YOLO(s.yolo_model_path);out=[]
    for r in model.predict(path,conf=confidence,verbose=False):
        if r.boxes is None:continue
        for b in r.boxes:
            out.append({'label':r.names[int(b.cls[0])],'confidence':float(b.conf[0]),'bbox_xyxy':b.xyxy[0].tolist(),'provider':'ultralytics'})
    return out

def ocr_read(path:str)->list[dict]:
    if not get_settings().ocr_enabled:return []
    try: from paddleocr import PaddleOCR
    except ImportError as e: raise RuntimeError('Install optional OCR dependencies') from e
    engine=PaddleOCR(use_angle_cls=True,lang='en');out=[]
    for page in engine.ocr(path,cls=True) or []:
        for line in page or []:out.append({'text':line[1][0],'confidence':float(line[1][1]),'bbox':line[0]})
    return out

def barcode_read(path:str)->list[dict]:
    try:
        from pyzbar.pyzbar import decode
        from PIL import Image
    except ImportError:return []
    return [{'value':x.data.decode('utf-8',errors='replace'),'type':x.type} for x in decode(Image.open(path))]
