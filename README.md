# Find my Ah ma 

**An AI-powered Elderly Care Relationship Operating System**

> Bridging families, caregivers, and the elderly — so no one gets left behind.

---

## What is  Find my Ah ma ?

 Track my Amar is a mobile app that helps families stay connected to their elderly loved ones. It combines a live location tracker, smart reminders, emergency contacts, and an AI alert engine into one simple interface — built for both caregivers and the elderly.

Think of it as a care operating system: one place to manage the people, schedules, and alerts that keep an elder safe.

---

## Who Is It For?

| Role | What they do in the app |
|---|---|
| **Grandparent (Elder)** | Receives reminders, shares live location, marks tasks done |
| **Parent / Caregiver** | Monitors the elder, manages schedules, gets AI alerts |
| **Family / Volunteers** | Added to the care network, notified in emergencies |

---

## 🔄 User Flow Architecture

Below is the role selection and authentication flow for connecting an Elderly user with a Caregiver via a QR code session.

```text
[Role Selection]
    |
    ├── Elderly ───→ [ElderlyQRPage]
    |                  | creates sessions/{id} = { status: 'waiting' } in Firebase
    |                  | shows QR encoding the session ID
    |                  | 👂 listens to sessions/{id}/status...
    |
    └── Caregiver ─→ [CaregiverScanPage]
                       | scans QR → reads session ID
                       |
                       ▼
                     [LoginScreen]  ← receives sessionId as argument
                       | sign up (saved once to caregivers/{uid})
                       | OR sign in (existing account)
                       | → updates sessions/{id} = { status: 'connected', caregiverEmail }
                       |
                ┌──────┴──────┐
                ▼             ▼
        Caregiver goes to    Elderly listener fires
        /home immediately    → navigates to /home
```

---

## Key Features

- 📍 **Live Map Tracking** — Elder's position updated every 5 minutes
- 🚨 **Emergency Contacts** — One-tap SOS with auto-notify to the care network
- 👥 **Dual User Mode** — Separate views for elder and caregiver
- 📋 **Dashboard** — Missed activities + Monthly activities presented in calender
- 🧠 **AI Suggestions** — Gemini proactively tells caregivers what needs attention

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| AI / Alerts | Google Gemini API |
| Maps & Location | Google Maps Flutter |
| Backend | Pthon Fast Api |
| Database | Firebase |

---

## 🛠️ Prerequisites

Before you begin, ensure you have the following installed:
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (for the mobile app)
* [Python 3.9+](https://www.python.org/downloads/) (for the backend server)
* A Firebase Project with Firestore enabled.

---

## ⚙️ Backend Setup (FastAPI)

The backend powers the AI ecosystem, location tracking, and schedule broadcasts. 

### 1. Environment Setup
Open your terminal, navigate to the `backend` folder, and create a fresh Python virtual environment:

**Windows:**
```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate
## 🛠️ Backend Setup (Python / FastAPI)

### 1. Create & Activate Virtual Environment

**Mac/Linux:**
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
```

**Windows:**
```bash
cd backend
python -m venv venv
venv\Scripts\activate
```

### 2. Install Dependencies

Install the required Python packages:

```bash
pip install fastapi uvicorn firebase-admin pydantic slowapi geopy requests python-dotenv
```

### 3. API Keys & Firebase Credentials

1. **Firebase:** Download your `firebase-adminsdk.json` file from your Firebase Console *(Project Settings > Service Accounts)* and place it directly inside the `backend/` folder.

2. **Environment Variables:** Create a `.env` file in the `backend/` folder and add your LLM routing keys:

```env
GROQ_API_KEY=your_groq_key_here
OPENROUTER_API_KEY=your_openrouter_key_here
CEREBRAS_API_KEY=your_cerebras_key_here
GEMINI_API_KEY=your_gemini_key_here
GOOGLE_MAPS_API_KEY=your_google_maps_key_here
```

### 4. Run the Server

Start the Uvicorn server on all network interfaces so your mobile device can reach it:

```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

You can verify it is running by opening `http://localhost:8000/docs` in your browser.

---

## 📱 Frontend Setup (Flutter)

The frontend is a cross-platform Flutter application.

### 1. Configure the Network Connection

Because you are running the backend locally, you need to tell the Flutter app where to find it.

1. Find your laptop's IPv4 Wi-Fi address (run `ipconfig` on Windows or `ifconfig` on Mac).
2. Open `lib/api_services.dart`.
3. Update the `baseUrl` to match your IP address:

```dart
// Example: Change 192.168.x.x to your actual IPv4 address
const String baseUrl = "http://192.168.x.x:8000";
```

### 2. Install Packages

Navigate to the root of your Flutter project and fetch the dependencies:

```bash
flutter pub get
```

### 3. Run the App

Connect your physical device or start an emulator, then run:

```bash
flutter run
```

> **Note:** If testing on a physical device, ensure your phone and laptop are connected to the **same Wi-Fi network**.


---

## Getting Started

```bash
# Clone the repo
git clone https://github.com/Gohpeijia/MyHack2026.git
cd MyHack2026

# Install dependencies
flutter pub get

# Run the app
flutter run
```

> Requires Flutter 3.x and a valid Google Maps API key.
> 
---

## Built At

**MyHack 2026** — Built with ❤️ to make elderly care less lonely and more connected.
