import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:multi_select_flutter/multi_select_flutter.dart';  // 다중 선택을 위한 패키지
import 'package:flutter/rendering.dart';

class StudentScheduleScreen extends StatefulWidget {
  const StudentScheduleScreen({super.key});

  @override
  _StudentScheduleScreenState createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> with AutomaticKeepAliveClientMixin {
  String? selectedYear;
  String? selectedMonth;
  String? selectedStudent;

  List<String> years = ['2025', '2026', '2027'];
  List<String> months = ['01', '02', '03', '04'];
  List<Map<String, dynamic>> students = []; // 서버에서 가져오는 학생 목록
  List<Map<String, dynamic>> teachers = []; // 서버에서 가져오는 선생님 목록
  List<String> selectedTeachers = []; // 선택된 선생님들
  Map<String, Map<String, List<String>>> schedules = {}; // 학생별 시간표 (년-월 -> {요일: 시간대})

  List<List<Map<String, dynamic>?>> schedule = List.generate(7, (index) => List.generate(14, (index) => null));

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    selectedYear = now.year.toString();
    selectedMonth = now.month.toString().padLeft(2, '0'); // 01, 02 형태 유지
    _loadStudents(); // 화면이 열리면 학생 목록을 불러옴
    _loadTeachers(); // 선생님 목록을 불러옴
  }

  // 학생 목록을 서버에서 불러오는 함수
  Future<void> _loadStudents() async {
    var response = await http.get(Uri.parse('http://101.101.160.223:5000/students'));

    if (response.statusCode == 200) {
      setState(() {
        var data = json.decode(response.body);
        students = List<Map<String, dynamic>>.from(data); // 서버에서 받은 학생 목록을 리스트로 저장
      });
    } else {
      print('Failed to load students');
    }
  }

  // 선생님 목록을 서버에서 불러오는 함수
  Future<void> _loadTeachers() async {
    var response = await http.get(Uri.parse('http://101.101.160.223:5000/teachers'));

    if (response.statusCode == 200) {
      setState(() {
        var data = json.decode(response.body);
        teachers = List<Map<String,dynamic>>.from(data); // 서버에서 받은 선생님 목록을 리스트로 저장
      });
    } else {
      print('Failed to load teachers');
    }
  }

