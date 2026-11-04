import hashlib,logging,secrets,uuid
from datetime import datetime,timedelta,timezone
from pathlib import Path
from fastapi import APIRouter,Depends,HTTPException,UploadFile,File,BackgroundTasks
from sqlalchemy import or_
from sqlalchemy.orm import Session
from fastapi.responses import Response
from app.db.session import get_db,SessionLocal
from app.core.config import get_settings
from app.core.security import hash_password,verify_password,create_token
from app.models.entities import User,PasswordReset,Workspace,Membership,Location,Timeline,Capture,MediaAsset,ObjectIdentity,Observation,Event,Relationship,InspectionTask,InventoryRecord,Evidence,Frame,SceneNote,CareItem,ChatMessage
from app.schemas.api import Register,Login,PasswordResetRequest,PasswordResetConfirm,WorkspaceCreate,LocationCreate,CaptureCreate,TimelineCreate,SearchRequest,AskRequest,InventoryCreate,CareItemCreate
from app.services.access import current_user,require_membership
from app.services.evidence import crop_bounds,expand_crop_bounds
from app.services.processing import process_capture
from app.services.qa import answer_question
from app.services.password_reset import send_password_reset_email
router=APIRouter()
logger=logging.getLogger(__name__)

def _matches_media_signature(prefix: bytes, extension: str) -> bool:
    if extension in ('.jpg', '.jpeg'):
        return prefix.startswith(b'\xff\xd8\xff')
    if extension == '.png':
        return prefix.startswith(b'\x89PNG\r\n\x1a\n')
    if extension == '.webp':
        return prefix.startswith(b'RIFF') and prefix[8:12] == b'WEBP'
    if extension in ('.mp4', '.mov'):
        return prefix[4:8] == b'ftyp'
    if extension == '.avi':
        return prefix.startswith(b'RIFF') and prefix[8:12] == b'AVI '
    if extension in ('.mkv', '.webm'):
        return prefix.startswith(b'\x1a\x45\xdf\xa3')
    return False

def _background(capture_id):
    db=SessionLocal()
    try:process_capture(db,capture_id,get_settings().media_path)
    except Exception:db.rollback()
    finally:db.close()
@router.post('/auth/register')
def register(p:Register,db:Session=Depends(get_db)):
    email=p.email.lower()
    if db.query(User).filter_by(email=email).first():raise HTTPException(409,'Email already registered')
    u=User(email=email,name=p.name,password_hash=hash_password(p.password));db.add(u);db.flush()
    w=Workspace(name=f"{p.name or 'My'} Home",domain='home',tier='personal',owner_id=u.id);db.add(w);db.flush();db.add(Membership(workspace_id=w.id,user_id=u.id,role='owner'));db.commit()
    return {'access_token':create_token(u.id),'token_type':'bearer','user_id':u.id}
@router.post('/auth/login')
def login(p:Login,db:Session=Depends(get_db)):
    u=db.query(User).filter_by(email=p.email.lower()).first()
    if not u or not verify_password(p.password,u.password_hash):raise HTTPException(401,'Invalid email or password')
    return {'access_token':create_token(u.id,p.remember_me),'token_type':'bearer','user_id':u.id}
@router.post('/auth/password-reset/request',status_code=202)
def request_password_reset(p:PasswordResetRequest,background_tasks:BackgroundTasks,db:Session=Depends(get_db)):
    settings=get_settings()
    if not settings.password_reset_email_configured:
        raise HTTPException(503,'Password recovery email is not configured on this server.')
    user=db.query(User).filter_by(email=p.email.lower()).first()
    if user:
        now=datetime.now(timezone.utc)
        recent=db.query(PasswordReset).filter(
            PasswordReset.user_id==user.id,
            PasswordReset.created_at >= now-timedelta(seconds=60),
        ).first()
        if not recent:
            code=f'{secrets.randbelow(100_000_000):08d}'
            salt=secrets.token_hex(16)
            db.query(PasswordReset).filter(
                PasswordReset.user_id==user.id,
                PasswordReset.consumed_at.is_(None),
            ).update({'consumed_at':now},synchronize_session=False)
            db.add(PasswordReset(
                user_id=user.id,
                token_hash=hashlib.sha256(f'{salt}:{code}'.encode()).hexdigest(),
                salt=salt,
                expires_at=now+timedelta(minutes=10),
            ))
            db.commit()
            background_tasks.add_task(send_password_reset_email,user.email,code)
    return {'message':'If an account exists for that email, a reset code will be sent.'}
