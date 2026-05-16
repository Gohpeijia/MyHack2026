from llm_router import call_llm
import json 
def _parse(text: str) -> dict: 
    text = text.strip()# Removes any additional spacing 
    if text.startswith("```"):
        text = text.split("```")[1] 
        if text.startswith("json"): # removes any formatting from the AI's Response 
            text = text[4:]
    return json.loads(text.strip())# adds the cleaned text into a python dictionary
    
def check_for_alerts(elder: dict, activities: list) -> dict: 
    system_prompt = "You are a wellbeing monitor for elderly Malaysians. Return only valid JSON." # tells the AI it's role
    user_prompt = f"""
Elder: {json.dumps(elder, indent =4)} 
Today's activities: {json.dumps(activities, indent =4)} # same information passing but for the activities

Raise a flag for any skipped or unchecked activities. 
Return ONLY JSON: 

{{
"alerts": [
{{ 
    "Activity" : "..." ,
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
Elder: {json.dumps(elder, indent =4)}
Available Contacts: {json.dumps(contacts, indent =4)}
Reason: {reason}

Pick the best contact to follow up 
Return ONLY JSON: 
{{
    "Contact_ID": "...",
    "Suggest Course of Action": "...",
    "Reasoning for Decision": "..." 
}}
"""
    response = call_llm(system_prompt, user_prompt)
    return _parse(response)


def find_replacement(elder: dict, cancelled_contact: dict, available_contacts: list) -> dict:
    system_prompt = (
        "You are a care scheduler for elderly Malaysians. "
        "Return only valid JSON, no extra text."
    )

    user_prompt = f"""
Elder profile:
{json.dumps(elder, indent=4)}

Cancelled caregiver:
{json.dumps(cancelled_contact, indent=4)}

Available replacements:
{json.dumps(available_contacts, indent=4)}

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
{json.dumps(elder, indent=4)}

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
  "notify_family": "true or false",
  "family_message": "Short update to send to family"
}}
"""
    response = call_llm(system_prompt, user_prompt, temperature=0.2)
    return _parse(response)

def check_location(elder: dict, location_history: list) -> dict:
    system_prompt = (
        "You are a location monitor for elderly Malaysians. "
        "Return only valid JSON, no extra text."
    )

    user_prompt = f"""
Elder profile:
{json.dumps(elder, indent=4)}

The elder's home address is: {elder.get("location", "unknown")}

Location pings (sent every 30 minutes, includes timestamp and place):
{json.dumps(location_history, indent=4)}

Your job:
1. If the elder is at home — only flag if there has been ZERO movement or check-in for over 4 hours.
2. If the elder is outside — use the time of day to judge how long is too long:
   - Early morning (5am-7am): likely prayer or walk, allow up to 2 hours before flagging
   - Daytime (8am-5pm): normal activity, allow up to 3 hours before flagging
   - Evening (5pm-9pm): likely leisure, allow up to 2 hours before flagging
   - Night (9pm onwards): flag immediately if outside home
3. If the elder is somewhere unexpected or very far from home, flag it regardless of time.

Return ONLY JSON:
{{
  "status": "normal | concern | alert",
  "last_known_location": "place name from most recent ping",
  "is_at_home": "true or false",
  "time_since_last_ping": "e.g. 30 minutes",
  "flag": "true or false",
  "message": "Short plain English update for the family",
  "reason": "Only fill this if flag is true, explain why"
}}
"""
    response = call_llm(system_prompt, user_prompt, temperature=0.2)
    return _parse(response)

def format_daily_schedule(elder: dict, activities: list, medicine_times: list) -> dict:
    system_prompt = (
        "You are a care dashboard assistant for elderly Malaysians. "
        "Return only valid JSON, no extra text."
    )

    user_prompt = f"""
Elder profile:
{json.dumps(elder, indent=4)}

Today's activities:
{json.dumps(activities, indent=4)}

Medicine intake schedule:
{json.dumps(medicine_times, indent=4)}

Combine and sort everything by time into one clean daily schedule.
Do NOT raise any alerts or flags.
Simply display what is scheduled, what is done, and what is upcoming.

Return ONLY JSON:
{{
  "elder_name": "...",
  "schedule": [
    {{
      "time": "08:00",
      "type": "activity | medicine",
      "description": "...",
      "status": "done | upcoming"
    }}
  ]
}}
"""
    response = call_llm(system_prompt, user_prompt, temperature=0.2)
    return _parse(response)

