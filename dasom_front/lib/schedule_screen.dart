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
  String selectedTeacher = '';
  List monthlySchedule = [];

  // 선생님 목록을 받아오는 함수
  Future<List<String>> _fetchTeachers() async {
    final response = await http.get(Uri.parse('http://101.101.160.223:5000/teachers'));
    if (response.statusCode == 200) {
      List teachers = jsonDecode(response.body);
      return teachers.map<String>((teacher) => teacher['name']).toList();
    } else {
      throw Exception('Failed to load teachers');
    }
  }

  // 선택된 선생님과 년월에 대한 스케줄 정보 가져오기
  Future<void> _fetchMonthlySchedule() async {
    if (selectedTeacher.isEmpty) return;

    final response = await http.get(Uri.parse(
        'http://101.101.160.223:5000/monthly_teacher_schedule?teacher=$selectedTeacher&year_month=$selectedMonth'));

    if (response.statusCode == 200) {
      setState(() {
        monthlySchedule = jsonDecode(response.body);
        print(monthlySchedule);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("불러오기 실패")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('시간표')),
      body: Column(
        children: [
          // 선생님 선택 드롭다운
          FutureBuilder<List<String>>(
            future: _fetchTeachers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              return DropdownButton<String>(
                value: selectedTeacher.isEmpty ? null : selectedTeacher,
                hint: Text("선생님을 선택하세요"),
                items: snapshot.data!
                    .map((teacher) => DropdownMenuItem<String>(
                          value: teacher,
                          child: Text(teacher),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTeacher = value!;
                    _fetchMonthlySchedule();
                  });
                },
              );
            },
          ),

          // 년월 선택 드롭다운
          DropdownButton<int>(
            value: selectedMonth,
            items: List.generate(12, (index) => index + 1)
                .map((month) => DropdownMenuItem(value: month, child: Text("$month월")))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedMonth = value!;
                _fetchMonthlySchedule();
              });
            },
          ),

          // 월간 스케줄을 달력 형식으로 표시
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
              ),
              itemCount: 31, // 각 월에 최대 31일
              itemBuilder: (context, index) {
                int day = index + 1;
                var daySchedule = monthlySchedule
                    .where((item) => item['day'] == day.toString())
                    .toList();
                return GestureDetector(
                  onTap: () {
                    // 해당 날짜를 클릭했을 때 더 자세한 정보를 보여줄 수 있음
                  },
                  child: Container(
                    margin: EdgeInsets.all(4.0),
                    decoration: BoxDecoration(
                      border: Border.all(),
                      color: Colors.blue[100],
                    ),
                    child: Column(
                      children: [
                        Text('$day'),
                        ...daySchedule.map((entry) {
                          return Text(
                            '${entry['teacher']} - ${entry['students'].join(", ")}',
                            style: TextStyle(fontSize: 12),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}