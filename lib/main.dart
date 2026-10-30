import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'bus.dart';
import 'weather.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const BusApp());
}

class BusApp extends StatelessWidget {
  const BusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horizon Express',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const AuthGate(),
    );
  }
}

class BusBuilder extends StatelessWidget {
  const BusBuilder({super.key, required this.builder});

  final Widget Function(Bus bus) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: myBookings().snapshots(),
      builder: (context, bookings) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: myWaitlist().orderBy('joinedAt').snapshots(),
          builder: (context, waiting) {
            if (bookings.hasError || waiting.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load your bookings.\n'
                    '${bookings.error ?? waiting.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!bookings.hasData || !waiting.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final bus = Bus(
              bookings.data!.docs.map(Booking.fromDoc).toList(),
              waiting.data!.docs.map(Passenger.fromDoc).toList(),
            );
            return builder(bus);
          },
        );
      },
    );
  }
}

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
    Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((message) {
      if (message != null) showMessage(message);
    });
  }

  void openSeat(Bus bus, Seat seat) {
    if (seat.isFree()) {
      openScreen(BookScreen(bus: bus, seat: seat));
    } else {
      openScreen(DetailsScreen(bus: bus, seat: seat));
    }
  }

  Widget seatTile(Bus bus, Seat seat) {
    Color boxColor = Colors.indigo;
    Color textColor = Colors.white;
    String label = seat.passenger;

    if (seat.isFree()) {
      boxColor = Colors.green.shade100;
      textColor = Colors.black;
      label = 'free';
    }

    return GestureDetector(
      onTap: () => openSeat(bus, seat),
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

  @override
  Widget build(BuildContext context) {
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
      body: BusBuilder(
        builder: (bus) {
          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  leading: const Icon(Icons.directions_bus, size: 40),
                  title: Text('Nyabugogo → ${bus.route} · ${bus.price} RWF'),
                  subtitle: Text(
                    'Seats sold: ${bus.soldSeats()} / 12\n'
                    'Money made: ${bus.moneyMade()} RWF',
                  ),
                ),
              ),

              const WeatherBox(),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                  ),
                  itemCount: bus.seats.length,
                  itemBuilder: (context, index) {
                    return seatTile(bus, bus.seats[index]);
                  },
                ),
              ),

              if (bus.isFull())
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
        },
      ),
    );
  }
}

class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.bus, required this.seat});

  final Bus bus;
  final Seat seat;

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
    final name = nameController.text.trim();
    final cash = int.tryParse(cashController.text.trim());
    final price = widget.bus.price;

    if (name.isEmpty) {
      showMessage('Type the passenger name');
      return;
    }
    if (widget.bus.hasPassenger(name)) {
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
      await widget.bus.book(widget.seat, name, cash);
      setState(() {
        change = changeInNotes(cash - price);
        busy = false;
      });
    } catch (e) {
      setState(() {
        busy = false;
      });
      showMessage('Could not save the booking. Check your internet.');
    }
  }

  void done() {
    Navigator.pop(
      context,
      '${nameController.text.trim()} booked seat ${widget.seat.number}',
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
    final paid = change != '';

    return Scaffold(
      appBar: AppBar(title: Text('Book seat ${widget.seat.number}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ticket to ${widget.bus.route}: ${widget.bus.price} RWF',
              style: const TextStyle(fontSize: 18),
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
              onPressed: busy ? null : (paid ? done : pay),
              child: Text(paid ? 'Done' : 'Pay and book'),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key, required this.bus, required this.seat});

  final Bus bus;
  final Seat seat;

  void confirmCancel(BuildContext context) {
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
                final message = await bus.cancel(seat);
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
    return Scaffold(
      appBar: AppBar(title: Text('Seat ${seat.number}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.event_seat, size: 64, color: Colors.indigo),
            const SizedBox(height: 12),
            Text(
              seat.passenger,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Seat ${seat.number} · ${bus.route} · ${bus.price} RWF',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => confirmCancel(context),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel booking'),
            ),
          ],
        ),
      ),
    );
  }
}

class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key});

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen> {
  final nameController = TextEditingController();
  bool priority = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> join(Bus bus) async {
    final name = nameController.text.trim();

    if (!bus.isFull()) {
      showMessage('Seats are still free: book one on the seat map');
      return;
    }
    if (name.isEmpty) {
      showMessage('Type the passenger name');
      return;
    }
    if (bus.hasPassenger(name)) {
      showMessage('$name already has a seat or is waiting');
      return;
    }

    await bus.joinWaitlist(name, priority);
    setState(() {
      priority = false;
    });
    nameController.clear();
    showMessage('$name joined the waitlist');
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Waitlist')),
      body: BusBuilder(
        builder: (bus) {
          final waitlist = bus.waitlist;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      bus.isFull()
                          ? 'The bus is full. ${waitlist.length} waiting.'
                          : 'Seats are still free: the waitlist opens when the bus is full.',
                    ),
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Passenger name'),
                    ),
                    SwitchListTile(
                      title:
                          const Text('Priority (elderly, pregnant, disabled)'),
                      value: priority,
                      onChanged: (value) {
                        setState(() {
                          priority = value;
                        });
                      },
                    ),
                    FilledButton(
                      onPressed: () => join(bus),
                      child: const Text('Join the waitlist'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: waitlist.isEmpty
                    ? const Center(child: Text('Nobody is waiting'))
                    : ListView.builder(
                        itemCount: waitlist.length,
                        itemBuilder: (context, index) {
                          final person = waitlist[index];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(person.name),
                            trailing: person.priority
                                ? const Chip(label: Text('Priority'))
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class WeatherBox extends StatefulWidget {
  const WeatherBox({super.key});

  @override
  State<WeatherBox> createState() => _WeatherBoxState();
}

class _WeatherBoxState extends State<WeatherBox> {
  Weather? weather;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await fetchHuyeWeather();
      if (!mounted) return;
      setState(() {
        weather = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load the weather. Check your internet connection.';
      });
    }
  }

  void retry() {
    setState(() {
      loading = true;
      error = null;
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (loading) {
      content = const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(),
        ),
        title: Text('Loading the weather in Huye...'),
      );
    } else if (error != null) {
      content = ListTile(
        leading: const Icon(Icons.wifi_off),
        title: Text(error!),
        trailing: FilledButton(
          onPressed: retry,
          child: const Text('Retry'),
        ),
      );
    } else {
      content = ListTile(
        leading: const Icon(Icons.wb_cloudy, size: 36),
        title: Text(
          'Huye now: ${weather!.temperature.round()}°C, ${describe(weather!.code)}',
        ),
        subtitle: Text(
          'Humidity ${weather!.humidity}% · Wind ${weather!.wind} km/h\n'
          'Updated at ${weather!.time.substring(11)}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: retry,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: content,
    );
  }
}
