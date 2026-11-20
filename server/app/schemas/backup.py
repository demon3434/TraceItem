from datetime import datetime
from pydantic import BaseModel, Field


class BackupRecordOut(BaseModel):
    id: int
    filename: str
    file_size: int
    file_size_display: str = ""
    sha256: str
    item_count: int
    attachment_count: int
    created_at: datetime

    class Config:
        from_attributes = True


class BackupPruneRequest(BaseModel):
    keep_latest: int = Field(5, ge=1, le=50, description="保留最新的 N 份备份")

