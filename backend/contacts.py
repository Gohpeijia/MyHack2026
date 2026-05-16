from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from database import db
import uuid

router = APIRouter(
    prefix="/api/contacts",
    tags=["Emergency Contacts"]
)

# ---------------------------------------------------------------------------
# Data Models
# ---------------------------------------------------------------------------
class AddContactPayload(BaseModel):
    elder_id: str
    name: str          # e.g., "Dr. Sarah" or "Ali"
    phone: str         # e.g., "+60 12-345 6789"
    relation: str      # e.g., "Doctor", "Son", "Neighbor"

# ---------------------------------------------------------------------------
# Endpoint 1: Add Emergency Contact
# ---------------------------------------------------------------------------
@router.post("/add")
async def add_emergency_contact(payload: AddContactPayload):
    """
    Receives contact information from the frontend and stores it in 
    the elder's specific 'contacts' subcollection in Firebase.
    """
    try:
        # Verify the elder exists in the main database
        elder_ref = db.collection("elders").document(payload.elder_id)
        if not elder_ref.get().exists:
            raise HTTPException(status_code=404, detail="Elder not found in database")

        # Generate a unique contact ID
        contact_id = str(uuid.uuid4())
        
        contact_data = {
            "contact_id": contact_id,
            "name": payload.name,
            "phone": payload.phone,
            "relation": payload.relation
        }

        # Save to the subcollection: elders/{elder_id}/contacts/{contact_id}
        elder_ref.collection("contacts").document(contact_id).set(contact_data)

        print(f"📞 [Contacts] Successfully added emergency contact {payload.name} for {payload.elder_id}")
        return {
            "status": "success", 
            "message": "Emergency contact added successfully.", 
            "data": contact_data
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")

# ---------------------------------------------------------------------------
# Endpoint 2: Get All Emergency Contacts
# ---------------------------------------------------------------------------
@router.get("/list/{elder_id}")
async def get_emergency_contacts(elder_id: str):
    """
    Returns a list of all emergency contacts for a specific elder.
    Called by the Flutter app when loading the Contacts page.
    """
    try:
        # Fetch all documents inside the elder's contacts subcollection
        contacts_ref = db.collection("elders").document(elder_id).collection("contacts")
        docs = contacts_ref.stream()

        contact_list = []
        for doc in docs:
            contact_list.append(doc.to_dict())

        return {
            "status": "success", 
            "elder_id": elder_id, 
            "contacts": contact_list
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")