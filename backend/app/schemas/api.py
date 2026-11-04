from typing import Literal, Any
from pydantic import BaseModel, EmailStr, Field
class Register(BaseModel): email: EmailStr; name: str=''; password: str=Field(min_length=10,max_length=128)
class Login(BaseModel): email: EmailStr; password: str; remember_me: bool = False
class PasswordResetRequest(BaseModel): email: EmailStr
class PasswordResetConfirm(BaseModel):
    email: EmailStr
    code: str = Field(pattern=r'^\d{8}$')
    new_password: str = Field(min_length=10, max_length=128)
class WorkspaceCreate(BaseModel): name: str; tier: Literal['personal','family','business']='personal'
class LocationCreate(BaseModel): name: str; location_type: str='room'; parent_id: str|None=None; metadata: dict[str,Any]=Field(default_factory=dict)
class CaptureCreate(BaseModel):
    workspace_id: str
    label: str=''
    domain: Literal['home','business']='home'
    media_type: Literal['photo','video','mixed']='photo'
    location_id: str|None=None
    timeline_id: str|None=None

class TimelineCreate(BaseModel):
    location_id: str
    name: str = Field(min_length=1, max_length=200)
class SearchRequest(BaseModel): workspace_id: str; query: str; domain: Literal['home','business']|None=None
class AskRequest(BaseModel):
    workspace_id: str
    query: str
    location_id: str|None=None
    conversation_id: str|None=Field(default=None, max_length=64)
class DocumentAsk(BaseModel):
    query: str = Field(min_length=1, max_length=500)
class AiPrivacyConsentCreate(BaseModel):
    policy_version: str = Field(min_length=1, max_length=40)
class InventoryCreate(BaseModel): workspace_id: str; product_name: str; sku: str|None=None; barcode: str|None=None; rfid: str|None=None; system_quantity: int|None=Field(default=None,ge=0); location_id: str|None=None
class CareItemCreate(BaseModel): workspace_id: str; name: str; note: str=''; location: str=''


class CameraCreate(BaseModel):
    workspace_id: str
    name: str = Field(min_length=1, max_length=160)
    location_id: str | None = None
    protocol: str = Field(default="rtsp", pattern="^(rtsp|onvif|vendor_api)$")
    # A secret-manager reference only; never send raw camera passwords to this API.
    connection_ref: str = Field(default="", max_length=250)
    retention_days: int = Field(default=7, ge=1, le=90)
