import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CounterController {
  int _counter = 0;
  int _step;
  List<String> _history = [];
  String? _username;

  CounterController({int initialStep = 1}) : _step = initialStep;
  int get value => _counter;
  int get currentStep => _step;
  List<String> get currentHistory => _history;

  Future<void> loadData(String username) async {
    _username = username;
    final prefs = await SharedPreferences.getInstance();
    _counter = prefs.getInt('counter_$username') ?? 0;
    _history = prefs.getStringList('history_$username') ?? [];
  }

  Future<void> _saveData() async {
    if (_username == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter_$_username', _counter);
    await prefs.setStringList('history_$_username', _history);
  }

  void incrementCounter() {
    int before = _counter;
    _counter += _step;
    _addLog("Menambahkan", before, _counter);
    _saveData();
  }

  void decrementCounter() {
    int before = _counter;
    if (_counter > 0) _counter -= _step;
    if (_step > _counter) _counter = 0;
    _addLog("Mengurangi", before, _counter);
    _saveData();
  }

  void resetCounter() {
    int before = _counter;
    _counter = 0;
    _addLog("Reset", before, _counter);
    _saveData();
  }

  void setStep(int newStep) {
    int before = _step;
    _step = newStep;
    if (newStep < 0) _step = before;
  }

  void _addLog(String action, int from, int to) {
    String time =
        "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    String name = _username ?? "User";
    _history.insert(0, "User $name $action dari $from ke $to di jam $time");

    if (_history.length > 5){
      _history.removeLast();
    }
    // _saveData called in calling methods
  }

  Color colorTile(String text) {
    Color result;
    if (text.contains("Menambahkan")) {
      result = Colors.green;
    } else if (text.contains("Mengurangi")) {
      result = Colors.red;
    } else {
      result = Colors.lightBlue;
    }
    return result;
  }
}
