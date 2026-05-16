import 'package:http/http.dart' as http;
import 'dart:convert';

// Replace 192.168.x.x with your backend teammate's IP
const String baseUrl = "http://192.168.30.150:8000";

Future<Map> getAlerts(String elderId) async {
  try {
    final response = await http.get(Uri.parse('$baseUrl/api/ai/alerts/$elderId'));
    return jsonDecode(response.body);
  } catch (e) {
    print('🚨 API ERROR in getAlerts: $e'); // Add this line!
    return {};
  }
}

Future<Map> getSchedule(String elderId) async {
  try {
    final response = await http.get(Uri.parse('$baseUrl/api/ai/schedule/$elderId'));
    return jsonDecode(response.body);
  } catch (e) {
    print('🚨 API ERROR in getAlerts: $e'); // Add this line!
    return {};
  }
}

Future<Map> getLocation(String elderId) async {
  try {
    final response = await http.get(Uri.parse('$baseUrl/api/ai/location/$elderId'));
    return jsonDecode(response.body);
  } catch (e) {
    print('🚨 API ERROR in getAlerts: $e'); // Add this line!
    return {};
  }
}

Future<Map> suggestContact(String elderId, String reason) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/ai/suggest'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"elder_id": elderId, "reason": reason}),
    );
    return jsonDecode(response.body);
  } catch (e) {
    print('🚨 API ERROR in getAlerts: $e'); // Add this line!
    return {};
  }
}

Future<Map> postVoiceLog(String elderId, String transcript) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/ai/voice-log'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"elder_id": elderId, "raw_text": transcript}),
    );
    return jsonDecode(response.body);
  } catch (e) {
    print('🚨 API ERROR in getAlerts: $e'); // Add this line!
    return {};
  }
}