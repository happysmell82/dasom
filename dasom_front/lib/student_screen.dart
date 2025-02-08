import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  _StudentScheduleScreenState createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  String? selectedYear;
  String? selectedMonth;
  List<String> selectedStudents = []; // 다중 선택된 선생님 목록

  List<String> years = ['2025', '2026', '2027'];
  List<String> months = ['01', '02', '03', '04'];
  List<String> students = []; // 서버에서 가져오는 선생님 목록
  Map<String, Map<String, List<String>>> schedules = {}; // 선생님별 시간표 (년-월 -> {요일: 시간대})

  List<List<Map<String, dynamic>?>> schedule = List.generate(7, (index) => List.generate(14, (index) => null));

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    selectedYear = now.year.toString();
    selectedMonth = now.month.toString().padLeft(2, '0'); // 01, 02 형태 유지
    _loadStudents(); // 화면이 열리면 선생님 목록을 불러옴
  }

  // 선생님 목록을 서버에서 불러오는 함수
  Future<void> _loadStudents() async {
    var response = await http.get(Uri.parse('http://101.101.160.223:5000/students'));

    if (response.statusCode == 200) {
      setState(() {
        var data = json.decode(response.body);
        students = List<String>.from(data.map((student) => student['name'])); // 서버에서 받은 선생님 목록을 리스트로 저장
      });
    } else {
      print('Failed to load students');
    }
  }

  // 선생님을 선택했을 때 해당 선생님의 시간표를 불러오는 함수
  Future<void> _loadSchedule(List<String> students, String yearMonth) async {
    var response = await http.get(
      Uri.parse('http://101.101.160.223:5000/schedules?students=${students.join(',')}&year_month=$yearMonth'),
    );

    if (response.statusCode == 200) {
      setState(() {
        var data = json.decode(response.body);

        // `schedule` 리스트 초기화
        schedule = List.generate(7, (index) => List.generate(14, (index) => null));

        for (var entry in data) {
          String day = entry['day'];  // 요일 ('일', '월' ...)
          String time = entry['time']; // "8:00" 형태의 문자열

          int dayIndex = ['일', '월', '화', '수', '목', '금', '토'].indexOf(day);
          int timeIndex = int.parse(time.split(':')[0]) - 8; // 8시부터 시작이므로 변환

          if (dayIndex >= 0 && timeIndex >= 0 && timeIndex < 14) {
            schedule[dayIndex][timeIndex] = {
              'year': selectedYear,
              'month': selectedMonth,
              'students': selectedStudents,
              'day': day,
              'time': time,
            };
          }
        }
      });
    } else {
      print('Failed to load schedule');
    }
  }

  // 선생님 등록 다이얼로그
  void _showStudentDialog(BuildContext context) {
    TextEditingController studentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('선생님 등록'),
          content: TextField(
            controller: studentController,
            decoration: InputDecoration(labelText: '선생님 이름'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('등록'),
              onPressed: () {
                _addStudent(studentController.text); // 선생님 등록 요청
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 선생님을 등록하는 함수
  Future<void> _addStudent(String studentName) async {
    if (studentName.isEmpty) return;

    var response = await http.post(
      Uri.parse('http://101.101.160.223:5000/students'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({'name': studentName}),
    );

    if (response.statusCode == 201) {
      // 등록 성공 시 선생님 목록을 다시 불러옵니다.
      _loadStudents();
    } else {
      print('Failed to add student');
    }
  }

  void _toggleCell(int day, int time) {
    setState(() {
      if (schedule[day][time] == null) {
        schedule[day][time] = {
          'year': selectedYear,
          'month': selectedMonth,
          'students': selectedStudents,
          'day': ['일', '월', '화', '수', '목', '금', '토'][day],
          'time': '${8 + time}:00', // 1시간 단위 시간 처리
        };
      } else {
        schedule[day][time] = null; // 이미 선택된 칸은 취소
      }

      Future.delayed(Duration(milliseconds: 300), _saveSchedule);
    });
  }

  Future<void> _saveSchedule() async {
    var scheduleData = [];

    for (int day = 0; day < 7; day++) {
      for (int time = 0; time < 14; time++) {
        if (schedule[day][time] != null) {
          scheduleData.add(schedule[day][time]);
        }
      }
    }

    var response = await http.post(
      Uri.parse('http://101.101.160.223:5000/schedules'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        'students': selectedStudents,
        'year_month': '$selectedYear-$selectedMonth',
        'schedule': scheduleData,
      }),
    );

    if (response.statusCode == 200) {
      print("Schedule saved successfully!");
    } else {
      print("Failed to save schedule.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('학생 일정 관리'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                DropdownButton<String>(
                  value: selectedYear,
                  hint: Text('년도'),
                  onChanged: (value) {
                    setState(() {
                      selectedYear = value;
                      if (selectedYear != null && selectedMonth != null && selectedStudents.isNotEmpty) {
                        _loadSchedule(selectedStudents, '$selectedYear-$selectedMonth');
                      }
                    });
                  },
                  items: years.map((year) {
                    return DropdownMenuItem<String>(
                      value: year,
                      child: Text(year),
                    );
                  }).toList(),
                ),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedMonth,
                  hint: Text('월'),
                  onChanged: (value) {
                    setState(() {
                      selectedMonth = value;
                      if (selectedYear != null && selectedMonth != null && selectedStudents.isNotEmpty) {
                        _loadSchedule(selectedStudents, '$selectedYear-$selectedMonth');
                      }
                    });
                  },
                  items: months.map((month) {
                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(month),
                    );
                  }).toList(),
                ),
                SizedBox(width: 10),
                // 다중 선생님 선택을 위한 체크박스 목록
                Expanded(
                  child: Column(
                    children: students.map((student) {
                      return CheckboxListTile(
                        title: Text(student),
                        value: selectedStudents.contains(student),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value != null && value) {
                              selectedStudents.add(student);
                            } else {
                              selectedStudents.remove(student);
                            }

                            if (selectedYear != null && selectedMonth != null && selectedStudents.isNotEmpty) {
                              _loadSchedule(selectedStudents, '$selectedYear-$selectedMonth');
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _showStudentDialog(context),
                ),
              ],
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8, // 7일 + 1시간 열 (가로 8칸)
                  childAspectRatio: 2.0,
                ),
                itemCount: 112, // 7일 * 14시간 + 1시간 열
                itemBuilder: (context, index) {
                  int day = (index % 8) - 1; // 첫 번째 열(시간 표시 제외)로 요일을 구분
                  int time = (index ~/ 8);    // 세로 14시간 (1시간 단위)

                  // 첫 번째 열 (시간 표시)
                  if (index % 8 == 0) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                      ),
                      child: Center(child: Text('${8 + time}:00')),
                    );
                  }

                  // 첫 번째 행 (요일 표시)
                  if (index < 8) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                      ),
                      child: Center(child: Text(['일', '월', '화', '수', '목', '금', '토'][index - 1])),
                    );
                  }

                  // 년월, 선생님 선택이 되어 있지 않으면 클릭 불가
                  if (selectedYear == null || selectedMonth == null || selectedStudents.isEmpty) {
                    return GestureDetector(
                      onTap: null,  // 클릭 비활성화
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black),
                          color: Colors.grey[200],
                        ),
                      ),
                    );
                  }

                  // 시간표 색칠 기능 (선택된 시간은 색상이 변함)
                  var currentSchedule = schedule[day][time];
                  return GestureDetector(
                    onTap: () {
                      _toggleCell(day, time);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black),
                        color: currentSchedule == null ? Colors.white : Colors.green[200],
                      ),
                    )
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}