import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../repositories/weather_repository.dart';

class WeatherBox extends StatefulWidget {
  const WeatherBox({super.key});

  @override
  State<WeatherBox> createState() => _WeatherBoxState();
}

class _WeatherBoxState extends State<WeatherBox> {
  final repo = WeatherRepository();
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
      final result = await repo.fetchHuye();
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
