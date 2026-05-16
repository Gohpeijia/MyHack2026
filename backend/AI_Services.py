from llm_router import call_llm
import json 
def _parse(text: str) -> dict:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())
    
def check_for_alerts(elder: dict, activities: list) -> dict: 
    system_prompt = "You are a wellbeing monitor for elderly Malaysians. Return only valid JSON." 
    user_prompt = f"""
Elder: {json.dumps(elder, indent =2)}
Today's activities: {json.dumps(activities, indent =2)}

Raise a flag for any skipped or unchecked activities. 
Return ONLY JSON: 

{{
"alerts": [
{{ 
    "Activity" : "..." 
    "Severity of Incident" : "Low | Medium | High",
    "Family Message" : "Short Friendly Warning Message for the Family"   
}}]
}} 
"""

    response = call_llm(system_prompt, user_prompt)
    return _parse(response)

def suggest_contact(elder:dict, contacts: list, reason: str) -> dict: 
    system_prompt = "You are a care coordinator for elderly Malaysians. Return only valid JSON." 
    user_prompt = f"""
Elder: {json.dumps(elder, indent =2)}
Available Contacts: {json.dumps(contacts, indent =2)}
Reason :" {reason}"

Pick the best contact to follow up 
Return ONLY JSON: 
{{
    "Contact_ID": "..."
    "Suggest Course of Action": "...",
    "Reasoning for Decision": "..." 
}}
"""
    response = call_llm(system_prompt, user_prompt)
    return _parse(response)

def emergency_check(elder: dict, activities: list, contacts: list) -> dict:
    system_prompt = "You are an emergency monitor for elderly Malaysians. Return only valid JSON."
    
    user_prompt = f"""
Elder: {json.dumps(elder, indent=2)}
Today's Activities: {json.dumps(activities, indent=2)}
Emergency Contacts: {json.dumps(contacts, indent=2)}

If 2 or more activities are missed, escalate to emergency.
Return ONLY JSON:
{{
  "escalate": true,
  "missed_count": 0,
  "severity": "low | medium | high | emergency",
  "message": "...",
  "recommended_contact": {{
    "contact_id": "...",
    "action": "Call immediately"
  }}
}}
"""
    response = call_llm(system_prompt, user_prompt)
    return json.loads(response)

def find_replacement(elder: dict, cancelled_contact: dict, available_contacts: list) -> dict:
    system_prompt = (
        "You are a care scheduler for elderly Malaysians. "
        "Return only valid JSON, no extra text."
    )

    user_prompt = f"""
Elder profile:
{json.dumps(elder, indent=2)}

Cancelled caregiver:
{json.dumps(cancelled_contact, indent=2)}

Available replacements:
{json.dumps(available_contacts, indent=2)}

Find the best 2 replacements who can cover the cancelled slot.
Match based on language, availability, and responsibilities.

Return ONLY JSON:
{{
  "gap_detected": true,
  "recommendations": [
    {{
      "contact_id": "...",
      "reason": "..."
    }}
  ]
}}
"""
    response = call_llm(system_prompt, user_prompt, temperature=0.2)
    return _parse(response)

def parse_visit_log(transcript: str, elder: dict) -> dict:
    system_prompt = (
        "You are a care record assistant for elderly Malaysians. "
        "Extract structured information from a caregiver's voice note. "
        "Return only valid JSON, no extra text."
    )

    user_prompt = f"""
Elder profile:
{json.dumps(elder, indent=2)}

Caregiver's spoken note (transcribed):
\"{transcript}\"

Extract all relevant information and structure it.

Return ONLY JSON:
{{
  "visit_summary": "One sentence summary",
  "mood": "good | neutral | low",
  "health_flags": [
    {{
      "issue": "e.g. knee pain",
      "severity": "low | medium | high",
      "action_needed": "e.g. add to doctor visit checklist"
    }}
  ],
  "tasks_confirmed": [
    {{
      "task": "e.g. blood pressure medication",
      "status": "completed"
    }}
  ],
  "notify_family": true or false,
  "family_message": "Short update to send to family"
}}
"""
    response = call_llm(system_prompt, user_prompt, temperature=0.2)
    return _parse(response)