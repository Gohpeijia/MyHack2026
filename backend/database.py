# database.py
import firebase_admin
from firebase_admin import credentials, firestore

# 1. Path to your Firebase service account JSON file (Download this from Firebase Console)
CREDENTIALS_PATH = "firebase-adminsdk.json"

try:
    # 2. initialize Firebase Admin SDK
    cred = credentials.Certificate(CREDENTIALS_PATH)
    firebase_admin.initialize_app(cred)
    
    # 3. Connect to Firestore database
    db = firestore.client()
    print("✅ Successful to connect Firebase Firestore database!")

except Exception as e:
    print(f"❌ Firebase connect failed: {e}")
    db = None  # Set db to None if connection fails, handle this in your endpoints later

# Add these to the bottom of database.py to prevent ImportErrors

def get_elder(elder_id: str) -> dict:
    # TODO: Replace with actual Firestore fetch
    return {"name": "Test Elder", "age": 75, "home_locations": []}

def get_activities(elder_id: str) -> list:
    return [{"activity": "Morning Walk", "status": "completed"}]

def get_contacts(elder_id: str) -> list:
    return [{"name": "Ali", "phone": "123456789"}]

def get_medicine(elder_id: str) -> list:
    return [{"medication": "Aspirin", "time": "08:00 AM"}]

def get_location_history(elder_id: str) -> list:
    return [{"lat": 3.1073, "lng": 101.6067, "timestamp": "10:00 AM"}]