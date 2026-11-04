from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.security import decode_token
from app.models.entities import User, Membership, Workspace
bearer=HTTPBearer(auto_error=False)
def current_user(creds: HTTPAuthorizationCredentials|None=Depends(bearer),db:Session=Depends(get_db)):
    if not creds: raise HTTPException(401,'Bearer token required')
    user=db.get(User,decode_token(creds.credentials))
    if not user: raise HTTPException(401,'User not found')
    return user
def require_membership(workspace_id,user,db):
    ws=db.get(Workspace,workspace_id)
    m=db.query(Membership).filter_by(workspace_id=workspace_id,user_id=user.id).first()
    if not ws or not m: raise HTTPException(404,'Workspace not found')
    return ws,m
