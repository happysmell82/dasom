import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? selectedYear;
  String? selectedMonth;
  String? selectedTeacher;
  List<String> teachers = [];
  bool isLoading = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  List<String> years = ['2025', '2026', '2027'];
  List<String> months = ['01', '02', '03', '04'];

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    selectedYear = now.year.toString();
    selectedMonth = now.month.toString().padLeft(2, '0');
    _selectedDay = now;
    _loadTeachers();
  }

  // 선생님 목록 로드
  Future<void> _loadTeachers() async {
    try {
      final response = await http.get(
        Uri.parse('http://101.101.160.223:5000/teachers'),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          teachers = List<String>.from(data.map((teacher) => teacher['name']));
        });
      }
    } catch (e) {
      print('Failed to load teachers: $e');
    }
  }

  // 선생님 선택 시 자동으로 스케줄 로드
  void _onTeacherChanged(String? value) {
    setState(() {
      selectedTeacher = value;
      if (selectedTeacher != null) {
        _loadMatchedSchedules();
      }
    });
  }

  Future<void> _loadMatchedSchedules() async {
    if (selectedTeacher == null || selectedYear == null || selectedMonth == null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'http://101.101.160.223:5000/matched_schedules?teacher=${Uri.encodeComponent(selectedTeacher!)}&year_month=$selectedYear-$selectedMonth'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        //print(data);
        setState(() {
          _events = _groupSchedulesByDate(List<Map<String, dynamic>>.from(data));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('스케줄 로드 중 오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupSchedulesByDate(List<Map<String, dynamic>> schedules) {
    Map<DateTime, List<Map<String, dynamic>>> grouped = {};
    
    // 현재 선택된 년월의 첫날과 마지막 날 계산 (UTC로 생성)
    DateTime firstDay = DateTime.utc(int.parse(selectedYear!), int.parse(selectedMonth!));
    DateTime lastDay = DateTime.utc(int.parse(selectedYear!), int.parse(selectedMonth!) + 1, 0);
    
    // 요일 매핑
    Map<String, int> dayMapping = {
      '월': DateTime.monday,
      '화': DateTime.tuesday,
      '수': DateTime.wednesday,
      '목': DateTime.thursday,
      '금': DateTime.friday,
      '토': DateTime.saturday,
      '일': DateTime.sunday,
    };
    
    // 해당 월의 모든 날짜에 대해 (UTC 날짜 사용)
    for (DateTime date = firstDay; date.isBefore(lastDay.add(Duration(days: 1))); date = date.add(Duration(days: 1))) {
      // UTC 날짜로 변환
      final utcDate = DateTime.utc(date.year, date.month, date.day);
      
      // 해당 날짜의 요일 가져오기
      String dayName = _getDayName(utcDate.weekday);
      
      // 해당 요일의 스케줄 찾기
      var daySchedules = schedules.where((schedule) {
        String scheduleDay = schedule['day'];
        return dayName == scheduleDay;
      }).toList();
      
      if (daySchedules.isNotEmpty) {
        grouped[utcDate] = daySchedules.map((schedule) => {
          'student': schedule['student'],
          'time': schedule['time']
        }).toList();
      }
    }
    
    return grouped;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return '월';
      case DateTime.tuesday: return '화';
      case DateTime.wednesday: return '수';
      case DateTime.thursday: return '목';
      case DateTime.friday: return '금';
      case DateTime.saturday: return '토';
      case DateTime.sunday: return '일';
      default: return '';
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  // 스케줄 생성 함수
  Future<void> _generateSchedule() async {
    if (selectedYear == null || selectedMonth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('년월을 선택해주세요.')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://101.101.160.223:5000/generate_schedule'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          'year_month': '$selectedYear-$selectedMonth',
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('스케줄이 생성되었습니다.')),
        );
        if (selectedTeacher != null) {
          await _loadMatchedSchedules();  // 현재 선택된 선생님의 스케줄 다시 로드
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('스케줄 생성에 실패했습니다.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildDayCell(DateTime date, List<Map<String, dynamic>> events) {
    return Container(
      margin: EdgeInsets.all(1),
      padding: EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (context, index) {
                print(events);
                final event = events[index];
                return Container(
                  padding: EdgeInsets.all(2),
                  margin: EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '${event['student']}\n${event['time']}',
                    style: TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('수업 시간표')),
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
                      if (selectedTeacher != null) {
                        _loadMatchedSchedules();
                      }
                    });
                  },
                  items: years.map((year) => DropdownMenuItem(
                    value: year,
                    child: Text(year),
                  )).toList(),
                ),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedMonth,
                  hint: Text('월'),
                  onChanged: (value) {
                    setState(() {
                      selectedMonth = value;
                      if (selectedTeacher != null) {
                        _loadMatchedSchedules();
                      }
                    });
                  },
                  items: months.map((month) => DropdownMenuItem(
                    value: month,
                    child: Text(month),
                  )).toList(),
                ),
                SizedBox(width: 10),
                DropdownButton<String>(
                  value: selectedTeacher,
                  hint: Text('선생님 선택'),
                  onChanged: _onTeacherChanged,
                  items: teachers.map((teacher) => DropdownMenuItem(
                    value: teacher,
                    child: Text(teacher),
                  )).toList(),
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: isLoading ? null : _generateSchedule,
                  child: isLoading 
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text('시간표 생성'),
                ),
              ],
            ),
            SizedBox(height: 20),
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: TableCalendar(
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2027, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  eventLoader: (day) => _events[day] ?? [],
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      print(date);
                      return _buildDayCell(date, _events[date] ?? []);
                    },
                    selectedBuilder: (context, date, _) {
                      return _buildDayCell(date, _events[date] ?? []);
                    },
                    todayBuilder: (context, date, _) {
                      return _buildDayCell(date, _events[date] ?? []);
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    cellMargin: EdgeInsets.all(1),
                    cellPadding: EdgeInsets.zero,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}