# ai_routes.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import get_elder, get_activities, get_contacts, get_medicine, get_location_history
from AI_Services import parse_visit_log, find_replacement, check_for_alerts, suggest_contact, check_location, format_daily_schedule

router = APIRouter(
    prefix="/api/ai",
    tags=["AI Intelligence Capabilities"]
)

# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------
class VoiceLogPayload(BaseModel):
    elder_id: str
    raw_text: str
    
# ---------------------------------------------------------------------------
# Endpoint 1: Voice Log Parser (Connects to parse_visit_log)
# ---------------------------------------------------------------------------
@router.post("/voice-log")
async def process_voice_log(payload: VoiceLogPayload):
    """
    Takes raw voice text from a caregiver, fetches the elder's profile from Firebase,
    and uses AI to extract structured health data and tasks.
    """
    # 1. Fetch Elder Profile from Firebase
    elder_profile = get_elder(payload.elder_id)
    if not elder_profile:
        raise HTTPException(status_code=404, detail="Elder not found")

    # 2. Pass the text and profile to your AI Service
    try:
        print(f"🎙️ [AI Service] Analyzing voice log for {payload.elder_id}...")
        ai_analysis = parse_visit_log(payload.raw_text, elder_profile)
        
        # 3. Return the smart JSON to the Flutter frontend
        return {
            "status": "success",
            "elder_id": payload.elder_id,
            "ai_insights": ai_analysis
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI Processing Failed: {str(e)}")

@router.get("/alerts/{elder_id}")
async def alerts(elder_id: str):
    elder = get_elder(elder_id)
    activities = get_activities(elder_id)
    medicine = get_medicine(elder_id)
    return check_for_alerts(elder, activities, medicine)

@router.get("/schedule/{elder_id}")
async def schedule(elder_id: str):
    elder = get_elder(elder_id)
    activities = get_activities(elder_id)
    medicine = get_medicine(elder_id)
    return format_daily_schedule(elder, activities, medicine)

<<<<<<< HEAD
@router.get("/location/{elder_id}")
async def location(elder_id: str):
    elder = get_elder(elder_id)
    history = get_location_history(elder_id)
    return check_location(elder, history)

class SuggestPayload(BaseModel):
    elder_id: str
    reason: str

@router.post("/suggest")
async def suggest(payload: SuggestPayload):
    elder = get_elder(payload.elder_id)
    contacts = get_contacts(payload.elder_id)
    return suggest_contact(elder, contacts, payload.reason)

class ReplacementPayload(BaseModel):
    elder_id: str
    cancelled_contact: dict
    available_contacts: list

@router.post("/replacement")
async def replacement(payload: ReplacementPayload):
    elder = get_elder(payload.elder_id)
    return find_replacement(elder, payload.cancelled_contact, payload.available_contacts)
=======
    try:
        print(f"🚨 [AI Service] Running Emergency Ecosystem Check for {payload.elder_id}...")
        ai_decision = emergency_check(elder_profile, mock_activities, mock_contacts)
        
        return {
            "status": "success",
            "ai_decision": ai_decision
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI Processing Failed: {str(e)}")
    




    
>>>>>>> 64327b71642b412a9de3e0e85c4e104414d16986
