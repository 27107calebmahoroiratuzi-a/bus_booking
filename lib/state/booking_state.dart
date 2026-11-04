import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/booking.dart';
import '../models/passenger.dart';
import '../models/seat.dart';
import '../repositories/bus_repository.dart';

class BookingState extends ChangeNotifier {
  BookingState(this._repo) {
    _bookingsSub = _repo.watchBookings().listen(
      (list) {
        _bookings = list;
        _bookingsLoaded = true;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = 'Could not load the bookings.\n$e';
        notifyListeners();
      },
    );
    _waitlistSub = _repo.watchWaitlist().listen(
      (list) {
        _waiting = list;
        _waitlistLoaded = true;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _error = 'Could not load the waitlist.\n$e';
        notifyListeners();
      },
    );
  }

  final BusRepository _repo;
  StreamSubscription<List<Booking>>? _bookingsSub;
  StreamSubscription<List<Passenger>>? _waitlistSub;

  List<Booking> _bookings = [];
  List<Passenger> _waiting = [];
  bool _bookingsLoaded = false;
  bool _waitlistLoaded = false;
  String? _error;
  String _filter = 'all';

  final String route = 'Huye';
  final int price = 3000;
  final int totalSeats = 12;

  bool get loading => !_bookingsLoaded || !_waitlistLoaded;
  String? get error => _error;
  String get filter => _filter;

  List<Seat> get seats {
    final list = <Seat>[];
    for (int n = 1; n <= totalSeats; n++) {
      list.add(Seat(n, '', ''));
    }
    for (var booking in _bookings) {
      if (booking.seat >= 1 && booking.seat <= totalSeats) {
        list[booking.seat - 1].passenger = booking.name;
        list[booking.seat - 1].bookedBy = booking.bookedBy;
      }
    }
    return list;
  }

  int get soldSeats => _bookings.length;
  int get seatsLeft => totalSeats - soldSeats;
  int get moneyMade => soldSeats * price;
  bool get isFull => seatsLeft == 0;

  List<Passenger> get waitlist {
    final ordered = <Passenger>[];
    for (var person in _waiting) {
      if (person.priority) ordered.add(person);
    }
    for (var person in _waiting) {
      if (!person.priority) ordered.add(person);
    }
    return ordered;
  }

  List<Seat> get visibleSeats {
    if (_filter == 'free') return seats.where((s) => s.isFree()).toList();
    if (_filter == 'mine') return seats.where((s) => isMine(s)).toList();
    return seats;
  }

  Seat seat(int number) {
    return seats[number - 1];
  }

  bool isMine(Seat seat) {
    return seat.bookedBy == _repo.uid;
  }

  bool hasPassenger(String name) {
    final wanted = name.toLowerCase();
    for (var booking in _bookings) {
      if (booking.name.toLowerCase() == wanted) return true;
    }
    for (var person in _waiting) {
      if (person.name.toLowerCase() == wanted) return true;
    }
    return false;
  }

  void setFilter(String value) {
    _filter = value;
    notifyListeners();
  }

  Future<void> book(Seat seat, String name, int cash) async {
    if (!seat.isFree()) return;
    await _repo.book(seat.number, name, cash);
  }

  Future<void> joinWaitlist(String name, bool priority) {
    return _repo.joinWaitlist(name, priority);
  }

  Future<String> cancel(Seat seat) async {
    if (!isMine(seat)) {
      return 'Only the account that booked seat ${seat.number} can cancel it';
    }
    final people = waitlist;
    if (people.isEmpty) {
      await _repo.cancel(seat.number);
      return '${seat.passenger} cancelled seat ${seat.number}';
    }
    final next = people.first;
    await _repo.moveUp(seat.number, next, price);
    return '${next.name} moved into seat ${seat.number}';
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _waitlistSub?.cancel();
    super.dispose();
  }
}
