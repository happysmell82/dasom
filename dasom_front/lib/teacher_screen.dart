import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/rendering.dart';

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  _TeacherScheduleScreenState createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> with AutomaticKeepAliveClientMixin {
  String? selectedYear;
  String? selectedMonth;
  String? selectedTeacher;

  List<String> years = ['2025', '2026', '2027'];
  List<String> months = ['01', '02', '03', '04'];
  List<Map<String, dynamic>> teachers = []; // 서버에서 가져오는 선생님 목록
  Map<String, Map<String, List<String>>> schedules = {}; // 선생님별 시간표 (년-월 -> {요일: 시간대})

  List<List<Map<String, dynamic>?>> schedule = List.generate(7, (index) => List.generate(14, (index) => null));

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    selectedYear = now.year.toString();
    selectedMonth = now.month.toString().padLeft(2, '0'); // 01, 02 형태 유지
    _loadTeachers(); // 화면이 열리면 선생님 목록을 불러옴
  }

  @override
  bool get wantKeepAlive => true;  // 상태 유지를 위한 오버라이드

  // 선생님 목록을 서버에서 불러오는 함수
  Future<void> _loadTeachers() async {
    var response = await http.get(Uri.parse('http://101.101.160.223:5000/teachers'));

    if (response.statusCode == 200) {
      setState(() {
        var data = json.decode(response.body);
        teachers = List<Map<String, dynamic>>.from(data); // 서버에서 받은 선생님 목록을 리스트로 저장
      });
    } else {
      print('Failed to load teachers');
    }
  }

  // 선생님을 선택했을 때 해당 선생님의 시간표를 불러오는 함수
  Future<void> _loadSchedule(String teacher, String yearMonth) async {
    var response = await http.get(
      Uri.parse('http://101.101.160.223:5000/teacher_schedules?teacher=$teacher&year_month=$yearMonth'),
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
              'teacher': selectedTeacher,
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
  void _showTeacherDialog(BuildContext context) {
    TextEditingController teacherController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('선생님 등록'),
          content: TextField(
            controller: teacherController,
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
                _addTeacher(teacherController.text); // 선생님 등록 요청
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 선생님을 등록하는 함수
  Future<void> _addTeacher(String teacherName) async {
    if (teacherName.isEmpty) return;

    var response = await http.post(
      Uri.parse('http://101.101.160.223:5000/teachers'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({'name': teacherName}),
    );

    if (response.statusCode == 201) {
      // 등록 성공 시 선생님 목록을 다시 불러옵니다.
      _loadTeachers();
    } else {
      print('Failed to add teacher');
    }
  }

  void _toggleCell(int day, int time) {
    setState(() {
      if (schedule[day][time] == null) {
        schedule[day][time] = {
          'year': selectedYear,
          'month': selectedMonth,
          'teacher': selectedTeacher,
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
      Uri.parse('http://101.101.160.223:5000/teacher_schedules'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        'teacher': selectedTeacher,
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
    super.build(context);  // AutomaticKeepAliveClientMixin 사용시 필수
    return Scaffold(
      appBar: AppBar(
        title: Text('선생님 일정 관리'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(  // 년도 선택
                      width: 80,
                      height: 32,  // 높이 고정
                      child: _buildDropdown(
                        value: selectedYear,
                        hint: '년도',
                        items: years,
                        onChanged: (value) => setState(() {
                          selectedYear = value;
                          if (selectedYear != null && selectedMonth != null && selectedTeacher != null) {
                            _loadSchedule(selectedTeacher!, '$selectedYear-$selectedMonth');
                          }
                        }),
                      ),
                    ),
                    SizedBox(width: 6),
                    SizedBox(  // 월 선택
                      width: 60,
                      height: 32,  // 높이 고정
                      child: _buildDropdown(
                        value: selectedMonth,
                        hint: '월',
                        items: months,
                        onChanged: (value) => setState(() {
                          selectedMonth = value;
                          if (selectedYear != null && selectedMonth != null && selectedTeacher != null) {
                            _loadSchedule(selectedTeacher!, '$selectedYear-$selectedMonth');
                          }
                        }),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(  // 선생님 선택
                      child: SizedBox(
                        height: 32,  // 높이 고정
                        child: _buildDropdown(
                          value: selectedTeacher,
                          hint: '선생님 선택',
                          items: teachers,
                          onChanged: (value) => setState(() {
                            selectedTeacher = value;
                            if (selectedYear != null && selectedMonth != null && selectedTeacher != null) {
                              _loadSchedule(selectedTeacher!, '$selectedYear-$selectedMonth');
                            }
                          }),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      height: 32,  // 높이 고정
                      child: IconButton(
                        icon: Icon(Icons.person_add_outlined, size: 20),
                        onPressed: () => _showTeacherDialog(context),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.all(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    childAspectRatio: 1.8,  // 비율 조정으로 칸 크기 증가
                    crossAxisSpacing: 1.5,   // 가로 간격 살짝 증가
                    mainAxisSpacing: 1.5,    // 세로 간격 살짝 증가
                  ),
                  itemCount: 112,
                  itemBuilder: (context, index) {
                    int day = (index % 8) - 1;
                    int time = (index ~/ 8);

                    if (index % 8 == 0) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            '${8 + time}:00',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }

                    if (index < 8) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Center(
                          child: Text(
                            ['일', '월', '화', '수', '목', '금', '토'][index - 1],
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      );
                    }

                    var currentSchedule = schedule[day][time];
                    return GestureDetector(
                      onTap: selectedYear == null || selectedMonth == null || selectedTeacher == null
                          ? null
                          : () => _toggleCell(day, time),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(4),
                          color: currentSchedule != null
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<dynamic> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 13)),
          items: items.map((item) {
            if (item is Map<String, dynamic>) {
              return DropdownMenuItem<String>(
                value: item['id'].toString(),
                child: Text(
                  item['name']?.toString() ?? '이름 없음',
                  style: TextStyle(fontSize: 13),
                ),
              );
            } else {
              return DropdownMenuItem<String>(
                value: item.toString(),
                child: Text(item.toString(), style: TextStyle(fontSize: 13)),
              );
            }
          }).toList(),
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          icon: Icon(Icons.arrow_drop_down, size: 18),
          isDense: true,
          itemHeight: 40,
        ),
      ),
    );
  }
}