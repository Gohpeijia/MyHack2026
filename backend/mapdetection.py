# mapdetect.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from geopy.distance import geodesic
from llm_router import call_llm
from database import db

# Initialize the router for map-related endpoints
router = APIRouter(
    prefix="/api/map",
    tags=["Map & Geofencing"]
)

# ---------------------------------------------------------------------------
# Data Models for Map Payloads
# ---------------------------------------------------------------------------
class ElderLocationPayload(BaseModel):
    elder_id: str
    lat: float
    lng: float
    current_time: str  # Example: "15:30" or "21:00"

class VolunteerLocationPayload(BaseModel):
    volunteer_id: str
    elder_id: str
    lat: float
    lng: float

# ---------------------------------------------------------------------------
# Core Feature 1: AI-Powered Dynamic Geofence (Firebase Integrated)
# ---------------------------------------------------------------------------
@router.post("/elder-geofence")
async def check_elder_geofence(payload: ElderLocationPayload):
    """
    Evaluates if the elder is outside their safe zone using Firebase data 
    and triggers AI contextual analysis to prevent false alarms.
    """
    # 1. Fetch live data from Firebase Firestore
    try:
        doc_ref = db.collection("elders").document(payload.elder_id)
        doc = doc_ref.get()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection error: {str(e)}")
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Elder not found in database")
    
    elder = doc.to_dict()

    # 2. Extract variables safely (with fallbacks just in case data is missing)
    # Defaulting to Subang Jaya coordinates if not found
    home_coords = (elder.get("home_lat", 3.0673), elder.get("home_lng", 101.6035)) 
    safe_radius_meters = elder.get("safe_radius_meters", 500)
    elder_name = elder.get("name", "Unknown Elder")
    today_schedule = elder.get("today_schedule", "No schedule")

    # 3. Calculate physical distance locally
    current_coords = (payload.lat, payload.lng)
    distance = geodesic(home_coords, current_coords).meters

    # 4. Inside the safe zone: Return early, no AI computation needed
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
        "Output strictly in JSON format:\n"
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
    
    # Call your LLM Router with a low temperature (0.1) for strict logical output
    ai_decision_json = call_llm(system_prompt, user_prompt, temperature=0.1)

    return {
        "status": "EVALUATED_BY_AI",
        "distance_meters": round(distance, 2),
        "ai_analysis": ai_decision_json 
    }

# ---------------------------------------------------------------------------
# Core Feature 2: Volunteer "Last-Mile" Auto Check-In (Firebase Integrated)
# ---------------------------------------------------------------------------
@router.post("/volunteer-checkin")
async def auto_checkin_volunteer(payload: VolunteerLocationPayload):
    """
    Calculates distance between the volunteer and the elder's home for seamless check-in.
    """
    # Fetch elder's home coordinates from Firebase
    try:
        doc_ref = db.collection("elders").document(payload.elder_id)
        doc = doc_ref.get()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection error: {str(e)}")

    if not doc.exists:
        raise HTTPException(status_code=404, detail="Elder not found in database")

    elder = doc.to_dict()
    home_coords = (elder.get("home_lat", 3.0673), elder.get("home_lng", 101.6035))
    volunteer_coords = (payload.lat, payload.lng)
    
    # Calculate distance
    distance_to_elder = geodesic(volunteer_coords, home_coords).meters

    # Threshold: Volunteer enters the 50-meter radius
    if distance_to_elder <= 50.0:
        # Update the volunteer's task status in Firebase
        try:
            task_ref = db.collection("tasks").document(f"{payload.volunteer_id}_{payload.elder_id}")
            task_ref.set({"status": "ARRIVED", "distance_logged": distance_to_elder}, merge=True)
            print(f"✅ [Map System] Volunteer {payload.volunteer_id} checked in at DB.")
        except Exception as e:
            print(f"⚠️ Could not write to DB, but check-in logic passed: {e}")

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