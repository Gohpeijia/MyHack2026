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
    """
    Calculates real-world distances against multiple home bases and vanity locations,
    then leverages the LLM to provide contextual safety analysis.
    """
    api_key = os.getenv("GOOGLE_MAPS_API_KEY")
    
    # Safety fallback if no location coordinates have arrived yet
    if not location_history:
        return {
            "status": "error",
            "message": "No location coordinates provided.",
            "flag": False
        }
    
    # Safely extract arrays of locations from the elder profile dictionary
    home_locations = elder.get("home_locations", [])
    vanity_locations = elder.get("vanity_locations", [])

    # Grab the latest location ping from the tracking history array
    latest_ping = location_history[-1]
    current_lat = latest_ping.get("lat")
    current_lng = latest_ping.get("lng")
    
    calculated_distances = []

    # Loop through and compute distances to all registered home bases
    for home in home_locations:
        # Fixed: Pass arguments positionally matching (origin_lat, origin_lng, dest_lat, dest_lng, api_key)
        matrix = get_distance_matrix(current_lat, current_lng, home.get("lat"), home.get("lng"), api_key) 
        if matrix:
            calculated_distances.append({
                "target_name": home.get("name", "Home Base"),
                "type": "home_base",
                "distance_text": matrix["distance_text"],
                "distance_meters": matrix["distance_meters"],
                "duration_text": matrix["duration_text"]
            })
            
    # Loop through and compute distances to all registered vanity locations
    for venue in vanity_locations:
        # Fixed: Pass arguments positionally matching (origin_lat, origin_lng, dest_lat, dest_lng, api_key)
        matrix = get_distance_matrix(current_lat, current_lng, venue.get("lat"), venue.get("lng"), api_key)
        if matrix:
            calculated_distances.append({
                "target_name": venue.get("name", "Vanity Spot"),
                "type": "vanity_spot",
                "distance_text": matrix["distance_text"],
                "distance_meters": matrix["distance_meters"],
                "duration_text": matrix["duration_text"]
            })

    # ==========================================
    # SYSTEM PROMPT (The Rules & Context)
    # ==========================================
    system_prompt = (
        "You are a location-tracking safety assistant for an elderly care app in Malaysia. Sonnen tracking logs.\n"
        "Your job is to analyze an elder's calculated proximity to their configured safe zones "
        "and flag if they are unexpectedly missing, wandering, or out too late.\n\n"
        "Rules:\n"
        "1. If 'distance_meters' to ANY location of type 'home_base' is very small (under 150 meters), "
        "they are safe at that home. Set 'is_at_home' to true.\n"
        "2. If they are close to a 'vanity_spot' (under 150 meters), recognize it by its custom name in your final message "
        "(e.g., 'Mak Cik Rohani is safely at her Favorite Park').\n"
        "3. If they are far from ALL configured home bases and vanity spots, flag it as a 'concern' or 'alert' depending on "
        "the hour and elapsed duration, stating they are wandering in an unrecognized area.\n\n"
        "Return ONLY valid JSON with no conversational wrapper."
    )

    # ==========================================
    # USER PROMPT (The Live Calculation Data)
    # ==========================================
    user_prompt = f"""
Elder Profile Info:
{json.dumps(elder, indent=4)}

Current Tracking Ping:
{json.dumps(latest_ping, indent=4)}

Calculated Real-World Proximities:
{json.dumps(calculated_distances, indent=4)}

Analyze the calculated proximities. Determine if they are safely at one of their homes, spending time at an identified vanity destination, or wandering off limits. Use time guidelines if they are completely away from all safe zones.

Return ONLY JSON:
{{
  "status": "normal | concern | alert",
  "last_known_location": "name of closest recognized place, or name from ping if unrecognized",
  "is_at_home": true_or_false,
  "time_since_last_ping": "e.g. 20 minutes",
  "flag": true_or_false,
  "message": "Short plain English update for the family mentioning the location name specifically",
  "reason": "Explain tracking assessment if flag is true"
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

