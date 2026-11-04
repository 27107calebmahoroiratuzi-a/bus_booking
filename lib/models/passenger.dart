import 'package:cloud_firestore/cloud_firestore.dart';

class Passenger {
  Passenger(this.id, this.name, this.priority, this.addedBy);

  final String id;
  final String name;
  final bool priority;
  final String addedBy;

  Map<String, dynamic> toMap() {
    return {'name': name, 'priority': priority, 'addedBy': addedBy};
  }

  factory Passenger.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Passenger(
      doc.id,
      data['name'] as String? ?? '',
      data['priority'] as bool? ?? false,
      data['addedBy'] as String? ?? '',
    );
  }
}
