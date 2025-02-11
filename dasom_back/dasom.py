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
        # 1. 모든 선생님의 가능 시간 가져오기
        teachers_ref = db.collection('teachers')
        teachers = teachers_ref.stream()
        
        teacher_schedules = {}
        for teacher in teachers:
            schedule_ref = db.collection('teacher_schedules').document(teacher.id).collection(year_month)
            schedules = schedule_ref.stream()
            teacher_schedules[teacher.id] = [s.to_dict() for s in schedules]

        # 2. 모든 학생의 가능 시간과 선호 선생님 가져오기
        students_ref = db.collection('students')
        students = students_ref.stream()

        print(teacher_schedules)
        
        student_schedules = {}
        for student in students:
            schedule_ref = db.collection('student_schedules').document(student.id).collection('year_month').document(year_month)
            schedule_doc = schedule_ref.get()
            if schedule_doc.exists:
                schedule_data = schedule_doc.to_dict() or {}

                sub_collections = schedule_ref.collections()
                
                for sub_col in sub_collections:
                    sub_docs = sub_col.stream()
                    schedule_data[sub_col.id] = [doc.to_dict() for doc in sub_docs]  # 컬렉션 데이터를 리스트로 변환
                
                student_schedules[student.id] = {
                    'teachers': schedule_data.get('teachers', []),
                    'schedule': schedule_data
                }

        print("////////////////////////////////////////////////////////////////")  
        
        # 3. 매칭 생성
        matched_schedules = []
        used_slots = set()  # (day, time) 튜플로 이미 사용된 시간 추적

        print("Student Schedules:", student_schedules)  # 디버깅용 출력

        # 각 학생에 대해
        for student_id, student_data in student_schedules.items():
            preferred_teachers = student_data['teachers']
            student_schedule = student_data['schedule'].get('schedule', [])  # schedule 키에서 schedule 리스트 가져오기
            
            # 학생의 가능한 시간 집합 생성
            student_available_times = set()
            for schedule_item in student_schedule:
                day = schedule_item.get('day')
                time = schedule_item.get('time')
                if day and time:
                    student_available_times.add((day, time))

            print(f"Student {student_id} available times:", student_available_times)  # 디버깅용 출력

            # 선호하는 선생님들에 대해
            for teacher_id in preferred_teachers:
                if teacher_id not in teacher_schedules:
                    continue

                teacher_schedule = teacher_schedules[teacher_id]
                
                # 선생님의 가능한 시간 집합 생성
                teacher_available_times = {(s.get('day'), s.get('time')) 
                                        for s in teacher_schedule 
                                        if s.get('day') and s.get('time')}

                print(f"Teacher {teacher_id} available times:", teacher_available_times)  # 디버깅용 출력
                
                # 학생과 선생님의 가능한 시간 중 겹치는 시간 찾기
                common_times = student_available_times.intersection(teacher_available_times)
                
                # 이미 사용된 시간 제외
                available_times = common_times - used_slots

                if available_times:
                    # 가능한 시간 중 하나 선택
                    matched_time = available_times.pop()
                    used_slots.add(matched_time)

                    # 매칭 스케줄에 추가
                    matched_schedules.append({
                        'teacher': teacher_id,
                        'student': student_id,
                        'day': matched_time[0],
                        'time': matched_time[1]
                    })

                    print(f"Matched: Teacher {teacher_id} with Student {student_id} at {matched_time}")  # 디버깅용 출력
                    break  # 한 학생당 한 선생님과만 매칭

        # 4. 생성된 스케줄 저장
        if matched_schedules:
            # 선생님별로 스케줄 그룹화
            teacher_grouped_schedules = {}
            for schedule in matched_schedules:
                teacher_id = schedule['teacher']
                if teacher_id not in teacher_grouped_schedules:
                    teacher_grouped_schedules[teacher_id] = []
                teacher_grouped_schedules[teacher_id].append({
                    'student': schedule['student'],
                    'day': schedule['day'],
                    'time': schedule['time']
                })

            # 년월 문서 아래에 선생님별로 저장
            matched_ref = db.collection('matched_schedules').document(year_month)
            
            for teacher_id, schedules in teacher_grouped_schedules.items():
                teacher_ref = matched_ref.collection(teacher_id)
                
                # 각 학생별로 문서 생성
                for schedule in schedules:
                    student_ref = teacher_ref.document(schedule['student'])
                    student_ref.set({
                        'day': schedule['day'],
                        'time': schedule['time']
                    })

        print("////////////////////////////////////////////////////////////////")  
        print(matched_schedules)    

        return jsonify(matched_schedules)
        
    except Exception as e:
        return jsonify({"message": f"오류가 발생했습니다: {str(e)}"}), 500

@app.route('/matched_schedules', methods=['GET'])
def get_matched_schedules():
    teacher_name = request.args.get('teacher')
    year_month = request.args.get('year_month')

    if not teacher_name or not year_month:
        return jsonify({"message": "선생님과 년월을 입력해 주세요."}), 400

    try:
        # 먼저 선생님 ID 찾기
        teachers_ref = db.collection('teachers')
        teacher_query = teachers_ref.where('name', '==', teacher_name).limit(1).stream()
        teacher_id = None
        
        for teacher in teacher_query:
            teacher_id = teacher.id
            break
            
        if not teacher_id:
            return jsonify({"message": "선생님을 찾을 수 없습니다."}), 404

        # matched_schedules/{year_month}/{teacher_id} 경로에서 데이터 조회
        teacher_ref = db.collection('matched_schedules').document(year_month).collection(teacher_id)
        schedules = []
        
        # 해당 선생님의 모든 학생 스케줄 조회
        for student_doc in teacher_ref.stream():
            schedule_data = student_doc.to_dict()
            
            # 학생 이름 가져오기
            student_ref = db.collection('students').document(student_doc.id).get()
            student_name = student_ref.get('name') if student_ref.exists else student_doc.id
            
            schedules.append({
                'student': student_name,  # 학생 ID 대신 이름 사용
                'day': schedule_data.get('day'),
                'time': schedule_data.get('time')
            })

        return jsonify(schedules)

    except Exception as e:
        print(f"Error fetching schedules: {str(e)}")
        return jsonify({"message": f"스케줄 조회 중 오류가 발생했습니다: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)