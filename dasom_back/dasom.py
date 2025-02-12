from flask import Flask, request, Response, jsonify
import json
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Firebase Admin SDK 인증
cred = credentials.Certificate("dasom-771e7-firebase-adminsdk-fbsvc-6dfc067219.json")
firebase_admin.initialize_app(cred)

# Firestore 데이터베이스 클라이언트
db = firestore.client()

app = Flask(__name__)

# 선생님 목록을 반환하는 API
@app.route('/teachers', methods=['GET'])
def get_teachers():
    teachers_ref = db.collection('teachers')
    teachers = teachers_ref.stream()

    teacher_list = []
    for teacher in teachers:
        teacher_list.append(teacher.to_dict())

    return jsonify(teacher_list)

# 선생님 등록 API (선생님의 이름을 받아서 등록)
@app.route('/teachers', methods=['POST'])
def add_teacher():
    data = request.get_json()

    teacher_name = data.get('name')

    if not teacher_name:
        return jsonify({"message": "선생님의 이름을 입력해 주세요."}), 400

    # Firestore에 선생님 등록
    teachers_ref = db.collection('teachers')
    
    # 이미 등록된 선생님인지 확인
    existing_teacher = teachers_ref.where('name', '==', teacher_name).stream()
    if any(existing_teacher):
        return jsonify({"message": "이미 등록된 선생님입니다."}), 400

    # 선생님 등록
    teachers_ref.document(teacher_name).set({
        'name': teacher_name,
        'created_at': datetime.now()
    })

    return jsonify({"message": f"선생님 {teacher_name}이(가) 등록되었습니다."}), 201

# 선생님의 시간표 조회 API (선생님과 년월을 쿼리로 받아옴)
@app.route('/teacher_schedules', methods=['GET'])
def get_schedule():
    teacher = request.args.get('teacher')
    year_month = request.args.get('year_month')

    if not teacher or not year_month:
        return jsonify({"message": "선생님과 년월을 입력해 주세요."}), 400

    # 해당 선생님의 시간표를 가져옵니다
    schedule_ref = db.collection('teacher_schedules').document(teacher).collection(year_month)
    schedule = schedule_ref.stream()

    schedule_data = []
    for entry in schedule:
        schedule_data.append(entry.to_dict())

    return Response(json.dumps(schedule_data, ensure_ascii=False), mimetype='application/json; charset=utf-8')

# 선생님의 시간표 저장 API
@app.route('/teacher_schedules', methods=['POST'])
def save_schedule():
    data = request.get_json()

    teacher = data.get('teacher')
    year_month = data.get('year_month')
    schedule = data.get('schedule')
    
    if not teacher or not year_month:
        return jsonify({"message": "선생님, 년월, 시간표 데이터를 모두 입력해 주세요."}), 400
    
    # 해당 선생님의 시간표를 저장합니다
    schedule_ref = db.collection('teacher_schedules').document(teacher).collection(year_month)
    
    # 기존 데이터 삭제 후 새로운 데이터 저장
    schedules = schedule_ref.stream()
    
    for data in schedules:
        data.reference.delete()

    for entry in schedule:
        day = entry.get('day')
        time = entry.get('time')
        day_time = day+time
        schedule_ref.document(day_time).set(entry)

    return jsonify({"message": "시간표가 저장되었습니다."}), 200

# 학생 목록을 반환하는 API
@app.route('/students', methods=['GET'])
def get_students():
    students_ref = db.collection('students')
    students = students_ref.stream()

    student_list = []
    for student in students:
        student_list.append(student.to_dict())

    return jsonify(student_list)

# 학생 등록 API (학생의 이름을 받아서 등록)
@app.route('/students', methods=['POST'])
def add_student():
    data = request.get_json()

    student_name = data.get('name')

    if not student_name:
        return jsonify({"message": "학생의 이름을 입력해 주세요."}), 400

    # Firestore에 학생 등록
    students_ref = db.collection('students')
    
    # 이미 등록된 학생인지 확인
    existing_student = students_ref.where('name', '==', student_name).stream()
    if any(existing_student):
        return jsonify({"message": "이미 등록된 학생입니다."}), 400

    # 학생 등록
    students_ref.document(student_name).set({
        'name': student_name,
        'created_at': datetime.now()
    })

    return jsonify({"message": f"학생 {student_name}이(가) 등록되었습니다."}), 201

