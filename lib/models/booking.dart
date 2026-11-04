import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  Booking(this.seat, this.name, this.cash, this.bookedBy);

  final int seat;
  final String name;
  final int cash;
  final String bookedBy;

  Map<String, dynamic> toMap() {
    return {'seat': seat, 'name': name, 'cash': cash, 'bookedBy': bookedBy};
  }

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Booking(
      (data['seat'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 0,
      data['name'] as String? ?? '',
      (data['cash'] as num?)?.toInt() ?? 0,
      data['bookedBy'] as String? ?? '',
    );
  }
}
