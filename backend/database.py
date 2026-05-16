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