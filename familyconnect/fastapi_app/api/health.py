from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from asgiref.sync import sync_to_async

from health.models import HealthMetric
from users.models import CustomUser

router = APIRouter()

class HealthMetricCreate(BaseModel):
    user_id: int
    metric_type: str
    value: float
    unit: Optional[str] = None

class HealthMetricResponse(HealthMetricCreate):
    id: int
    recorded_at: str

@sync_to_async
def create_health_metric(data: HealthMetricCreate):
    try:
        user = CustomUser.objects.get(id=data.user_id)
        metric = HealthMetric.objects.create(
            user=user,
            metric_type=data.metric_type,
            value=data.value,
            unit=data.unit
        )
        return metric
    except CustomUser.DoesNotExist:
        return None

@router.post("/health/metrics/", response_model=HealthMetricResponse)
async def add_health_metric(metric: HealthMetricCreate):
    """
    High-performance endpoint to ingest health data from wearables or mobile app.
    """
    new_metric = await create_health_metric(metric)
    if not new_metric:
        raise HTTPException(status_code=404, detail="User not found")
        
    return {
        "id": new_metric.id,
        "user_id": new_metric.user_id,
        "metric_type": new_metric.metric_type,
        "value": new_metric.value,
        "unit": new_metric.unit,
        "recorded_at": new_metric.recorded_at.isoformat()
    }
