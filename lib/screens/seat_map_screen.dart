import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/seat.dart';
import '../state/booking_state.dart';
import 'book_screen.dart';
import 'details_screen.dart';
import 'waitlist_screen.dart';
import 'weather_box.dart';

class SeatMapScreen extends StatefulWidget {
  const SeatMapScreen({super.key});

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void openScreen(Widget screen) {
    final brain = context.read<BookingState>();
    Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<BookingState>.value(
          value: brain,
          child: screen,
        ),
      ),
    ).then((message) {
      if (message != null && mounted) showMessage(message);
    });
  }

  void openSeat(Seat seat) {
    if (seat.isFree()) {
      openScreen(BookScreen(seatNumber: seat.number));
    } else {
      openScreen(DetailsScreen(seatNumber: seat.number));
    }
  }

  Widget seatTile(BookingState brain, Seat seat) {
    Color boxColor = Colors.blueGrey;
    Color textColor = Colors.white;
    String label = seat.passenger;

    if (seat.isFree()) {
      boxColor = Colors.green.shade100;
      textColor = Colors.black;
      label = 'free';
    } else if (brain.isMine(seat)) {
      boxColor = Colors.indigo;
    }

    return GestureDetector(
      onTap: () => openSeat(seat),
      child: Container(
        margin: const EdgeInsets.all(6),
        color: boxColor,
        child: Center(
          child: Text(
            '${seat.number}\n$label',
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor),
          ),
        ),
      ),
    );
  }

  Widget filterChip(BookingState brain, String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: brain.filter == value,
        onSelected: (_) => context.read<BookingState>().setFilter(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brain = context.watch<BookingState>();

    Widget body;
    if (brain.error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(brain.error!, textAlign: TextAlign.center),
        ),
      );
    } else if (brain.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final seats = brain.visibleSeats;
      body = Column(
        children: [
          Card(
            margin: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.directions_bus, size: 40),
              title: Text('Nyabugogo → ${brain.route} · ${brain.price} RWF'),
              subtitle: Text(
                'Seats sold: ${brain.soldSeats} / ${brain.totalSeats}\n'
                'Money made: ${brain.moneyMade} RWF',
              ),
            ),
          ),

          const WeatherBox(),

          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                filterChip(brain, 'all', 'All'),
                filterChip(brain, 'free', 'Free'),
                filterChip(brain, 'mine', 'Mine'),
              ],
            ),
          ),

          Expanded(
            child: seats.isEmpty
                ? const Center(child: Text('Nothing matches this filter.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                    ),
                    itemCount: seats.length,
                    itemBuilder: (context, index) {
                      return seatTile(brain, seats[index]);
                    },
                  ),
          ),

          if (brain.isFull)
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () => openScreen(const WaitlistScreen()),
                icon: const Icon(Icons.hourglass_empty),
                label: const Text('Bus is full: join the waitlist'),
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Horizon Express'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Waitlist',
            onPressed: () => openScreen(const WaitlistScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: body,
    );
  }
}
