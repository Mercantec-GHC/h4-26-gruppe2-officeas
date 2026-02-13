import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/ticket_model.dart';

class TicketService {
  static const String baseUrl = 'http://localhost:8080/api';

  Future<List<TicketModel>> getAllTickets({String? jwt}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (jwt != null && jwt.isNotEmpty) headers['Authorization'] = 'Bearer $jwt';

    final response = await http.get(Uri.parse('$baseUrl/tickets'), headers: headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => TicketModel.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load tickets (${response.statusCode}): ${response.body}');
    }
  }

  Future<TicketModel> createTicket({required TicketModel ticket, String? jwt}) async {
    final headers = {'Content-Type': 'application/json'};
    if (jwt != null) headers['Authorization'] = 'Bearer $jwt';

    final response = await http.post(Uri.parse('$baseUrl/tickets'), headers: headers, body: jsonEncode(ticket.toJson()));
    if (response.statusCode == 201) {
      return TicketModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create ticket (${response.statusCode}): ${response.body}');
    }
  }

  Future<void> deleteTicket(String id, {String? jwt}) async {
    final headers = <String, String>{};
    if (jwt != null) headers['Authorization'] = 'Bearer $jwt';

    final response = await http.delete(Uri.parse('$baseUrl/tickets/$id'), headers: headers);
    if (response.statusCode != 204) {
      throw Exception('Failed to delete ticket');
    }
  }
}