  // 학생을 선택했을 때 해당 학생의 시간표를 불러오는 함수
  Future<void> _loadSchedule(String student, String yearMonth) async {
    var response = await http.get(
      Uri.parse('http://101.101.160.223:5000/student_schedules?student=$student&year_month=$yearMonth'),
    );

    if (response.statusCode == 200) {
      setState(() {
        var dataTeacher = json.decode(response.body)["teachers"];
        
        selectedTeachers = dataTeacher != null ? List<String>.from(dataTeacher) : [];
        
        var dataSchedule = json.decode(response.body)["schedule"];

        // schedule 리스트 초기화
        schedule = List.generate(7, (index) => List.generate(14, (index) => null));
        
        for (var entry in dataSchedule) {
          String day = entry['day'];  // 요일 ('일', '월' ...)
          String time = entry['time']; // "8:00" 형태의 문자열

          int dayIndex = ['일', '월', '화', '수', '목', '금', '토'].indexOf(day);
          int timeIndex = int.parse(time.split(':')[0]) - 8; // 8시부터 시작이므로 변환

          if (dayIndex >= 0 && timeIndex >= 0 && timeIndex < 14) {
            schedule[dayIndex][timeIndex] = {
              'year': selectedYear,
              'month': selectedMonth,
              'student': selectedStudent,
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

  // 학생 등록 다이얼로그
  void _showStudentDialog(BuildContext context) {
    TextEditingController studentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('학생 등록'),
          content: TextField(
            controller: studentController,
            decoration: InputDecoration(labelText: '학생 이름'),
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
                _addStudent(studentController.text); // 학생 등록 요청
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 선생님을 다중 선택할 수 있는 다이얼로그
  void _showTeacherDialog(BuildContext context) {
    List<String> tempSelectedTeachers = List.from(selectedTeachers);  // 다이얼로그에서만 사용할 임시 리스트

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('선생님 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 여러 선생님을 체크할 수 있도록 체크박스 리스트
              ...teachers.map((teacher) {
                return StatefulBuilder(  // 다이얼로그 내에서 상태를 직접적으로 관리하도록 StatefulBuilder 사용
                  builder: (context, setState) {
                    return CheckboxListTile(
                      title: Text(teacher['name']),
                      value: tempSelectedTeachers.contains(teacher['id']), // 임시 리스트로 체크 상태 관리
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelectedTeachers.add(teacher['id']);  // 선택된 선생님 추가
                          } else {
                            tempSelectedTeachers.remove(teacher['id']);  // 선택 해제된 선생님 제거
                          }
                          
                          selectedTeachers = List.from(tempSelectedTeachers);  // 최종 선택된 선생님 리스트 반영

                          Future.delayed(Duration(milliseconds: 300), _saveSchedule);
                        });
                      },
                    );
                  });  
                }),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('닫기'),
              onPressed: () {
                setState(() {
                  selectedTeachers = List.from(tempSelectedTeachers);  // 최종 선택된 선생님 리스트 반영
                });
                Navigator.of(context).pop();  // 다이얼로그 닫기
              },
            ),
          ],
        );
      },
    );
  }

  // 학생을 등록하는 함수
  Future<void> _addStudent(String studentName) async {
    if (studentName.isEmpty) return;

    var response = await http.post(
      Uri.parse('http://101.101.160.223:5000/students'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({'name': studentName}),
    );

    if (response.statusCode == 201) {
      // 등록 성공 시 학생 목록을 다시 불러옵니다.
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
          'student': selectedStudent,
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
      Uri.parse('http://101.101.160.223:5000/student_schedules'),
      headers: {"Content-Type": "application/json"},
      body: json.encode({
        'student': selectedStudent,
        'teachers': selectedTeachers,  // 선택된 선생님들 추가
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

  @override
  bool get wantKeepAlive => true;  // 상태 유지를 위한 오버라이드

  @override
  Widget build(BuildContext context) {
    super.build(context);  // AutomaticKeepAliveClientMixin 사용시 필수
    return Scaffold(
      appBar: AppBar(
        title: Text('학생 일정 관리'),
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
                      width: 80,  // 너비 축소
                      child: _buildDropdown(
                        value: selectedYear,
                        hint: '년도',
                        items: years,
                        onChanged: (value) => setState(() {
                          selectedYear = value;
                          if (selectedYear != null && selectedMonth != null && selectedStudent != null) {
                            _loadSchedule(selectedStudent!, '$selectedYear-$selectedMonth');
                          }
                        }),
                      ),
                    ),
                    SizedBox(width: 6),  // 간격 축소
                    SizedBox(  // 월 선택
                      width: 60,  // 너비 축소
                      child: _buildDropdown(
                        value: selectedMonth,
                        hint: '월',
                        items: months,
                        onChanged: (value) => setState(() {
                          selectedMonth = value;
                          if (selectedYear != null && selectedMonth != null && selectedStudent != null) {
                            _loadSchedule(selectedStudent!, '$selectedYear-$selectedMonth');
                          }
                        }),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(  // 학생 선택 - 더 넓은 공간 차지
                      flex: 3,  // 더 많은 공간을 차지하도록 flex 값 추가
                      child: _buildDropdown(
                        value: selectedStudent,
                        hint: '학생 선택',
                        items: students,
                        onChanged: (value) => setState(() {
                          selectedStudent = value;
                          if (selectedYear != null && selectedMonth != null && selectedStudent != null) {
                            _loadSchedule(selectedStudent!, '$selectedYear-$selectedMonth');
                          }
                        }),
                      ),
                    ),
                    SizedBox(width: 4),
                    Container(  // 학생 추가 버튼
                      width: 32,  // 최소 넓이 지정
                      height: 32,
                      child: OutlinedButton(
                        onPressed: () => _showStudentDialog(context),
                        child: Icon(Icons.person_add, size: 16),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,  // 패딩 제거
                          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 4),
                    Container(  // 선생님 선택 버튼
                      width: 32,  // 최소 넓이 지정
                      height: 32,
                      child: TextButton(
                        onPressed: () => _showTeacherDialog(context),
                        child: Icon(Icons.school, size: 16),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,  // 패딩 제거
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
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
                      onTap: selectedYear == null || selectedMonth == null || selectedStudent == null
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
}