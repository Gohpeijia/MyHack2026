from AI_Services import check_for_alerts, check_location, suggest_contact, find_replacement, parse_visit_log,format_daily_schedule

# --- Fake data ---

elder = {
    "id": "elder001",
    "name": "Mak Cik Rohani",
    "age": 71,
    "location": "Petaling Jaya, Selangor",
    "living_situation": "lives alone",
    "languages": ["Malay", "Mandarin"],
    "interests": ["morning walks", "cooking"]
}

activities = [
    {"activity": "Morning walk", "scheduled_time": "08:00", "checked_in": False, "skipped": True},
    {"activity": "Lunch", "scheduled_time": "12:00", "checked_in": False, "skipped": False},
    {"activity": "Evening call with son", "scheduled_time": "18:00", "checked_in": True, "skipped": False},
]

contacts = [
    {"id": "c001", "name": "Ahmad", "role": "volunteer", "availability": ["weekday mornings"], "phone": "0123456789"},
    {"id": "c002", "name": "Siti", "role": "family", "availability": ["evenings"], "phone": "0198765432"},
    {"id": "c003", "name": "MyCare NGO", "role": "ngo", "availability": ["daily"], "phone": "0111234567"},
]

cancelled = {
    "id": "c001", "name": "Ahmad", "role": "volunteer", "availability": ["weekday mornings"]
}

transcript = "Today I visited Mak Cik Rohani, she was in good spirits. She mentioned her knee has been a bit sore lately. I watched her take her blood pressure medication at noon."

medicine_times = [
    {"medicine": "Blood pressure pill", "time": "08:00", "taken": True},
    {"medicine": "Vitamin D", "time": "13:00", "taken": False},
    {"medicine": "Cholesterol pill", "time": "21:00", "taken": False},
]

location_history = [
    {"timestamp": "08:00", "place": "Home, Petaling Jaya", "lat": 3.1073, "lng": 101.6067},
    {"timestamp": "08:30", "place": "Taman Jaya Park, PJ", "lat": 3.1080, "lng": 101.6100},
    {"timestamp": "09:00", "place": "Taman Jaya Park, PJ", "lat": 3.1081, "lng": 101.6101},
    {"timestamp": "09:30", "place": "Taman Jaya Park, PJ", "lat": 3.1081, "lng": 101.6101},
    {"timestamp": "10:00", "place": "Taman Jaya Park, PJ", "lat": 3.1081, "lng": 101.6101},
]
# --- Tests ---

print("\n========== TEST 1: check_for_alerts ==========")
result = check_for_alerts(elder, activities)
print(result)

print("\n========== TEST 2: suggest_contact ==========")
result = suggest_contact(elder, contacts, "Morning walk was skipped")
print(result)

print("\n========== TEST 3: find_replacement ==========")
result = find_replacement(elder, cancelled, contacts)
print(result)

print("\n========== TEST 4: parse_visit_log ==========")
result = parse_visit_log(transcript, elder)
print(result)

print("\n========== TEST 5: format_daily_schedule ==========")
result = format_daily_schedule(elder, activities, medicine_times)
print(result)

print("\n========== TEST 6: check_location ==========")
result = check_location(elder, location_history)
print(result)


print("\n========== TEST 7: format_daily_schedule ==========")
result = format_daily_schedule(elder, activities, medicine_times)
print(result)

print("\n========== ALL TESTS DONE ==========")


