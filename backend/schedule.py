from datetime import datetime
from typing import Literal
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from database import db
from google.cloud import firestore

# Initializing router keeping your exact route prefix path
router = APIRouter(
    prefix="/api/schedule",
    tags=["Schedule & Notifications"]
)

# ---------------------------------------------------------------------------
# Data Models for Request Payloads
# ---------------------------------------------------------------------------
class CreateSchedulePayload(BaseModel):
    elder_id: str = Field(..., description="The unique ID of the elder")
    title: str = Field(..., description="e.g., Take Blood Pressure Medication")
    scheduled_time: str = Field(..., alias="time", description="e.g., 08:00 AM or 14:30")
    event_type: str = Field(..., alias="type", description="Must be 'MEDICATION', 'APPOINTMENT', 'medicine', or 'checkup'")

    class Config:
        populate_by_name = True


class ConfirmSchedulePayload(BaseModel):
    elder_id: str = Field(..., description="The unique ID of the elder")
    schedule_id: str = Field(..., alias="task_id", description="The document ID of the specific task entry")

    class Config:
        populate_by_name = True


# ---------------------------------------------------------------------------
# Endpoint 1: Family Creates a Schedule (Triggers Broadcast)
# ---------------------------------------------------------------------------
@router.post("/create")
async def create_scheduled_event(payload: CreateSchedulePayload):
    """
    Family member adds an event to the elder's sub-collection. 
    The backend saves it natively and returns a broadcast notification string.
    """
    try:
        # Save to sub-collection matching your Flutter app: /elders/{elder_id}/tasks
        tasks_ref = db.collection("elders").document(payload.elder_id).collection("tasks")
        
        schedule_data = {
            "title": payload.title,
            "time": payload.scheduled_time,
            "type": payload.event_type.lower(),  # Standardized to lowercase string format for frontend icons
            "status": "PENDING",
            "createdAt": firestore.SERVER_TIMESTAMP
        }
        
        # Insert record into Firestore
        _, doc_ref = tasks_ref.add(schedule_data)
        
        # Dynamic context notification copy generation
        if payload.event_type.upper() in ["MEDICATION", "MEDICINE"]:
            notify_msg = f"Reminder: It is time to take your {payload.title}."
        else:
            notify_msg = f"Reminder: You have an upcoming {payload.title}."

        print(f"📣 [Broadcast] Sent to Elder {payload.elder_id} & Network: '{notify_msg}'")

        return {
            "status": "success",
            "schedule_id": doc_ref.id,
            "notification_text": notify_msg
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection or insertion failure: {str(e)}")


# ---------------------------------------------------------------------------
# Endpoint 2: Elder / Volunteer Confirms the Task
# ---------------------------------------------------------------------------
@router.post("/confirm")
async def confirm_scheduled_event(payload: ConfirmSchedulePayload):
    """
    Elder takes the medication or attends the appointment and clicks 'Confirm'.
    State updates instantly in place inside their sub-collection document mapping.
    """
    try:
        task_doc_ref = db.collection("elders") \
                         .document(payload.elder_id) \
                         .collection("tasks") \
                         .document(payload.schedule_id)
        
        if not task_doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Scheduled event record not found")
            
        # Transition state machine node safely
        task_doc_ref.update({
            "status": "COMPLETED",
            "isDone": True  # Backward compatibility flag safeguard if UI reads primitive booleans
        })
        
        print(f"✅ [Schedule] Event {payload.schedule_id} marked as COMPLETED.")
        return {
            "status": "success", 
            "message": "Check-in successful! The care network has been updated instantly."
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database update mutation failure: {str(e)}")


# ---------------------------------------------------------------------------
# Endpoint 3: Permanent Deletion (Parent Authority Feature Layer)
# ---------------------------------------------------------------------------
@router.delete("/delete/{elder_id}/{schedule_id}")
async def delete_scheduled_event(elder_id: str, schedule_id: str):
    """
    Allows parents to completely clean out old or incorrect items out of the sub-collection tree.
    """
    try:
        # Fixed variable name mapping below from elderly_id to elder_id
        task_doc_ref = db.collection("elders") \
                         .document(elder_id) \
                         .collection("tasks") \
                         .document(schedule_id)
                         
        if not task_doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Target schedule entry not found.")
            
        task_doc_ref.delete()
        print(f"❌ [Schedule System] Entry {schedule_id} wiped from timeline.")
        return {
            "status": "success",
            "message": "Task record removed successfully."
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database execution purge dropped: {str(e)}")


# ---------------------------------------------------------------------------
# Endpoint 4: [HACKATHON DEMO ONLY] Force Missed Alert Engine
# ---------------------------------------------------------------------------
@router.post("/trigger-missed-alert/{elder_id}/{schedule_id}")
async def trigger_missed_alert(elder_id: str, schedule_id: str):
    """
    Pitch Demo Tool: Fast-forwards temporal delays instantly.
    Simulates a critical timeout lifecycle stage changing status to MISSED.
    """
    try:
        task_doc_ref = db.collection("elders") \
                         .document(elder_id) \
                         .collection("tasks") \
                         .document(schedule_id)
        
        doc_snapshot = task_doc_ref.get()
        if not doc_snapshot.exists:
            raise HTTPException(status_code=404, detail="Target demo scheduled event index missing.")
            
        schedule_data = doc_snapshot.to_dict()
        
        # Verify execution context state rules
        if schedule_data.get("status") == "PENDING":
            task_doc_ref.update({"status": "MISSED"})
            
            alert_msg = (
                f"🚨 CRITICAL ALERT: The scheduled event '{schedule_data.get('title')}' "
                f"was missed! Family members and nearby volunteers, please follow up immediately."
            )
            print(f"⚠️ [Demo Trigger Execution] {alert_msg}")
            
            return {
                "alert_triggered": True,
                "status": "CRITICAL",
                "push_notification": alert_msg
            }
        
        return {
            "alert_triggered": False, 
            "message": "The event was already marked complete. No emergency alert required."
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Sandbox simulation execution pipeline fault: {str(e)}")