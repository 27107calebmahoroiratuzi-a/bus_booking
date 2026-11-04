import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/booking_state.dart';

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

  Future<void> join() async {
    final brain = context.read<BookingState>();
    final name = nameController.text.trim();

    if (!brain.isFull) {
      showMessage('Seats are still free: book one on the seat map');
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

    try {
      await brain.joinWaitlist(name, priority);
    } catch (e) {
      showMessage('Could not join. Check your internet.');
      return;
    }
    if (!mounted) return;
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
    final brain = context.watch<BookingState>();
    final waitlist = brain.waitlist;

    return Scaffold(
      appBar: AppBar(title: const Text('Waitlist')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  brain.isFull
                      ? 'The bus is full. ${waitlist.length} waiting.'
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