@router.post('/auth/password-reset/confirm')
def confirm_password_reset(p:PasswordResetConfirm,db:Session=Depends(get_db)):
    user=db.query(User).filter_by(email=p.email.lower()).first()
    reset=None
    if user:
        reset=db.query(PasswordReset).filter_by(
            user_id=user.id,consumed_at=None,
        ).order_by(PasswordReset.created_at.desc()).first()
    now=datetime.now(timezone.utc)
    if not reset or reset.attempts>=5:
        raise HTTPException(400,'Invalid or expired reset code.')
    expiry=reset.expires_at
    if expiry.tzinfo is None:
        expiry=expiry.replace(tzinfo=timezone.utc)
    if expiry<=now:
        db.query(PasswordReset).filter(
            PasswordReset.id==reset.id,
            PasswordReset.consumed_at.is_(None),
        ).update({'consumed_at':now},synchronize_session=False)
        db.commit()
        raise HTTPException(400,'Invalid or expired reset code.')
    candidate=hashlib.sha256(f'{reset.salt}:{p.code}'.encode()).hexdigest()
    if not secrets.compare_digest(candidate,reset.token_hash):
        db.query(PasswordReset).filter(
            PasswordReset.id==reset.id,
            PasswordReset.consumed_at.is_(None),
            PasswordReset.attempts<5,
        ).update(
            {'attempts':PasswordReset.attempts+1},
            synchronize_session=False,
        )
        db.commit()
        raise HTTPException(400,'Invalid or expired reset code.')
    consumed=db.query(PasswordReset).filter(
        PasswordReset.id==reset.id,
        PasswordReset.consumed_at.is_(None),
        PasswordReset.attempts<5,
        PasswordReset.expires_at>now,
    ).update({'consumed_at':now},synchronize_session=False)
    if consumed!=1:
        db.rollback()
        raise HTTPException(400,'Invalid or expired reset code.')
    user.password_hash=hash_password(p.new_password)
    db.query(PasswordReset).filter(
        PasswordReset.user_id==user.id,
        PasswordReset.consumed_at.is_(None),
        PasswordReset.id!=reset.id,
    ).update({'consumed_at':now},synchronize_session=False)
    db.commit()
    return {'message':'Password updated. You can now sign in.'}
@router.get('/auth/me')
def me(u:User=Depends(current_user)):return {'id':u.id,'email':u.email,'name':u.name}
@router.post('/workspaces')
def create_workspace(p:WorkspaceCreate,u:User=Depends(current_user),db:Session=Depends(get_db)):
    domain='business' if p.tier=='business' else 'home'
    w=Workspace(name=p.name,domain=domain,tier=p.tier,owner_id=u.id);db.add(w);db.flush();db.add(Membership(workspace_id=w.id,user_id=u.id,role='owner'));db.commit();return {'id':w.id,'name':w.name,'domain':w.domain,'tier':w.tier}
@router.get('/workspaces')
def workspaces(u:User=Depends(current_user),db:Session=Depends(get_db)):
    rows=db.query(Workspace).join(Membership).filter(Membership.user_id==u.id).all();return {'workspaces':[{'id':w.id,'name':w.name,'domain':w.domain,'tier':w.tier} for w in rows]}
