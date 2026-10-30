import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

CollectionReference<Map<String, dynamic>> myBookings() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('bookings');
}

CollectionReference<Map<String, dynamic>> myWaitlist() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('waitlist');
}

Future<void> addSampleBookings() async {
  final batch = FirebaseFirestore.instance.batch();
  batch.set(myBookings().doc('1'), {'seat': 1, 'name': 'Keza', 'cash': 3000});
  batch.set(myBookings().doc('2'), {'seat': 2, 'name': 'Eric', 'cash': 5000});
  batch.set(myBookings().doc('5'), {'seat': 5, 'name': 'Diane', 'cash': 3000});
  await batch.commit();
}

class Booking {
  Booking(this.seat, this.name, this.cash);

  final int seat;
  final String name;
  final int cash;

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Booking(
      (data['seat'] as num).toInt(),
      data['name'] as String,
      (data['cash'] as num).toInt(),
    );
  }
}

class Passenger {
  Passenger(this.id, this.name, this.priority);

  final String id;
  final String name;
  final bool priority;

  factory Passenger.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Passenger(doc.id, data['name'] as String, data['priority'] as bool);
  }
}

class Seat {
  Seat(this.number, this.passenger);

  final int number;
  String passenger;

  bool isFree() {
    return passenger == '';
  }
}

class Bus {
  Bus(List<Booking> bookings, List<Passenger> waiting) {
    for (int n = 1; n <= 12; n++) {
      seats.add(Seat(n, ''));
    }
    for (var booking in bookings) {
      if (booking.seat >= 1 && booking.seat <= 12) {
        seats[booking.seat - 1].passenger = booking.name;
      }
    }

    for (var person in waiting) {
      if (person.priority) waitlist.add(person);
    }
    for (var person in waiting) {
      if (!person.priority) waitlist.add(person);
    }
  }

  final String route = 'Huye';
  final int price = 3000;
  final List<Seat> seats = [];
  final List<Passenger> waitlist = [];

  int soldSeats() {
    int sold = 0;
    for (var seat in seats) {
      if (!seat.isFree()) sold = sold + 1;
    }
    return sold;
  }

  int moneyMade() {
    return soldSeats() * price;
  }

  bool isFull() {
    return soldSeats() == seats.length;
  }

  bool hasPassenger(String name) {
    final wanted = name.toLowerCase();
    for (var seat in seats) {
      if (seat.passenger.toLowerCase() == wanted) return true;
    }
    for (var person in waitlist) {
      if (person.name.toLowerCase() == wanted) return true;
    }
    return false;
  }

  Future<void> book(Seat seat, String name, int cash) async {
    if (!seat.isFree()) return;
    await myBookings().doc('${seat.number}').set({
      'seat': seat.number,
      'name': name,
      'cash': cash,
    });
  }

  Future<void> joinWaitlist(String name, bool priority) async {
    await myWaitlist().add({
      'name': name,
      'priority': priority,
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> cancel(Seat seat) async {
    final seatDoc = myBookings().doc('${seat.number}');

    if (waitlist.isEmpty) {
      await seatDoc.delete();
      return '${seat.passenger} cancelled seat ${seat.number}';
    }

    final next = waitlist.first;
    final batch = FirebaseFirestore.instance.batch();
    batch.set(seatDoc, {'seat': seat.number, 'name': next.name, 'cash': price});
    batch.delete(myWaitlist().doc(next.id));
    await batch.commit();
    return '${next.name} moved into seat ${seat.number}';
  }
}

String changeInNotes(int change) {
  if (change == 0) return 'No change';

  final notes = [5000, 2000, 1000, 500, 100];
  final parts = <String>[];
  int left = change;

  for (var note in notes) {
    int count = left ~/ note;
    left = left % note;
    if (count > 0) parts.add('$note × $count');
  }
  return parts.join(' · ');
}
