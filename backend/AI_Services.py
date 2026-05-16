from llm_router import call_llm
import json 
import requests
import os
import re
from dotenv import load_dotenv

load_dotenv()  # Load environment variables from .env file

def get_distance_matrix(origin_lat, origin_lng, dest_lat, dest_lng, api_key):
    """
    Calculates real-world distance and travel time using Google Maps API.
    """
    url = "https://maps.googleapis.com/maps/api/distancematrix/json"
    params = {
        "origins": f"{origin_lat},{origin_lng}",
        "destinations": f"{dest_lat},{dest_lng}",
        "mode": "walking",  # Can change to 'driving' if needed
        "key": api_key
    }
    try:
        response = requests.get(url, params=params).json()
        if response.get("status") == "OK":
            element = response["rows"][0]["elements"][0]
            if element.get("status") == "OK":
                return {
                    "distance_text": element["distance"]["text"],       # e.g., "4.2 km"
                    "distance_meters": element["distance"]["value"],    # e.g., 4200
                    "duration_text": element["duration"]["text"]        # e.g., "52 mins"
                }
    except Exception as e:
        print(f"Google Maps API Error: {e}")
    return None

def _parse(text: str) -> dict: 
    text = text.strip()
    
    
    match = re.search(r'\{.*\}', text, re.DOTALL)
    if match:
        text = match.group(0)
            
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return {
            "status": "error",
            "message": "Failed to parse system payload response.",
            "flag": True
        }
    
def check_for_alerts(elder: dict, activities: list) -> dict: 
    system_prompt = "You are a wellbeing monitor for elderly Malaysians. Return only valid JSON." # tells the AI it's role
    user_prompt = f"""
Elder: {json.dumps(elder, indent =4)} 
Today's activities: {json.dumps(activities, indent =4)} 

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
  "notify_family": "true_or_false",
  "family_message": "Short update to send to family"
}}
"""
    response = call_llm(system_prompt, user_prompt, temperature=0.2)
    return _parse(response)

def check_location(elder: dict, location_history: list) -> dict:
    system_prompt = (
        "You are a location monitor for elderly Malaysians. "
        "Return only valid JSON, no extra text. "
        "Example Output Format:\n"
        "{\n"
        "  \"status\": \"normal\",\n"
        "  \"last_known_location\": \"Taman Jaya Park\",\n"
        "  \"is_at_home\": \"false\",\n"
        "  \"time_since_last_ping\": \"30 minutes\",\n"
        "  \"flag\": \"false\",\n"
        "  \"message\": \"Elder is taking a normal walk nearby.\",\n"
        "  \"reason\": \"\"\n"
        "}"
    )

    # Secure your list slicing safely:
    if not location_history:
        return {
            "status": "error",
            "message": "No location coordinates provided.",
            "flag": False
        }
    
    latest_ping = location_history[-1]

    # 1. Get the latest ping coordinate from history
    latest_ping = location_history[-1] if location_history else {}
    current_lat = latest_ping.get("lat")
    current_lng = latest_ping.get("lng")
    
    # 2. Get home coordinates (assuming you add 'home_lat'/'home_lng' to your elder profile)
    home_lat = elder.get("home_lat", 3.1073) 
    home_lng = elder.get("home_lng", 101.6067)
    
    # 3. Call Google Maps API to get the real distance
    GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
    
    if not GOOGLE_MAPS_API_KEY:
        return {
            "status": "error",
            "message": "Google Maps API Key is missing from environment.",
            "flag": False
        }
    
    geo_data = get_distance_matrix(home_lat, home_lng, current_lat, current_lng, GOOGLE_MAPS_API_KEY)   
    
    # 4. Supply the clear-cut distance calculations straight to the AI prompt
    distance_info = "Unknown"
    if geo_data:
        distance_info = f"{geo_data['distance_text']} away ({geo_data['duration_text']} walk from home)"

    user_prompt = f"""
Elder profile:
{json.dumps(elder, indent=4)}

The elder's home address is: {elder.get("location", "unknown")}
Calculated distance from home for the latest ping: {distance_info}

Location pings (sent every 30 minutes, includes timestamp and place):
{json.dumps(location_history, indent=4)}

Your job:
1. If the elder is at home — only flag if there has been ZERO movement or check-in for over 4 hours.
2. If the elder is outside — use the time of day to judge how long is too long:
   - Early morning (5am-7am): likely prayer or walk, allow up to 2 hours before flagging
   - Daytime (8am-5pm): normal activity, allow up to 3 hours before flagging
   - Evening (5pm-9pm): likely leisure, allow up to 2 hours before flagging
   - Night (9pm onwards): flag immediately if outside home
3. If the calculated distance shows the elder is very far from home (e.g., more than 5-10 km away), flag it regardless of time.

Return ONLY JSON:
{{
  "status": "normal | concern | alert",
  "last_known_location": "place name from most recent ping",
  "is_at_home": "true_or_false",
  "time_since_last_ping": "e.g. 30 minutes",
  "flag": "true",
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

