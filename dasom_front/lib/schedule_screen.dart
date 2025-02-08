import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int selectedMonth = DateTime.now().month;
  List schedules = [];

  Future<void> _fetchSchedules() async {
    final url = Uri.parse("http://101.101.160.223:5000/schedules?month=$selectedMonth");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        schedules = jsonDecode(response.body);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("불러오기 실패")));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('시간표')),
      body: Column(
        children: [
          DropdownButton<int>(
            value: selectedMonth,
            items: List.generate(12, (index) => index + 1)
                .map((month) => DropdownMenuItem(value: month, child: Text("$month월")))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedMonth = value!;
                _fetchSchedules();
              });
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                var data = schedules[index];
                return ListTile(
                  title: Text("${data['date']} - ${data['day']}"),
                  subtitle: Text("${data['teacher']} - ${data['student']}"),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}