# 학생의 시간표 조회 API (학생과 년월을 쿼리로 받아옴)
@app.route('/student_schedules', methods=['GET'])
def get_student_schedule():
    student = request.args.get('student')
    year_month = request.args.get('year_month')

    if not student or not year_month:
        return jsonify({"message": "학생과 년월을 입력해 주세요."}), 400

    # 해당 학생의 시간표를 가져옵니다
    schedule_ref = db.collection('student_schedules').document(student).collection("year_month").document(year_month)
    schedule_doc = schedule_ref.get()

    if not schedule_doc.exists:
        return jsonify({"message": "해당 문서가 존재하지 않습니다."}), 404

    # 문서의 필드 정보 가져오기
    schedule_data = schedule_doc.to_dict() or {}

    # 하위 컬렉션 가져오기 (예: lessons, timeslots 등 여러 개일 수 있음)
    sub_collections = schedule_ref.collections()
    
    for sub_col in sub_collections:
        sub_docs = sub_col.stream()
        schedule_data[sub_col.id] = [doc.to_dict() for doc in sub_docs]  # 컬렉션 데이터를 리스트로 변환

    return Response(json.dumps(schedule_data, ensure_ascii=False), mimetype='application/json; charset=utf-8')

# 학생의 시간표 저장 API
@app.route('/student_schedules', methods=['POST'])
def save_student_schedule():
    data = request.get_json()

    student = data.get('student')
    year_month = data.get('year_month')
    teachers = data.get('teachers')
    schedule = data.get('schedule')
    
    if not student or not year_month:
        return jsonify({"message": "학생, 년월, 시간표 데이터를 모두 입력해 주세요."}), 400
    
    # 해당 학생의 시간표를 저장합니다
    schedule_ref = db.collection('student_schedules').document(student).collection('year_month').document(year_month)
    
    # 기존 데이터 삭제 후 새로운 데이터 저장
    subcollections = ["teachers","schedule"]
    
    for subcollection in subcollections:
        docs = schedule_ref.collection(subcollection).stream()
        for doc in docs:
            doc.reference.delete()  # 🔥 개별 문서 삭제
    
    schedule_ref.set({'teachers':teachers})

    for entry in schedule:
        day = entry.get('day')
        time = entry.get('time')
        schedule_ref.collection("schedule").document(f"{day}_{time}").set(entry)
        
    return jsonify({"message": "시간표가 저장되었습니다."}), 200

