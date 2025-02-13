import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/rendering.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with AutomaticKeepAliveClientMixin {
  String? selectedYear;
  String? selectedMonth;
  String? selectedTeacher;
  List<Map<String, dynamic>> teachers = [];
  bool isLoading = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _events = {};

  List<String> years = ['2025', '2026', '2027'];
  List<String> months = ['01', '02', '03', '04'];

  // 타입 명시적 선언
  List<List<dynamic>> schedule = List.generate(7, (_) => List.filled(14, null));
  List<Map<String, dynamic>> teacherSchedules = [];
  List<Map<String, dynamic>> studentSchedules = [];

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    selectedYear = now.year.toString();
    selectedMonth = now.month.toString().padLeft(2, '0');
    _selectedDay = now;
    _loadTeachers();
  }

  @override
  bool get wantKeepAlive => true;  // 상태 유지를 위한 오버라이드

  // 선생님 목록 로드
  Future<void> _loadTeachers() async {
    try {
      final response = await http.get(
        Uri.parse('http://101.101.160.223:5000/teachers'),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          teachers = List<Map<String, dynamic>>.from(data);
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
      } else {
        _events.clear();  // 선생님 선택이 해제되면 이벤트 초기화
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
    
    // 각 스케줄을 날짜별로 그룹화
    for (var schedule in schedules) {
      try {
        // 스케줄의 날짜(일)를 정수로 변환
        int scheduleDay = int.parse(schedule['date']);
        // 현재 선택된 년월과 스케줄의 일을 조합하여 DateTime 생성
        DateTime scheduleDate = DateTime(
          int.parse(selectedYear!),
          int.parse(selectedMonth!),
          scheduleDay
        );
        final utcDate = DateTime.utc(scheduleDate.year, scheduleDate.month, scheduleDate.day);
        
        if (!grouped.containsKey(utcDate)) {
          grouped[utcDate] = [];
        }
        
        grouped[utcDate]!.add({
          'student': schedule['student'],
          'time': schedule['time']
        });
      } catch (e) {
        print('Error parsing date: ${schedule['date']} - $e');
        continue;
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
      width: double.infinity,  // 전체 넓이 사용
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        color: events.isNotEmpty ? 
          Theme.of(context).colorScheme.primaryContainer : 
          Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          if (events.isNotEmpty)
            Expanded(
              child: Container(  // Container로 감싸서 넓이 제어
                width: double.infinity,  // 전체 넓이 사용
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Container(
                      width: double.infinity,  // 전체 넓이 사용
                      padding: EdgeInsets.all(2),
                      margin: EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${event['student']}',
                        style: TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);  // AutomaticKeepAliveClientMixin 사용시 필수
    return Scaffold(
      appBar: AppBar(title: Text('수업 시간표')),
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
                      height: 32,
                      child: _buildDropdown(
                        value: selectedYear,
                        hint: '년도',
                        items: years,
                        onChanged: (value) {
                          setState(() {
                            selectedYear = value;
                            _clearSchedule();
                            if (selectedTeacher != null) {
                              _loadMatchedSchedules();  // 기존 스케줄 로드
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 6),
                    SizedBox(  // 월 선택
                      width: 60,
                      height: 32,
                      child: _buildDropdown(
                        value: selectedMonth,
                        hint: '월',
                        items: months,
                        onChanged: (value) {
                          setState(() {
                            selectedMonth = value;
                            _clearSchedule();
                            if (selectedTeacher != null) {
                              _loadMatchedSchedules();  // 기존 스케줄 로드
                            }
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(  // 선생님 선택
                      child: SizedBox(
                        height: 32,
                        child: _buildDropdown(
                          value: selectedTeacher,
                          hint: '선생님 선택',
                          items: teachers,
                          onChanged: (value) {
                            setState(() {
                              selectedTeacher = value;
                              _clearSchedule();
                              if (value != null) {
                                _loadMatchedSchedules();  // 기존 스케줄 로드
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(  // 시간표 생성 버튼
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: (isLoading || selectedYear == null || 
                                   selectedMonth == null) ? null : _generateSchedule,
                        icon: isLoading 
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : Icon(Icons.add_chart_outlined, size: 16),
                        label: Text(
                          '생성',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.9),
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
            SizedBox(height: 20),
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: TableCalendar(
                  firstDay: DateTime(int.parse(selectedYear!), int.parse(selectedMonth!), 1),
                  lastDay: DateTime(int.parse(selectedYear!), int.parse(selectedMonth!) + 1, 0),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: null,
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  eventLoader: _getEventsForDay,
                  rowHeight: 80,
                  calendarStyle: CalendarStyle(
                    cellMargin: EdgeInsets.all(1),
                    cellPadding: EdgeInsets.zero,
                    markerSize: 0,
                    markersMaxCount: 0,
                    markerMargin: EdgeInsets.zero,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      final utcDate = DateTime.utc(date.year, date.month, date.day);
                      return _buildDayCell(date, _events[utcDate] ?? []);
                    },
                    selectedBuilder: (context, date, _) {
                      final utcDate = DateTime.utc(date.year, date.month, date.day);
                      return _buildDayCell(date, _events[utcDate] ?? []);
                    },
                    todayBuilder: (context, date, _) {
                      final utcDate = DateTime.utc(date.year, date.month, date.day);
                      return _buildDayCell(date, _events[utcDate] ?? []);
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

  // 데이터 초기화를 위한 메서드 추가
  void _clearScheduleIfNeeded() {
    setState(() {
      schedule = List.generate(7, (_) => List.filled(14, null));
      teacherSchedules.clear();
      studentSchedules.clear();
    });
  }

  // fetchTeacherSchedules 함수 추가
  Future<List<Map<String, dynamic>>> fetchTeacherSchedules(String teacherId, String yearMonth) async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://101.101.160.223:5000/teacher_schedules?teacher=$teacherId&year_month=$yearMonth'
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load teacher schedules');
      }
    } catch (e) {
      print('Error fetching teacher schedules: $e');
      return [];
    }
  }

  Future<void> _loadTeacherSchedules() async {
    if (selectedYear == null || selectedMonth == null || selectedTeacher == null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final data = await fetchTeacherSchedules(
        selectedTeacher!, 
        '$selectedYear-$selectedMonth'
      );
      
      if (mounted) {
        setState(() {
          teacherSchedules = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          teacherSchedules = [];
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('선생님 시간표를 불러오는데 실패했습니다.')),
        );
      }
    }
  }

  void _clearSchedule() {
    setState(() {
      schedule = List.generate(7, (_) => List.filled(14, null));
      teacherSchedules = [];
      studentSchedules = [];
    });
  }
}