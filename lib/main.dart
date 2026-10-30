import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_gate.dart';
import 'weather.dart';

class Seat {
  Seat(this.number, this.passenger);

  final int number;
  String passenger;

  bool isFree() {
    return passenger == '';
  }
}

class Passenger {
  Passenger(this.name, this.priority);

  final String name;
  final bool priority;

  Map<String, dynamic> toJson() {
    return {'name': name, 'priority': priority};
  }

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(json['name'] as String, json['priority'] as bool);
  }
}

class Bus {
  final String route = 'Huye';
  final int price = 3000;

  final seats = [
    Seat(1, 'Keza'),
    Seat(2, 'Eric'),
    Seat(3, ''),
    Seat(4, ''),
    Seat(5, 'Diane'),
    Seat(6, ''),
    Seat(7, ''),
    Seat(8, ''),
    Seat(9, ''),
    Seat(10, ''),
    Seat(11, ''),
    Seat(12, ''),
  ];
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

  void book(Seat seat, String name) {
    if (seat.isFree()) {
      seat.passenger = name;
      save();
    }
  }

  void joinWaitlist(String name, bool priority) {
    if (priority) {
      int position = 0;
      for (var person in waitlist) {
        if (person.priority) position = position + 1;
      }
      waitlist.insert(position, Passenger(name, true));
    } else {
      waitlist.add(Passenger(name, false));
    }
    save();
  }

  String cancel(Seat seat) {
    final name = seat.passenger;
    seat.passenger = '';

    if (waitlist.isEmpty) {
      save();
      return '$name cancelled seat ${seat.number}';
    }
    final next = waitlist.removeAt(0);
    seat.passenger = next.name;
    save();
    return '${next.name} moved into seat ${seat.number}';
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    final names = <String>[];
    for (var seat in seats) {
      names.add(seat.passenger);
    }
    await prefs.setStringList('seats', names);

    final people = <Map<String, dynamic>>[];
    for (var person in waitlist) {
      people.add(person.toJson());
    }
    await prefs.setString('waitlist', jsonEncode(people));
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final names = prefs.getStringList('seats');
    if (names != null && names.length == seats.length) {
      for (int i = 0; i < seats.length; i++) {
        seats[i].passenger = names[i];
      }
    }

    final saved = prefs.getString('waitlist');
    if (saved != null) {
      final list = jsonDecode(saved) as List;
      waitlist.clear();
      for (var item in list) {
        waitlist.add(Passenger.fromJson(item as Map<String, dynamic>));
      }
    }
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

class SeatMapScreen extends StatefulWidget {
  const SeatMapScreen({super.key});

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  final bus = Bus();

  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    await bus.load();
    setState(() {});
  }

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
      setState(() {});
      if (message != null) showMessage(message);
    });
  }

  void openSeat(Seat seat) {
    if (seat.isFree()) {
      openScreen(BookScreen(bus: bus, seat: seat));
    } else {
      openScreen(DetailsScreen(bus: bus, seat: seat));
    }
  }

  Widget seatTile(Seat seat) {
    Color boxColor = Colors.indigo;
    Color textColor = Colors.white;
    String label = seat.passenger;

    if (seat.isFree()) {
      boxColor = Colors.green.shade100;
      textColor = Colors.black;
      label = 'free';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Horizon Express'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Waitlist',
            onPressed: () => openScreen(WaitlistScreen(bus: bus)),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
              ),
              itemCount: bus.seats.length,
              itemBuilder: (context, index) {
                return seatTile(bus.seats[index]);
              },
            ),
          ),

          if (bus.isFull())
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () => openScreen(WaitlistScreen(bus: bus)),
                icon: const Icon(Icons.hourglass_empty),
                label: const Text('Bus is full: join the waitlist'),
              ),
            ),
        ],
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

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void pay() {
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
      widget.bus.book(widget.seat, name);
      change = changeInNotes(cash - price);
    });
  }

  void done() {
    Navigator.pop(
      context,
      '${widget.seat.passenger} booked seat ${widget.seat.number}',
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
              onPressed: paid ? done : pay,
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
              onPressed: () {
                final message = bus.cancel(seat);
                Navigator.pop(dialogContext);
                Navigator.pop(context, message);
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
  const WaitlistScreen({super.key, required this.bus});

  final Bus bus;

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

  void join() {
    final name = nameController.text.trim();

    if (!widget.bus.isFull()) {
      showMessage('Seats are still free: book one on the seat map');
      return;
    }
    if (name.isEmpty) {
      showMessage('Type the passenger name');
      return;
    }
    if (widget.bus.hasPassenger(name)) {
      showMessage('$name already has a seat or is waiting');
      return;
    }

    setState(() {
      widget.bus.joinWaitlist(name, priority);
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
    final waitlist = widget.bus.waitlist;

    return Scaffold(
      appBar: AppBar(title: Text('Waitlist (${waitlist.length})')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.bus.isFull()
                      ? 'The bus is full. New passengers wait here.'
                      : 'Seats are still free: the waitlist opens when the bus is full.',
                ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Passenger name'),
                ),
                SwitchListTile(
                  title: const Text('Priority (elderly, pregnant, disabled)'),
                  value: priority,
                  onChanged: (value) {
                    setState(() {
                      priority = value;
                    });
                  },
                ),
                FilledButton(
                  onPressed: join,
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
      setState(() {
        weather = result;
        loading = false;
        error = null;
      });
    } catch (e) {
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