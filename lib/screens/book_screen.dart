import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/booking_state.dart';
import '../utils/money.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.seatNumber});

  final int seatNumber;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final nameController = TextEditingController();
  final cashController = TextEditingController();
  String change = '';
  bool busy = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> pay() async {
    final brain = context.read<BookingState>();
    final seat = brain.seat(widget.seatNumber);
    final name = nameController.text.trim();
    final cash = int.tryParse(cashController.text.trim());
    final price = brain.price;

    if (!seat.isFree()) {
      showMessage('Seat ${seat.number} was just taken. Go back and choose another.');
      return;
    }
    if (name.isEmpty) {
      showMessage('Type the passenger name');
      return;
    }
    if (brain.hasPassenger(name)) {
      showMessage('$name already has a seat or is waiting');
      return;
    }
    if (cash == null) {
      showMessage('Type the cash as a number, like 5000');
      return;
    }
    if (cash < price) {
      showMessage('Not enough: the ticket is $price RWF');
      return;
    }
    if (cash % 100 != 0) {
      showMessage('Cash must be a multiple of 100 RWF');
      return;
    }

    setState(() {
      busy = true;
    });
    try {
      await brain.book(seat, name, cash);
      if (!mounted) return;
      setState(() {
        change = changeInNotes(cash - price);
        busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
      });
      showMessage('Could not book: the seat may have just been taken, or there is no internet.');
    }
  }

  void done() {
    Navigator.pop(
      context,
      '${nameController.text.trim()} booked seat ${widget.seatNumber}',
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    cashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = context.watch<BookingState>();
    final seat = brain.seat(widget.seatNumber);
    final paid = change != '';
    final justTaken = !paid && !busy && !seat.isFree();

    return Scaffold(
      appBar: AppBar(title: Text('Book seat ${widget.seatNumber}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ticket to ${brain.route}: ${brain.price} RWF',
              style: const TextStyle(fontSize: 18),
            ),
            Text('Seats left: ${brain.seatsLeft} / ${brain.totalSeats}'),
            if (justTaken)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Seat ${seat.number} was just taken by another account.',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              enabled: !paid,
              decoration: const InputDecoration(labelText: 'Passenger name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cashController,
              enabled: !paid,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cash handed over (RWF)',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              paid ? 'Change: $change' : 'The change will show here',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: (busy || justTaken) ? null : (paid ? done : pay),
              child: Text(paid ? 'Done' : 'Pay and book'),
            ),
          ],
        ),
      ),
    );
  }
}
