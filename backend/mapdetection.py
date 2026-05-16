import json
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from geopy.distance import geodesic
from llm_router import call_llm
from database import db

# Initialize the router for map-related endpoints
router = APIRouter(
    prefix="/api/map",
    tags=["Map & Geofencing"]
)

# ---------------------------------------------------------------------------
# Configuration / Constants
# ---------------------------------------------------------------------------
DEFAULT_SAFE_RADIUS = 500.0  # meters
VOLUNTEER_CHECKIN_RADIUS = 50.0  # meters

# ---------------------------------------------------------------------------
# Data Models for Map Payloads (Enhanced with Validation)
# ---------------------------------------------------------------------------
class ElderLocationPayload(BaseModel):
    elder_id: str = Field(..., description="The unique ID of the elder")
    lat: float = Field(..., ge=-90, le=90, description="Latitude")
    lng: float = Field(..., ge=-180, le=180, description="Longitude")
    current_time: str = Field(..., pattern=r"^(?:[01]\d|2[0-3]):[0-5]\d$", description="Time in HH:MM format")

class VolunteerLocationPayload(BaseModel):
    volunteer_id: str
    elder_id: str
    lat: float = Field(..., ge=-90, le=90)
    lng: float = Field(..., ge=-180, le=180)

# ---------------------------------------------------------------------------
# Core Feature 1: AI-Powered Dynamic Geofence
# ---------------------------------------------------------------------------
@router.post("/elder-geofence")
async def check_elder_geofence(payload: ElderLocationPayload):
    """
    Evaluates if the elder is outside their safe zone using Firebase data 
    and triggers AI contextual analysis to prevent false alarms.
    """
    # 1. Fetch live data from Firebase Firestore safely
    try:
        doc_ref = db.collection("elders").document(payload.elder_id)
        doc = doc_ref.get() # Note: Consider await doc_ref.get() if using Async Firestore
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection error: {str(e)}")
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Elder not found in database")
    
    elder = doc.to_dict()

    # 2. Strict Coordinate Validation (Removed hardcoded defaults)
    if "home_lat" not in elder or "home_lng" not in elder:
         raise HTTPException(status_code=400, detail="Elder's home coordinates are missing from the database.")
    
    home_coords = (elder["home_lat"], elder["home_lng"]) 
    safe_radius_meters = elder.get("safe_radius_meters", DEFAULT_SAFE_RADIUS)
    elder_name = elder.get("name", "Unknown Elder")
    today_schedule = elder.get("today_schedule", "No schedule")

    # 3. Calculate physical distance locally
    current_coords = (payload.lat, payload.lng)
    distance = geodesic(home_coords, current_coords).meters

    # 4. Inside the safe zone: Return early
    if distance <= safe_radius_meters:
        return {
            "status": "SAFE",
            "distance_meters": round(distance, 2),
            "message": "Elder is within the normal activity perimeter. No action needed."
        }

    # 5. Geofence breached: Trigger AI Contextual Analysis
    system_prompt = (
        "You are the core logic engine of an AI Elderly Care System designed to prevent false alarms.\n"
        "The elderly individual has left their safe geofence. \n"
        "Based on the [Current Time] and [Today's Schedule], determine the alert level.\n\n"
        "Output STRICTLY in valid JSON format:\n"
        '{"alarm_level": "SAFE" | "WARNING" | "CRITICAL", "reason": "Your reasoning", "action": "Suggested system action"}\n\n'
        "Rules:\n"
        "- If the time aligns with a scheduled accompanied outing, alarm_level is SAFE.\n"
        "- If it is daytime and there is no schedule, alarm_level is WARNING.\n"
        "- If it is late night (after 19:00) and there is no schedule, alarm_level is CRITICAL and action must be 'trigger_emergency'."
    )

    user_prompt = (
        f"Elder Name: {elder_name}\n"
        f"Distance from Home: {int(distance)} meters\n"
        f"Current Time: {payload.current_time}\n"
        f"Today's Schedule: {today_schedule}"
    )

    print(f"[Map System] Abnormal movement detected for {payload.elder_id}. Calling LLM...")
    
    # 6. Call LLM and handle potential parsing errors
    try:
        # Assuming call_llm is synchronous. If it's async, add 'await'
        ai_decision_raw = call_llm(system_prompt, user_prompt, temperature=0.1)
        
        # Clean up string just in case LLM adds markdown formatting like ```json
        clean_json_str = ai_decision_raw.replace("```json", "").replace("```", "").strip()
        ai_decision_json = json.loads(clean_json_str)
    except json.JSONDecodeError:
        print(f"⚠️ [Map System] LLM Output parsing failed. Raw output: {ai_decision_raw}")
        # Fallback safeguard
        ai_decision_json = {
            "alarm_level": "WARNING", 
            "reason": "AI context engine failed to parse response. Defaulting to warning for safety.", 
            "action": "manual_review_required"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI Engine failure: {str(e)}")

    return {
        "status": "EVALUATED_BY_AI",
        "distance_meters": round(distance, 2),
        "ai_analysis": ai_decision_json 
    }

# ---------------------------------------------------------------------------
# Core Feature 2: Volunteer "Last-Mile" Auto Check-In
# ---------------------------------------------------------------------------
@router.post("/volunteer-checkin")
async def auto_checkin_volunteer(payload: VolunteerLocationPayload):
    """
    Calculates distance between the volunteer and the elder's home for seamless check-in.
    """
    try:
        doc_ref = db.collection("elders").document(payload.elder_id)
        doc = doc_ref.get()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection error: {str(e)}")

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Elder not found in database")

    elder = doc.to_dict()
    
    # Strict Coordinate Validation
    if "home_lat" not in elder or "home_lng" not in elder:
         raise HTTPException(status_code=400, detail="Elder's home coordinates are missing.")
         
    home_coords = (elder["home_lat"], elder["home_lng"])
    volunteer_coords = (payload.lat, payload.lng)
    
    distance_to_elder = geodesic(volunteer_coords, home_coords).meters

    if distance_to_elder <= VOLUNTEER_CHECKIN_RADIUS:
        try:
            task_ref = db.collection("tasks").document(f"{payload.volunteer_id}_{payload.elder_id}")
            task_ref.set({"status": "ARRIVED", "distance_logged": distance_to_elder}, merge=True)
            print(f"✅ [Map System] Volunteer {payload.volunteer_id} checked in at DB.")
        except Exception as e:
            print(f"⚠️ Could not write to DB, but check-in logic passed: {e}")
            # Don't fail the request if the DB write fails, but log it

        return {
            "checkin_status": "SUCCESS",
            "distance_meters": round(distance_to_elder, 2),
            "message": "Auto check-in successful. Please submit the voice care log within 10 minutes."
        }
    else:
        return {
            "checkin_status": "PENDING",
            "distance_meters": round(distance_to_elder, 2),
            "message": f"Approaching destination. {int(distance_to_elder)} meters remaining."
        }