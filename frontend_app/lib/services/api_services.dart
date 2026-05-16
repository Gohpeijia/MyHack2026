import 'package:http/http.dart' as http;
import 'dart:convert';

// Replace 192.168.x.x with your backend teammate's IP
const String baseUrl = "http://192.168.56.1:8000";

Future<Map> getAlerts(String elderId) async {
  final response = await http.get(Uri.parse('$baseUrl/api/ai/alerts/$elderId'));
  return jsonDecode(response.body);
}

Future<Map> getSchedule(String elderId) async {
  final response = await http.get(Uri.parse('$baseUrl/api/ai/schedule/$elderId'));
  return jsonDecode(response.body);
}

Future<Map> getLocation(String elderId) async {
  final response = await http.get(Uri.parse('$baseUrl/api/ai/location/$elderId'));
  return jsonDecode(response.body);
}

Future<Map> suggestContact(String elderId, String reason) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/ai/suggest'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"elder_id": elderId, "reason": reason}),
  );
  return jsonDecode(response.body);
}

Future<Map> postVoiceLog(String elderId, String transcript) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/ai/voice-log'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"elder_id": elderId, "raw_text": transcript}),
  );
  return jsonDecode(response.body);
}