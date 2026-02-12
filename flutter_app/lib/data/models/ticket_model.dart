class TicketModel {
  final String? id;
  final String title;
  final String description;
  final String status;
  final String? createdByUserId;
  final String? createdByName;
  final String? createdByEmail;

  TicketModel({
    this.id,
    required this.title,
    required this.description,
    required this.status,
    this.createdByUserId,
    this.createdByName,
    this.createdByEmail,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final created = json['created_by_user'];
    return TicketModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'OPEN',
      createdByUserId: json['created_by_user_id'],
      createdByName: created != null ? created['name'] : null,
      createdByEmail: created != null ? created['email'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'title': title,
      'description': description,
      'status': status,
    };
    if (createdByUserId != null) {
      map['created_by_user_id'] = createdByUserId!;
    }
    return map;
  }
}