@router.post('/workspaces/{wid}/locations')
def add_location(wid:str,p:LocationCreate,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(wid,u,db)
    if p.parent_id:
        parent=db.get(Location,p.parent_id)
        if not parent or parent.workspace_id!=wid:raise HTTPException(400,'Parent location is outside workspace')
    x=Location(workspace_id=wid,name=p.name,location_type=p.location_type,parent_id=p.parent_id,metadata_json=p.metadata);db.add(x);db.commit();return {'id':x.id,'name':x.name}
@router.get('/workspaces/{wid}/locations')
def locations(wid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(wid,u,db);rows=db.query(Location).filter_by(workspace_id=wid).all();return {'locations':[{'id':x.id,'name':x.name,'type':x.location_type,'parent_id':x.parent_id} for x in rows]}
@router.post('/workspaces/{wid}/timelines')
def create_timeline(wid:str,p:TimelineCreate,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(wid,u,db)
    if not p.name.strip():
        raise HTTPException(422,'Timeline name cannot be empty')
    location=db.get(Location,p.location_id)
    if not location or location.workspace_id!=wid:
        raise HTTPException(400,'Timeline space is outside workspace')
    timeline=Timeline(
        workspace_id=wid,
        location_id=location.id,
        created_by=u.id,
        name=p.name.strip(),
    )
    db.add(timeline)
    db.commit()
    return {'id':timeline.id,'name':timeline.name,'location_id':timeline.location_id}
@router.get('/workspaces/{wid}/timelines')
def list_timelines(wid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(wid,u,db)
    locations={row.id:row.name for row in db.query(Location).filter_by(workspace_id=wid).all()}
    rows=(db.query(Timeline).filter_by(workspace_id=wid)
          .order_by(Timeline.created_at.desc()).all())
    return {'timelines':[{
        'id':row.id,
        'name':row.name,
        'location_id':row.location_id,
        'space':locations.get(row.location_id,''),
        'created_at':row.created_at.isoformat() if row.created_at else None,
    } for row in rows]}
@router.post('/captures')
def create_capture(p:CaptureCreate,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(p.workspace_id,u,db)
    location_id=p.location_id
    if location_id:
        loc=db.get(Location,location_id)
        if not loc or loc.workspace_id!=p.workspace_id:raise HTTPException(400,'Invalid location')
    if p.timeline_id:
        timeline=db.get(Timeline,p.timeline_id)
        if (not timeline or timeline.workspace_id!=p.workspace_id or
                (location_id and timeline.location_id!=location_id)):
            raise HTTPException(400,'Timeline does not belong to this space')
        if location_id is None:
            location_id=timeline.location_id
    x=Capture(workspace_id=p.workspace_id,location_id=location_id,timeline_id=p.timeline_id,created_by=u.id,label=p.label,domain=p.domain,media_type=p.media_type);db.add(x);db.commit();return {'capture_id':x.id,'status':x.status}
@router.post('/captures/{cid}/media')
async def upload(cid:str,file:UploadFile=File(...),u:User=Depends(current_user),db:Session=Depends(get_db)):
    cap=db.get(Capture,cid)
    if not cap:raise HTTPException(404,'Capture not found')
    require_membership(cap.workspace_id,u,db)
    ext=Path(file.filename or '').suffix.lower();kinds={'.jpg':'photo','.jpeg':'photo','.png':'photo','.webp':'photo','.mp4':'video','.mov':'video','.avi':'video','.mkv':'video','.webm':'video'}
    if ext not in kinds:raise HTTPException(415,'Unsupported file type')
    if cap.media_type not in ('mixed',kinds[ext]):raise HTTPException(400,'Media type does not match capture')
    settings=get_settings();limit=settings.max_upload_mb*1024*1024
    mid='med_'+uuid.uuid4().hex
    folder=settings.media_path/cap.workspace_id/cid
    folder.mkdir(parents=True,exist_ok=True)
    temp=folder/(mid+ext+'.tmp');dest=folder/(mid+ext)
    digest=hashlib.sha256();size=0;prefix=bytearray()
    try:
        with temp.open('wb') as output:
            while chunk:=await file.read(1024*1024):
                size+=len(chunk)
                if size>limit:raise HTTPException(413,'Upload exceeds configured limit')
                if len(prefix)<16:prefix.extend(chunk[:16-len(prefix)])
                digest.update(chunk);output.write(chunk)
        if size==0:raise HTTPException(400,'Empty upload')
        if not _matches_media_signature(bytes(prefix),ext):
            raise HTTPException(415,'File content does not match its extension')
        digest_hex=digest.hexdigest()
        duplicate=db.query(MediaAsset).filter_by(capture_id=cid,sha256=digest_hex).first()
        if duplicate:return {'media_id':duplicate.id,'duplicate':True}
        temp.replace(dest)
        mime_type={
            '.jpg':'image/jpeg','.jpeg':'image/jpeg','.png':'image/png','.webp':'image/webp',
            '.mp4':'video/mp4','.mov':'video/quicktime','.avi':'video/x-msvideo',
            '.mkv':'video/x-matroska','.webm':'video/webm',
        }[ext]
        row=MediaAsset(id=mid,capture_id=cid,original_name=Path(file.filename or 'upload').name,
            stored_path=str(dest),mime_type=mime_type,media_kind=kinds[ext],size_bytes=size,sha256=digest_hex)
        db.add(row);db.commit()
        return {'media_id':row.id,'size_bytes':size,'sha256':digest_hex}
    finally:
        if temp.exists():temp.unlink()
@router.post('/captures/{cid}/process')
def process(cid:str,bg:BackgroundTasks,u:User=Depends(current_user),db:Session=Depends(get_db)):
    cap=db.get(Capture,cid)
    if not cap:raise HTTPException(404,'Capture not found')
    require_membership(cap.workspace_id,u,db)
    if not db.query(MediaAsset).filter_by(capture_id=cid).first():raise HTTPException(400,'Upload media first')
    if cap.status=='processing':return {'capture_id':cid,'status':'processing'}
    cap.status='queued';db.commit();bg.add_task(_background,cid);return {'capture_id':cid,'status':'queued'}
@router.get('/captures/{cid}')
def get_capture(cid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    cap=db.get(Capture,cid)
    if not cap:raise HTTPException(404,'Capture not found')
    require_membership(cap.workspace_id,u,db);obs=db.query(Observation).filter_by(capture_id=cid).count();media=db.query(MediaAsset).filter_by(capture_id=cid).count()
    return {'capture_id':cid,'status':cap.status,'domain':cap.domain,'label':cap.label,'media_count':media,'observation_count':obs,'report':cap.report}
@router.get('/objects')
def objects(workspace_id:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(workspace_id,u,db)
    out=[]
    for o in db.query(ObjectIdentity).filter_by(workspace_id=workspace_id).all():
        ob=db.query(Observation).filter_by(object_id=o.id).order_by(Observation.observed_at.desc()).first()
        out.append({'id':o.id,'name':o.canonical_label,'label':o.canonical_label,'category':o.category,'domain':o.domain,'identity_status':o.identity_status,'location':ob.location_text if ob else '','condition':ob.condition_text if ob else '','evidence_id':ob.evidence_id if ob else None})
    return {'objects':out}
@router.get('/objects/{oid}/history')
def history(oid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    obj=db.get(ObjectIdentity,oid)
    if not obj:raise HTTPException(404,'Object not found')
    require_membership(obj.workspace_id,u,db);obs=db.query(Observation).filter_by(object_id=oid).order_by(Observation.observed_at.desc()).all();ev=db.query(Event).filter_by(object_id=oid).order_by(Event.created_at.desc()).all()
    return {'object_id':oid,'observations':[{'id':x.id,'label':x.label,'location':x.location_text,'condition':x.condition_text,'confidence':x.confidence,'verification':x.verification_status,'evidence_id':x.evidence_id,'observed_at':x.observed_at} for x in obs],'events':[{'id':e.id,'type':e.event_type,'details':e.details,'evidence_ids':e.evidence_ids} for e in ev]}
@router.post('/ask')
def ask(p:AskRequest,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(p.workspace_id,u,db)
    question=ChatMessage(
        workspace_id=p.workspace_id,
        user_id=u.id,
        role='user',
        content=p.query,
        conversation_id=p.conversation_id,
    )
    db.add(question)
    db.commit()
    result=answer_question(db,p.workspace_id,p.query)
    answer=ChatMessage(
        workspace_id=p.workspace_id,
        user_id=u.id,
        role='assistant',
        content=str(result.get('answer','')),
        evidence_ids=result.get('evidence',[]) or [],
        confidence=float(result.get('confidence',0) or 0),
        language=str(result.get('language') or ''),
        conversation_id=p.conversation_id,
    )
    db.add(answer)
    db.commit()
    return result
@router.get('/workspaces/{wid}/chat-history')
def chat_history(
    wid:str,
    conversation_id:str|None=None,
    u:User=Depends(current_user),
    db:Session=Depends(get_db),
):
    require_membership(wid,u,db)
    query=db.query(ChatMessage).filter_by(workspace_id=wid,user_id=u.id)
    if conversation_id in (None,'legacy'):
        query=query.filter(ChatMessage.conversation_id.is_(None))
    else:
        query=query.filter_by(conversation_id=conversation_id)
    rows=(query
          .order_by(ChatMessage.created_at.desc(),ChatMessage.id.desc())
          .limit(200).all())
    rows.reverse()
    return {'messages':[{
        'id':message.id,
        'role':message.role,
        'content':message.content or (
            "I couldn't generate a reply this time. Please try asking again."
            if message.role == 'assistant' else ''
        ),
        'evidence':message.evidence_ids or [],
        'confidence':message.confidence,
        'language':message.language or '',
        'created_at':message.created_at.isoformat(),
    } for message in rows]}
@router.get('/workspaces/{wid}/chat-conversations')
def chat_conversations(wid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(wid,u,db)
    rows=(db.query(ChatMessage)
          .filter_by(workspace_id=wid,user_id=u.id)
          .order_by(ChatMessage.created_at.desc(),ChatMessage.id.desc())
          .limit(2000).all())
    conversations={}
    for message in rows:
        key=message.conversation_id or 'legacy'
        conversation=conversations.setdefault(key,{
            'id':key,
            'title':'New chat',
            'updated_at':message.created_at.isoformat(),
        })
        if message.role=='user' and conversation['title']=='New chat':
            conversation['title']=message.content[:80] or 'New chat'
    return {'conversations':list(conversations.values())}
@router.delete('/workspaces/{wid}/chat-history')
def clear_chat_history(
    wid:str,
    conversation_id:str|None=None,
    u:User=Depends(current_user),
    db:Session=Depends(get_db),
):
    require_membership(wid,u,db)
    query=db.query(ChatMessage).filter_by(workspace_id=wid,user_id=u.id)
    if conversation_id in (None,'legacy'):
        query=query.filter(ChatMessage.conversation_id.is_(None))
    else:
        query=query.filter_by(conversation_id=conversation_id)
    deleted=query.delete(synchronize_session=False)
    db.commit()
    return {'deleted':deleted}
@router.get('/workspaces/{wid}/overview')
def overview(wid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(wid,u,db)
    objs=db.query(ObjectIdentity).filter_by(workspace_id=wid).count()
    locs=db.query(Location).filter_by(workspace_id=wid).count()
    evs=db.query(Event).filter_by(workspace_id=wid).count()
    mems=db.query(Membership).filter_by(workspace_id=wid).count()
    caps=db.query(Capture).filter_by(workspace_id=wid).count()
    photos=(db.query(MediaAsset).join(Capture,MediaAsset.capture_id==Capture.id)
            .filter(Capture.workspace_id==wid,MediaAsset.media_kind=='photo').count())
    return {'objects':objs,'rooms':locs,'spaces':locs,'changes':evs,'members':mems,'activities':caps,'scans':caps,'photos':photos}
@router.get('/workspaces/{wid}/rooms-summary')
def rooms_summary(wid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(wid,u,db)
    out=[]
    for loc in db.query(Location).filter_by(workspace_id=wid).all():
        img=(db.query(MediaAsset).join(Capture,MediaAsset.capture_id==Capture.id)
             .filter(Capture.workspace_id==wid,Capture.location_id==loc.id,
                     MediaAsset.media_kind=='photo').count())
        out.append({'space_id':loc.id,'location_id':loc.id,'name':loc.name,'image_count':img,'location_type':loc.location_type})
    return {'rooms':out}
@router.get('/workspaces/{wid}/timeline')
def timeline(
    wid:str,
    timeline_id:str|None=None,
    u:User=Depends(current_user),
    db:Session=Depends(get_db),
):
    require_membership(wid,u,db)
    if timeline_id:
        selected=db.query(Timeline).filter_by(
            id=timeline_id,workspace_id=wid,
        ).first()
        if not selected:
            raise HTTPException(404,'Timeline not found')
        captures=(db.query(Capture).filter_by(
            workspace_id=wid,timeline_id=timeline_id,
        ).order_by(Capture.created_at.desc()).all())
    else:
        captures=(db.query(Capture).filter_by(
            workspace_id=wid,timeline_id=None,
        ).order_by(Capture.created_at.desc()).all())
    locs={l.id:l.name for l in db.query(Location).filter_by(workspace_id=wid).all()}
    out=[]
    for cap in captures:
        ev=db.query(Evidence).filter_by(capture_id=cap.id,source_type='original_frame').first()
        media=db.query(MediaAsset).filter_by(capture_id=cap.id).first()
        out.append({'capture_id':cap.id,'space':locs.get(cap.location_id,''),'label':cap.label,
            'image':f'/api/v1/evidence/{ev.id}/file' if ev else None,
            'media_type':media.media_kind if media else cap.media_type,
            'created_at':cap.created_at.isoformat() if cap.created_at else None,
            'status':cap.status})
    return {'entries':out}
@router.get('/workspaces/{wid}/scan-images')
def scan_images(wid:str,location_id:str|None=None,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(wid,u,db)
    out=[]
    for cap in db.query(Capture).filter_by(workspace_id=wid).order_by(Capture.created_at.desc()).all():
        if location_id and cap.location_id!=location_id: continue
        ev=db.query(Evidence).filter_by(capture_id=cap.id,source_type='original_frame').first()
        media=db.query(MediaAsset).filter_by(capture_id=cap.id,media_kind='photo').first()
        if not ev and not media: continue
        image=(f'/api/v1/evidence/{ev.id}/file' if ev else
               f'/api/v1/captures/{cap.id}/media/{media.id}/file')
        out.append({'capture_id':cap.id,'label':cap.label,'image':image,'status':cap.status})
    return {'images':out}

@router.get('/captures/{cid}/media/{mid}/file')
def capture_media_file(
    cid:str,
    mid:str,
    u:User=Depends(current_user),
    db:Session=Depends(get_db),
):
    from fastapi.responses import FileResponse
    cap=db.get(Capture,cid)
    if not cap:raise HTTPException(404,'Capture not found')
    require_membership(cap.workspace_id,u,db)
    media=db.get(MediaAsset,mid)
    if not media or media.capture_id!=cid:
        raise HTTPException(404,'Capture media not found')
    if media.media_kind!='photo':
        raise HTTPException(415,'Only photo media can be previewed as an image')
    path=Path(media.stored_path)
    root=get_settings().media_path.resolve()
    try:path.resolve().relative_to(root)
    except ValueError:raise HTTPException(403,'Media path is outside storage')
    if not path.is_file():raise HTTPException(404,'Media file unavailable')
    return FileResponse(path,media_type=media.mime_type)

@router.delete('/captures/{cid}')
def delete_capture(cid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    cap=db.get(Capture,cid)
    if not cap:raise HTTPException(404,'Capture not found')
    require_membership(cap.workspace_id,u,db)
    files=[
        Path(row.stored_path)
        for row in db.query(MediaAsset).filter_by(capture_id=cid).all()
    ]
    files.extend(
        Path(row.stored_path)
        for row in db.query(Frame).filter_by(capture_id=cid).all()
    )
    files.extend(
        Path(row.crop_path)
        for row in db.query(Evidence).filter_by(capture_id=cid).all()
        if row.crop_path
    )
    evidence_ids=[
        row.id for row in db.query(Evidence.id).filter_by(capture_id=cid).all()
    ]
    obj_ids={o.object_id for o in db.query(Observation).filter_by(capture_id=cid).all() if o.object_id}
    db.query(Event).filter_by(capture_id=cid).delete(synchronize_session=False)
    db.query(InspectionTask).filter_by(capture_id=cid).delete(synchronize_session=False)
    if evidence_ids:
        db.query(Relationship).filter(
            Relationship.evidence_id.in_(evidence_ids)
        ).delete(synchronize_session=False)
    db.query(Observation).filter_by(capture_id=cid).delete(synchronize_session=False)
    db.query(SceneNote).filter_by(capture_id=cid).delete(synchronize_session=False)
    db.query(Evidence).filter_by(capture_id=cid).delete(synchronize_session=False)
    db.query(Frame).filter_by(capture_id=cid).delete(synchronize_session=False)
    db.query(MediaAsset).filter_by(capture_id=cid).delete(synchronize_session=False)
    for oid in obj_ids:
        related=(
            db.query(Event).filter_by(object_id=oid).count()
            or db.query(InventoryRecord).filter_by(object_id=oid).count()
            or db.query(Relationship).filter(or_(
                Relationship.subject_object_id==oid,
                Relationship.target_object_id==oid,
            )).count()
        )
        if (not related and
                not db.query(Observation).filter_by(object_id=oid).count()):
            o=db.get(ObjectIdentity,oid)
            if o:db.delete(o)
    db.delete(cap);db.commit()
    for path in files:
        try:
            path.unlink(missing_ok=True)
        except OSError:
            logger.exception('Could not remove deleted capture file %s',path)
    return {'deleted':cid}
@router.get('/care-items')
def list_care_items(workspace_id:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(workspace_id,u,db)
    rows=db.query(CareItem).filter_by(workspace_id=workspace_id).order_by(CareItem.created_at.desc()).all()
    return {'items':[{'id':c.id,'name':c.name,'note':c.note,'location':c.location} for c in rows]}
@router.post('/care-items')
def create_care_item(p:CareItemCreate,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(p.workspace_id,u,db)
    c=CareItem(workspace_id=p.workspace_id,created_by=u.id,name=p.name,note=p.note,location=p.location)
    db.add(c);db.commit()
    return {'id':c.id}
@router.delete('/care-items/{cid}')
def delete_care_item(cid:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    c=db.get(CareItem,cid)
    if not c:raise HTTPException(404,'Item not found')
    require_membership(c.workspace_id,u,db)
    db.delete(c);db.commit()
    return {'deleted':cid}
@router.post('/search')
def search(p:SearchRequest,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(p.workspace_id,u,db);q=db.query(ObjectIdentity).filter(ObjectIdentity.workspace_id==p.workspace_id,ObjectIdentity.canonical_label.ilike(f'%{p.query}%'))
    if p.domain:q=q.filter(ObjectIdentity.domain==p.domain)
    rows=q.limit(30).all();return {'results':[{'object_id':o.id,'label':o.canonical_label,'category':o.category,'identity_status':o.identity_status} for o in rows],'mode':'lexical_baseline','note':'Connect pgvector and visual embeddings for semantic/image retrieval.'}
@router.post('/inventory')
def inventory_add(p:InventoryCreate,u:User=Depends(current_user),db:Session=Depends(get_db)):
    ws,_=require_membership(p.workspace_id,u,db)
    if ws.domain!='business':raise HTTPException(400,'Business workspace required')
    x=InventoryRecord(workspace_id=p.workspace_id,product_name=p.product_name,sku=p.sku,barcode=p.barcode,rfid=p.rfid,system_quantity=p.system_quantity,location_id=p.location_id);db.add(x);db.commit();return {'inventory_id':x.id,'status':x.status}
@router.get('/inventory')
def inventory_list(workspace_id:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    ws,_=require_membership(workspace_id,u,db)
    if ws.domain!='business':raise HTTPException(400,'Business workspace required')
    rows=db.query(InventoryRecord).filter_by(workspace_id=workspace_id).all();return {'items':[{'id':x.id,'product_name':x.product_name,'sku':x.sku,'barcode':x.barcode,'rfid':x.rfid,'system_quantity':x.system_quantity,'visible_count':x.visible_count,'status':x.status} for x in rows]}
@router.get('/inspections/tasks')
def tasks(workspace_id:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(workspace_id,u,db);rows=db.query(InspectionTask).filter_by(workspace_id=workspace_id).order_by(InspectionTask.priority).all();return {'tasks':[{'id':t.id,'title':t.title,'reason':t.reason,'status':t.status,'priority':t.priority,'location_id':t.location_id} for t in rows]}
@router.post('/inspections/tasks')
def task_create(workspace_id:str,title:str,reason:str='',u:User=Depends(current_user),db:Session=Depends(get_db)):
    require_membership(workspace_id,u,db);t=InspectionTask(workspace_id=workspace_id,title=title,reason=reason);db.add(t);db.commit();return {'task_id':t.id,'status':t.status}

@router.get('/evidence/{evidence_id}')
def evidence_detail(evidence_id:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    from app.models.entities import Evidence
    ev=db.get(Evidence,evidence_id)
    if not ev:raise HTTPException(404,'Evidence not found')
    cap=db.get(Capture,ev.capture_id)
    require_membership(cap.workspace_id,u,db)
    return {'id':ev.id,'capture_id':ev.capture_id,'frame_id':ev.frame_id,'media_id':ev.media_id,
            'bbox':ev.bbox,'timestamp_ms':ev.timestamp_ms,'source_type':ev.source_type}

def _authorized_evidence_path(evidence_id:str,u:User,db:Session)->Path:
    from app.models.entities import Evidence,Frame,MediaAsset
    ev=db.get(Evidence,evidence_id)
    if not ev:raise HTTPException(404,'Evidence not found')
    cap=db.get(Capture,ev.capture_id)
    if not cap:raise HTTPException(404,'Evidence capture not found')
    require_membership(cap.workspace_id,u,db)
    frame=db.get(Frame,ev.frame_id) if ev.frame_id else None
    media=db.get(MediaAsset,ev.media_id)
    if not frame and not media:raise HTTPException(404,'Evidence media unavailable')
    path=Path(frame.stored_path) if frame else Path(media.stored_path)
    root=get_settings().media_path.resolve()
    try:path.resolve().relative_to(root)
    except ValueError:raise HTTPException(403,'Evidence path is outside media storage')
    if not path.is_file():raise HTTPException(404,'Evidence file unavailable')
    return path

@router.get('/evidence/{evidence_id}/file')
def evidence_file(evidence_id:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    from fastapi.responses import FileResponse
    path=_authorized_evidence_path(evidence_id,u,db)
    return FileResponse(path)

@router.get('/evidence/{evidence_id}/preview')
def evidence_preview(evidence_id:str,u:User=Depends(current_user),db:Session=Depends(get_db)):
    import cv2
    from fastapi.responses import FileResponse
    from app.models.entities import Evidence
    from app.models.entities import Frame
    ev=db.get(Evidence,evidence_id)
    if not ev:raise HTTPException(404,'Evidence not found')
    path=_authorized_evidence_path(evidence_id,u,db)
    frame=db.get(Frame,ev.frame_id) if ev.frame_id else None
    if not frame or not isinstance(ev.bbox,list) or len(ev.bbox)!=4:
        return FileResponse(path)
    image=cv2.imread(str(path))
    if image is None:raise HTTPException(415,'Evidence image cannot be decoded')
    height,width=image.shape[:2]
    try:
        bounds=crop_bounds(ev.bbox,width,height)
    except ValueError as exc:raise HTTPException(422,str(exc))
    x1,y1,x2,y2=expand_crop_bounds(bounds,width,height)
    pad_x=max(2,int((x2-x1)*0.12))
    pad_y=max(2,int((y2-y1)*0.12))
    crop=image[max(0,y1-pad_y):min(height,y2+pad_y),
               max(0,x1-pad_x):min(width,x2+pad_x)]
    ok,encoded=cv2.imencode('.jpg',crop,[cv2.IMWRITE_JPEG_QUALITY,90])
    if not ok:raise HTTPException(500,'Could not encode evidence preview')
    return Response(content=encoded.tobytes(),media_type='image/jpeg')


# ---------------------------------------------------------------------------
# Camera registry. This stores metadata and a secret-manager reference only.
# It does NOT persist RTSP URLs, usernames or passwords.
# ---------------------------------------------------------------------------
from pydantic import BaseModel, Field
from app.models.entities import Camera

class CameraCreatePayload(BaseModel):
    workspace_id: str
    name: str = Field(min_length=1, max_length=160)
    location_id: str | None = None
    protocol: str = Field(default="rtsp", pattern="^(rtsp|onvif|vendor_api)$")
    connection_ref: str = Field(default="", max_length=250)
    retention_days: int = Field(default=7, ge=1, le=90)

@router.get('/cameras')
def camera_list(workspace_id: str, u: User = Depends(current_user), db: Session = Depends(get_db)):
    require_membership(workspace_id, u, db)
    rows = db.query(Camera).filter_by(workspace_id=workspace_id).order_by(Camera.created_at.desc()).all()
    return {'cameras': [{
        'id': c.id, 'name': c.name, 'location_id': c.location_id,
        'protocol': c.protocol, 'connection_ref': c.connection_ref,
        'status': c.status, 'enabled': c.enabled,
        'retention_days': c.retention_days,
        'created_at': c.created_at.isoformat() if c.created_at else None
    } for c in rows]}

@router.post('/cameras')
def camera_create(p: CameraCreatePayload, u: User = Depends(current_user), db: Session = Depends(get_db)):
    require_membership(p.workspace_id, u, db)
    if p.location_id:
        loc = db.get(Location, p.location_id)
        if not loc or loc.workspace_id != p.workspace_id:
            raise HTTPException(404, 'Location not found in this workspace')
    c = Camera(workspace_id=p.workspace_id, name=p.name.strip(), location_id=p.location_id,
               protocol=p.protocol, connection_ref=p.connection_ref,
               retention_days=p.retention_days, status='configured')
    db.add(c); db.commit(); db.refresh(c)
    return {'camera_id': c.id, 'status': c.status}

@router.patch('/cameras/{camera_id}')
def camera_update(camera_id: str, enabled: bool | None = None, name: str | None = None,
                  u: User = Depends(current_user), db: Session = Depends(get_db)):
    c = db.get(Camera, camera_id)
    if not c: raise HTTPException(404, 'Camera not found')
    require_membership(c.workspace_id, u, db)
    if enabled is not None: c.enabled = enabled
    if name is not None and name.strip(): c.name = name.strip()
    db.commit()
    return {'camera_id': c.id, 'enabled': c.enabled, 'name': c.name}

@router.delete('/cameras/{camera_id}')
def camera_delete(camera_id: str, u: User = Depends(current_user), db: Session = Depends(get_db)):
    c = db.get(Camera, camera_id)
    if not c: raise HTTPException(404, 'Camera not found')
    require_membership(c.workspace_id, u, db)
    db.delete(c); db.commit()
    return {'deleted': camera_id}

@router.post('/cameras/{camera_id}/pause')
def camera_pause(camera_id: str, paused: bool = True, u: User = Depends(current_user), db: Session = Depends(get_db)):
    c = db.get(Camera, camera_id)
    if not c: raise HTTPException(404, 'Camera not found')
    require_membership(c.workspace_id, u, db)
    c.enabled = not paused
    c.status = 'paused' if paused else 'configured'
    db.commit()
    return {'camera_id': c.id, 'status': c.status, 'enabled': c.enabled}


@router.post('/cameras/{camera_id}/start')
def camera_start(camera_id: str, u: User = Depends(current_user), db: Session = Depends(get_db)):
    from app.cameras.manager import camera_manager
    c = db.get(Camera, camera_id)
    if not c: raise HTTPException(404, 'Camera not found')
    require_membership(c.workspace_id, u, db)
    if not c.enabled: raise HTTPException(409, 'Camera is paused; enable it before starting')
    try:
        camera_manager.start(camera_id)
    except ValueError as exc:
        raise HTTPException(400, str(exc))
    c.status = 'starting'
    db.commit()
    return {'camera_id': camera_id, 'status': 'starting'}

@router.post('/cameras/{camera_id}/stop')
def camera_stop(camera_id: str, u: User = Depends(current_user), db: Session = Depends(get_db)):
    from app.cameras.manager import camera_manager
    c = db.get(Camera, camera_id)
    if not c: raise HTTPException(404, 'Camera not found')
    require_membership(c.workspace_id, u, db)
    camera_manager.stop(camera_id)
    c.status = 'stopped'
    db.commit()
    return {'camera_id': camera_id, 'status': 'stopped'}

@router.get('/cameras/{camera_id}/status')
def camera_status(camera_id: str, u: User = Depends(current_user), db: Session = Depends(get_db)):
    from app.cameras.manager import camera_manager
    c = db.get(Camera, camera_id)
    if not c: raise HTTPException(404, 'Camera not found')
    require_membership(c.workspace_id, u, db)
    return {'camera_id': camera_id, 'database_status': c.status,
            **camera_manager.status(camera_id)}
