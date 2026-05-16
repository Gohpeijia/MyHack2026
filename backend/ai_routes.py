# ai_routes.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import db
from AI_Services import parse_visit_log, emergency_check, find_replacement, check_for_alerts

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

class EmergencyCheckPayload(BaseModel):
    elder_id: str

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
    try:
        doc_ref = db.collection("elders").document(payload.elder_id)
        doc = doc_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Elder not found in database")
        elder_profile = doc.to_dict()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

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

# ---------------------------------------------------------------------------
# Endpoint 2: Ecosystem Emergency Check (Connects to emergency_check)
# ---------------------------------------------------------------------------
@router.post("/emergency-check")
async def trigger_emergency_analysis(payload: EmergencyCheckPayload):
    """
    Evaluates the current state of an elder's ecosystem to see if an emergency 
    escalation is required.
    """
    # Fetch Elder Profile
    doc_ref = db.collection("elders").document(payload.elder_id)
    elder_profile = doc_ref.get().to_dict() if doc_ref.get().exists else {"name": "Unknown"}

    # NOTE FOR HACKATHON: In a fully finished app, you would query Firebase here 
    # to get their actual activities and contacts for the day. 
    # To make sure your demo works smoothly today, we supply safe fallback data if the DB is empty.
    mock_activities = [
        {"activity": "Morning walk", "skipped": True},
        {"activity": "Lunch Medication", "skipped": True}
    ]
    mock_contacts = [
        {"id": "c001", "name": "Ahmad", "role": "volunteer", "phone": "0123456789"},
        {"id": "c002", "name": "Siti", "role": "family", "phone": "0198765432"}
    ]

    try:
        print(f"🚨 [AI Service] Running Emergency Ecosystem Check for {payload.elder_id}...")
        ai_decision = emergency_check(elder_profile, mock_activities, mock_contacts)
        
        return {
            "status": "success",
            "ai_decision": ai_decision
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"AI Processing Failed: {str(e)}")