@app.route('/generate_schedule', methods=['POST'])
def generate_schedule():
    data = request.get_json()
    year_month = data.get('year_month')
    
    if not year_month:
        return jsonify({"message": "년월을 입력해 주세요."}), 400
        
    try:
        # 1. 해당 월의 날짜 정보 계산
        from calendar import monthrange
        year, month = map(int, year_month.split('-'))
        _, last_day = monthrange(year, month)

        # 요일 매핑
        day_mapping = {
            0: '월', 1: '화', 2: '수', 3: '목', 
            4: '금', 5: '토', 6: '일'
        }

        # 2. 선생님 스케줄 가져오기
        teachers_ref = db.collection('teachers')
        teachers = teachers_ref.stream()
        
        teacher_schedules = {}
        for teacher in teachers:
            schedule_ref = db.collection('teacher_schedules').document(teacher.id).collection(year_month)
            schedules = schedule_ref.stream()
            teacher_schedules[teacher.id] = [s.to_dict() for s in schedules]

        #print(teacher_schedules)
        
        # 3. 학생 스케줄 가져오기
        students_ref = db.collection('students')
        students = students_ref.stream()
        
        student_schedules = {}
        for student in students:
            schedule_ref = db.collection('student_schedules').document(student.id).collection('year_month').document(year_month)
            schedule_doc = schedule_ref.get()
            if schedule_doc.exists:
                schedule_data = schedule_doc.to_dict() or {}
                
                # 하위 컬렉션 데이터 가져오기
                sub_collections = schedule_ref.collections()
                for sub_col in sub_collections:
                    sub_docs = sub_col.stream()
                    schedule_data[sub_col.id] = [doc.to_dict() for doc in sub_docs]
                
                student_schedules[student.id] = {
                    'teachers': schedule_data.get('teachers', []),
                    'schedule': schedule_data.get('schedule', [])
                }

        #print(student_schedules)
        
        # 4. 기존 매칭 정보 가져오기
        existing_matches = {}
        matched_ref = db.collection('matched_schedules').document(year_month)
        teacher_collections = matched_ref.collections()
        
        for teacher_col in teacher_collections:
            teacher_id = teacher_col.id
            existing_matches[teacher_id] = []
            for doc in teacher_col.stream():
                match_data = doc.to_dict()
                existing_matches[teacher_id].append({
                    'day': match_data.get('day'),
                    'time': match_data.get('time')
                })

        print(existing_matches)

        # 5. 날짜별 매칭 생성
        new_matches = []
        
        for day in range(1, last_day + 1):
            current_date = datetime(year, month, day)
            weekday = day_mapping[current_date.weekday()]
            
            # 각 학생에 대해
            for student_id, student_data in student_schedules.items():
                preferred_teachers = student_data['teachers']
                student_times = [s for s in student_data['schedule'] if s.get('day') == weekday]
                
                # 선호하는 선생님들에 대해
                for teacher_id in preferred_teachers:
                    if teacher_id not in teacher_schedules:
                        continue
                        
                    # 선생님의 해당 요일 가능 시간
                    teacher_times = [s for s in teacher_schedules[teacher_id] if s.get('day') == weekday]
                    
                    # 기존 매칭 확인
                    teacher_existing_times = [m for m in existing_matches.get(teacher_id, []) 
                                           if m.get('day') == day]
                    
                    # 가능한 시간 매칭
                    for student_slot in student_times:
                        student_time = student_slot.get('time')
                        
                        # 선생님 가능 시간과 매칭
                        for teacher_slot in teacher_times:
                            teacher_time = teacher_slot.get('time')
                            
                            if student_time == teacher_time:
                                # 기존 매칭과 중복 체크
                                if not any(m.get('time') == teacher_time for m in teacher_existing_times):
                                    new_matches.append({
                                        'teacher': teacher_id,
                                        'student': student_id,
                                        'day': day,
                                        'time': teacher_time
                                    })
                                    # 중복 방지를 위해 기존 매칭에 추가
                                    if teacher_id not in existing_matches:
                                        existing_matches[teacher_id] = []
                                    existing_matches[teacher_id].append({
                                        'day': day,
                                        'time': teacher_time
                                    })
                                    break
                        else:
                            continue
                        break

        # 6. 새로운 매칭 저장
        # 선생님별로 그룹화
        teacher_matches = {}
        for match in new_matches:
            teacher_id = match['teacher']
            if teacher_id not in teacher_matches:
                teacher_matches[teacher_id] = {}
            
            # 년월별로 그룹화
            if year_month not in teacher_matches[teacher_id]:
                teacher_matches[teacher_id][year_month] = {}
            
            # 학생별로 그룹화
            student_id = match['student']
            if student_id not in teacher_matches[teacher_id][year_month]:
                teacher_matches[teacher_id][year_month][student_id] = {}
            
            # 일자별로 저장
            day = match['day']
            teacher_matches[teacher_id][year_month][student_id][str(day)] = {
                'day_of_week': day_mapping[datetime(year, month, day).weekday()],
                'time': match['time']
            }

        # Firestore에 저장
        for teacher_id, teacher_data in teacher_matches.items():
            for ym, year_month_data in teacher_data.items():
                for student_id, student_data in year_month_data.items():
                    # 경로: teachers/{teacher_id}/{year_month}/{student_id}
                    doc_ref = db.collection('matched_schedules')\
                              .document(teacher_id)\
                              .collection(year_month)\
                              .document(student_id)
                    
                    # 일자별 데이터 저장
                    doc_ref.set(student_data)

        return jsonify(new_matches)

    except Exception as e:
        print(f"Error generating schedule: {str(e)}")
        return jsonify({"message": f"스케줄 생성 중 오류가 발생했습니다: {str(e)}"}), 500

@app.route('/matched_schedules', methods=['GET'])
def get_matched_schedules():
    teacher_name = request.args.get('teacher')
    year_month = request.args.get('year_month')

    if not teacher_name or not year_month:
        return jsonify({"message": "선생님과 년월을 입력해 주세요."}), 400

    try:
        matched_ref = db.collection('matched_schedules').document(teacher_name).collection(year_month)
        schedules = []
        
        year, month = map(int, year_month.split('-'))
        
        for student_doc in matched_ref.stream():
            student_data = student_doc.to_dict()
            student_id = student_doc.id
            
            # 각 일자별 데이터 처리
            for day, day_data in student_data.items():
                date_str = f"{year}-{month:02d}-{int(day):02d}T00:00:00Z"
                schedules.append({
                    'student': student_id,
                    'day': day_data['day_of_week'],
                    'time': date_str
                })

        return jsonify(schedules)

    except Exception as e:
        print(f"Error fetching schedules: {str(e)}")
        return jsonify({"message": f"스케줄 조회 중 오류가 발생했습니다: {str(e)}"}), 500           

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)