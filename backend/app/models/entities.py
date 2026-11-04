import uuid
from datetime import datetime, timezone
from sqlalchemy import String, Text, Float, DateTime, ForeignKey, Integer, JSON, UniqueConstraint, Index
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base

def uid(p): return f'{p}_{uuid.uuid4().hex}'
def now(): return datetime.now(timezone.utc)
class User(Base):
    __tablename__='users'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('usr'))
    email: Mapped[str]=mapped_column(String(320),unique=True,index=True)
    name: Mapped[str]=mapped_column(String(160),default='')
    password_hash: Mapped[str]=mapped_column(String(512))
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
class PasswordReset(Base):
    __tablename__='password_resets'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('rst'))
    user_id: Mapped[str]=mapped_column(ForeignKey('users.id'),index=True)
    token_hash: Mapped[str]=mapped_column(String(64))
    salt: Mapped[str]=mapped_column(String(32))
    attempts: Mapped[int]=mapped_column(Integer,default=0)
    expires_at: Mapped[datetime]=mapped_column(DateTime(timezone=True))
    consumed_at: Mapped[datetime|None]=mapped_column(DateTime(timezone=True),nullable=True)
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now,index=True)
class Workspace(Base):
    __tablename__='workspaces'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('wsp'))
    name: Mapped[str]=mapped_column(String(200)); domain: Mapped[str]=mapped_column(String(20),default='home'); tier: Mapped[str]=mapped_column(String(20),default='personal')
    owner_id: Mapped[str]=mapped_column(ForeignKey('users.id'),index=True)
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
class Membership(Base):
    __tablename__='memberships'; __table_args__=(UniqueConstraint('workspace_id','user_id'),)
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('mem'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    user_id: Mapped[str]=mapped_column(ForeignKey('users.id'),index=True)
    role: Mapped[str]=mapped_column(String(30),default='member')
class Location(Base):
    __tablename__='locations'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('loc'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    parent_id: Mapped[str|None]=mapped_column(ForeignKey('locations.id'),nullable=True)
    name: Mapped[str]=mapped_column(String(200)); location_type: Mapped[str]=mapped_column(String(40))
    metadata_json: Mapped[dict]=mapped_column('metadata',JSON,default=dict)
class Timeline(Base):
    __tablename__='timelines'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('tml'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    location_id: Mapped[str]=mapped_column(ForeignKey('locations.id'),index=True)
    created_by: Mapped[str]=mapped_column(ForeignKey('users.id'))
    name: Mapped[str]=mapped_column(String(200))
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
class Capture(Base):
    __tablename__='captures'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('cap'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    location_id: Mapped[str|None]=mapped_column(ForeignKey('locations.id'),nullable=True)
    timeline_id: Mapped[str|None]=mapped_column(ForeignKey('timelines.id'),nullable=True,index=True)
    created_by: Mapped[str]=mapped_column(ForeignKey('users.id'))
    label: Mapped[str]=mapped_column(String(250),default=''); domain: Mapped[str]=mapped_column(String(20))
    media_type: Mapped[str]=mapped_column(String(20)); status: Mapped[str]=mapped_column(String(30),default='created',index=True)
    report: Mapped[dict]=mapped_column(JSON,default=dict)
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
    completed_at: Mapped[datetime|None]=mapped_column(DateTime(timezone=True),nullable=True)
class MediaAsset(Base):
    __tablename__='media_assets'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('med'))
    capture_id: Mapped[str]=mapped_column(ForeignKey('captures.id'),index=True)
    original_name: Mapped[str]=mapped_column(String(255)); stored_path: Mapped[str]=mapped_column(Text)
    mime_type: Mapped[str]=mapped_column(String(100)); media_kind: Mapped[str]=mapped_column(String(20))
    size_bytes: Mapped[int]=mapped_column(Integer); sha256: Mapped[str]=mapped_column(String(64),index=True)
class Frame(Base):
    __tablename__='frames'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('frm'))
    capture_id: Mapped[str]=mapped_column(ForeignKey('captures.id'),index=True)
    media_id: Mapped[str]=mapped_column(ForeignKey('media_assets.id'))
    stored_path: Mapped[str]=mapped_column(Text); timestamp_ms: Mapped[int]=mapped_column(Integer,default=0)
    frame_index: Mapped[int]=mapped_column(Integer,default=0); width: Mapped[int]=mapped_column(Integer,default=0)
    height: Mapped[int]=mapped_column(Integer,default=0); sharpness: Mapped[float]=mapped_column(Float,default=0)
class ObjectIdentity(Base):
    __tablename__='objects'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('obj'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    canonical_label: Mapped[str]=mapped_column(String(250),index=True); category: Mapped[str]=mapped_column(String(100),default='other')
    domain: Mapped[str]=mapped_column(String(20)); identity_status: Mapped[str]=mapped_column(String(30),default='candidate')
    identifiers: Mapped[dict]=mapped_column(JSON,default=dict); attributes: Mapped[dict]=mapped_column(JSON,default=dict)
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
class Evidence(Base):
    __tablename__='evidence'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('evd'))
    capture_id: Mapped[str]=mapped_column(ForeignKey('captures.id'),index=True)
    frame_id: Mapped[str|None]=mapped_column(ForeignKey('frames.id'),nullable=True)
    media_id: Mapped[str]=mapped_column(ForeignKey('media_assets.id'))
    bbox: Mapped[list|None]=mapped_column(JSON,nullable=True); crop_path: Mapped[str|None]=mapped_column(Text,nullable=True)
    timestamp_ms: Mapped[int]=mapped_column(Integer,default=0); source_type: Mapped[str]=mapped_column(String(30),default='frame')
class Observation(Base):
    __tablename__='observations'; __table_args__=(Index('ix_obs_object_created','object_id','observed_at'),)
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('obs'))
    capture_id: Mapped[str]=mapped_column(ForeignKey('captures.id'),index=True)
    object_id: Mapped[str|None]=mapped_column(ForeignKey('objects.id'),nullable=True,index=True)
    evidence_id: Mapped[str]=mapped_column(ForeignKey('evidence.id'))
    location_id: Mapped[str|None]=mapped_column(ForeignKey('locations.id'),nullable=True)
    label: Mapped[str]=mapped_column(String(250)); location_text: Mapped[str]=mapped_column(Text,default='')
    condition_text: Mapped[str]=mapped_column(Text,default=''); attributes: Mapped[dict]=mapped_column(JSON,default=dict)
    confidence: Mapped[dict]=mapped_column(JSON,default=dict); verification_status: Mapped[str]=mapped_column(String(30),default='unverified')
    observed_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
class Relationship(Base):
    __tablename__='relationships'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('rel'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    subject_object_id: Mapped[str|None]=mapped_column(ForeignKey('objects.id'),nullable=True)
    subject_location_id: Mapped[str|None]=mapped_column(ForeignKey('locations.id'),nullable=True)
    predicate: Mapped[str]=mapped_column(String(50)); target_object_id: Mapped[str|None]=mapped_column(ForeignKey('objects.id'),nullable=True)
    target_location_id: Mapped[str|None]=mapped_column(ForeignKey('locations.id'),nullable=True)
    evidence_id: Mapped[str|None]=mapped_column(ForeignKey('evidence.id'),nullable=True)
    confidence: Mapped[float]=mapped_column(Float,default=0); valid_from: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
    valid_to: Mapped[datetime|None]=mapped_column(DateTime(timezone=True),nullable=True)
class Event(Base):
    __tablename__='events'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('evt'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    capture_id: Mapped[str|None]=mapped_column(ForeignKey('captures.id'),nullable=True)
    object_id: Mapped[str|None]=mapped_column(ForeignKey('objects.id'),nullable=True)
    event_type: Mapped[str]=mapped_column(String(50)); details: Mapped[dict]=mapped_column(JSON,default=dict)
    confidence: Mapped[float]=mapped_column(Float,default=0); evidence_ids: Mapped[list]=mapped_column(JSON,default=list)
    source: Mapped[str]=mapped_column(String(30),default='vision'); created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
class InspectionTask(Base):
    __tablename__='inspection_tasks'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('tsk'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    capture_id: Mapped[str|None]=mapped_column(ForeignKey('captures.id'),nullable=True)
    location_id: Mapped[str|None]=mapped_column(ForeignKey('locations.id'),nullable=True)
    title: Mapped[str]=mapped_column(String(250)); reason: Mapped[str]=mapped_column(Text,default='')
    status: Mapped[str]=mapped_column(String(30),default='pending'); priority: Mapped[int]=mapped_column(Integer,default=3)
class InventoryRecord(Base):
    __tablename__='inventory_records'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('inv'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    object_id: Mapped[str|None]=mapped_column(ForeignKey('objects.id'),nullable=True)
    sku: Mapped[str|None]=mapped_column(String(120),nullable=True); barcode: Mapped[str|None]=mapped_column(String(160),nullable=True)
    rfid: Mapped[str|None]=mapped_column(String(160),nullable=True); product_name: Mapped[str]=mapped_column(String(250))
    system_quantity: Mapped[int|None]=mapped_column(Integer,nullable=True); visible_count: Mapped[int|None]=mapped_column(Integer,nullable=True)
    location_id: Mapped[str|None]=mapped_column(ForeignKey('locations.id'),nullable=True); source_system: Mapped[str]=mapped_column(String(80),default='manual')
    status: Mapped[str]=mapped_column(String(30),default='unreconciled')
class SceneNote(Base):
    __tablename__='scene_notes'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('scn'))
    capture_id: Mapped[str]=mapped_column(ForeignKey('captures.id'),index=True)
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    frame_id: Mapped[str|None]=mapped_column(ForeignKey('frames.id'),nullable=True)
    evidence_id: Mapped[str|None]=mapped_column(ForeignKey('evidence.id'),nullable=True)
    text: Mapped[str]=mapped_column(Text,default='')
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
class ChatMessage(Base):
    __tablename__='chat_messages'
    __table_args__=(Index('ix_chat_user_created','workspace_id','user_id','created_at'),)
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('msg'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    user_id: Mapped[str]=mapped_column(ForeignKey('users.id'),index=True)
    role: Mapped[str]=mapped_column(String(20))
    content: Mapped[str]=mapped_column(Text)
    evidence_ids: Mapped[list]=mapped_column(JSON,default=list)
    confidence: Mapped[float]=mapped_column(Float,default=0)
    language: Mapped[str]=mapped_column(String(35),default='')
    conversation_id: Mapped[str|None]=mapped_column(String(64),nullable=True,index=True)
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)
class CareItem(Base):
    __tablename__='care_items'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('care'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    created_by: Mapped[str]=mapped_column(ForeignKey('users.id'))
    name: Mapped[str]=mapped_column(String(200)); note: Mapped[str]=mapped_column(Text,default='')
    location: Mapped[str]=mapped_column(String(200),default='')
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)

class WorkspaceDocument(Base):
    __tablename__='workspace_documents'
    id: Mapped[str]=mapped_column(String(64),primary_key=True,default=lambda:uid('doc'))
    workspace_id: Mapped[str]=mapped_column(ForeignKey('workspaces.id'),index=True)
    uploaded_by: Mapped[str]=mapped_column(ForeignKey('users.id'))
    name: Mapped[str]=mapped_column(String(255))
    description: Mapped[str]=mapped_column(Text)
    stored_path: Mapped[str]=mapped_column(Text)
    file_type: Mapped[str]=mapped_column(String(10))
    size_bytes: Mapped[int]=mapped_column(Integer)
    created_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)

class AiPrivacyConsent(Base):
    __tablename__='ai_privacy_consents'
    user_id: Mapped[str]=mapped_column(ForeignKey('users.id'),primary_key=True)
    policy_version: Mapped[str]=mapped_column(String(40))
    accepted_at: Mapped[datetime]=mapped_column(DateTime(timezone=True),default=now)


class Camera(Base):
    """Registered camera metadata. Credentials/stream URLs are deliberately not stored here."""
    __tablename__ = 'cameras'
    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=lambda: uid('cam'))
    workspace_id: Mapped[str] = mapped_column(ForeignKey('workspaces.id'), index=True)
    name: Mapped[str] = mapped_column(String(160))
    location_id: Mapped[str | None] = mapped_column(ForeignKey('locations.id'), nullable=True)
    protocol: Mapped[str] = mapped_column(String(30), default='rtsp')
    connection_ref: Mapped[str] = mapped_column(String(250), default='')
    status: Mapped[str] = mapped_column(String(30), default='configured')
    enabled: Mapped[bool] = mapped_column(default=True)
    retention_days: Mapped[int] = mapped_column(Integer, default=7)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
