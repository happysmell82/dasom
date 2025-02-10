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

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)