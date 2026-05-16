# schedule.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import db
from datetime import datetime

router = APIRouter(
    prefix="/api/schedule",
    tags=["Schedule & Notifications"]
)

# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------
class CreateSchedulePayload(BaseModel):
    elder_id: str
    title: str
    event_type: str  # e.g., "MEDICATION" or "APPOINTMENT"
    scheduled_time: str  # e.g., "14:00"

class ConfirmSchedulePayload(BaseModel):
    schedule_id: str
    elder_id: str

# ---------------------------------------------------------------------------
# Endpoint 1: Family Creates a Schedule (Triggers Broadcast)
# ---------------------------------------------------------------------------
@router.post("/create")
async def create_scheduled_event(payload: CreateSchedulePayload):
    """
    Family member adds an event to the calendar. 
    The backend saves it and generates a broadcast notification.
    """
    
    # 1. Save to Firebase Firestore
    schedule_data = {
        "elder_id": payload.elder_id,
        "title": payload.title,
        "type": payload.event_type,
        "scheduled_time": payload.scheduled_time,
        "status": "PENDING",
        "created_at": datetime.now().isoformat()
    }
    
    try:
        new_schedule_ref = db.collection("schedules").document()
        new_schedule_ref.set(schedule_data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    
    # 2. Generate clean notification text for the UI
    if payload.event_type == "MEDICATION":
        notify_msg = f"Reminder: It is time to take your {payload.title}."
    else:
        notify_msg = f"Reminder: You have an upcoming {payload.title}."

    # In a real app, you would use Firebase Cloud Messaging (FCM) here.
    # For the hackathon, we return this string to the frontend to trigger a local popup.
    print(f"📣 [Broadcast] Sent to Elder & Network: '{notify_msg}'")

    return {
        "status": "success",
        "schedule_id": new_schedule_ref.id,
        "notification_text": notify_msg
    }

# ---------------------------------------------------------------------------
# Endpoint 2: Elder / Volunteer Confirms the Task
# ---------------------------------------------------------------------------
@router.post("/confirm")
async def confirm_scheduled_event(payload: ConfirmSchedulePayload):
    """
    Elder takes the medication or attends the appointment and clicks 'Confirm'.
    """
    schedule_ref = db.collection("schedules").document(payload.schedule_id)
    doc = schedule_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Scheduled event not found")
        
    # Update status to COMPLETED
    schedule_ref.update({"status": "COMPLETED"})
    
    print(f"✅ [Schedule] Event {payload.schedule_id} marked as COMPLETED.")
    
    return {
        "status": "success", 
        "message": "Check-in successful! The care network has been updated."
    }

# ---------------------------------------------------------------------------
# Endpoint 3: [HACKATHON DEMO ONLY] Force Missed Alert
# ---------------------------------------------------------------------------
@router.post("/trigger-missed-alert/{schedule_id}")
async def trigger_missed_alert(schedule_id: str):
    """
    Pitch Demo tool: We cannot wait 2 hours during a presentation to show a missed alert.
    Call this endpoint to instantly simulate a time-out scenario and trigger the AI warning.
    """
    schedule_ref = db.collection("schedules").document(schedule_id)
    doc = schedule_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Scheduled event not found")
        
    schedule_data = doc.to_dict()
    
    # Check if the status is still PENDING (meaning they missed it)
    if schedule_data.get("status") == "PENDING":
        # 1. Change status to MISSED
        schedule_ref.update({"status": "MISSED"})
        
        # 2. Trigger the Red Alert to the Network
        alert_msg = (
            f"🚨 CRITICAL ALERT: The scheduled event '{schedule_data['title']}' "
            f"was missed! Family members and nearby volunteers, please follow up immediately."
        )
        print(alert_msg)
        
        return {
            "alert_triggered": True,
            "status": "CRITICAL",
            "push_notification": alert_msg
        }
    
    return {
        "alert_triggered": False, 
        "message": "The event was already completed. No alarm needed."
    }