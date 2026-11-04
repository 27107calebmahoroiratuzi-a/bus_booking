import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/booking_state.dart';

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key, required this.seatNumber});

  final int seatNumber;

  void confirmCancel(BuildContext context) {
    final brain = context.read<BookingState>();
    final seat = brain.seat(seatNumber);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel this booking?'),
          content: Text('Seat ${seat.number} will be freed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Keep it'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                String message;
                try {
                  message = await brain.cancel(seat);
                } catch (e) {
                  message = 'Could not cancel. Check your internet.';
                }
                if (context.mounted) {
                  Navigator.pop(context, message);
                }
              },
              child: const Text('Yes, cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brain = context.watch<BookingState>();
    final seat = brain.seat(seatNumber);

    return Scaffold(
      appBar: AppBar(title: Text('Seat $seatNumber')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.event_seat, size: 64, color: Colors.indigo),
            const SizedBox(height: 12),
            Text(
              seat.isFree() ? 'This seat is free now' : seat.passenger,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Seat $seatNumber · ${brain.route} · ${brain.price} RWF',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (seat.isFree())
              const SizedBox()
            else if (brain.isMine(seat))
              OutlinedButton.icon(
                onPressed: () => confirmCancel(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel booking'),
              )
            else
              const Text(
                'Booked by another account: only that account can cancel it.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
