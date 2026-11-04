import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';
import '../models/passenger.dart';

class BusRepository {
  BusRepository(this.uid);

  final String uid;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      FirebaseFirestore.instance
          .collection('buses')
          .doc('huye')
          .collection('bookings');

  CollectionReference<Map<String, dynamic>> get _waitlist =>
      FirebaseFirestore.instance
          .collection('buses')
          .doc('huye')
          .collection('waitlist');

  Stream<List<Booking>> watchBookings() => _bookings
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Booking.fromDoc).toList());

  Stream<List<Passenger>> watchWaitlist() => _waitlist
      .orderBy('joinedAt')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Passenger.fromDoc).toList());

  Future<void> book(int seat, String name, int cash) =>
      _bookings.doc('$seat').set(Booking(seat, name, cash, uid).toMap());

  Future<void> joinWaitlist(String name, bool priority) => _waitlist.add({
        ...Passenger('', name, priority, uid).toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancel(int seat) => _bookings.doc('$seat').delete();

  Future<void> moveUp(int seat, Passenger next, int price) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(_bookings.doc('$seat'),
        Booking(seat, next.name, price, next.addedBy).toMap());
    batch.delete(_waitlist.doc(next.id));
    await batch.commit();
  }

  Future<void> addSamples() async {
    try {
      final existing = await _bookings.limit(1).get();
      if (existing.docs.isNotEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      batch.set(_bookings.doc('1'), Booking(1, 'Keza', 3000, uid).toMap());
      batch.set(_bookings.doc('2'), Booking(2, 'Eric', 5000, uid).toMap());
      batch.set(_bookings.doc('5'), Booking(5, 'Diane', 3000, uid).toMap());
      await batch.commit();
    } catch (e) {
    }
  }
}
