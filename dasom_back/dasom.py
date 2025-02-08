from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta

cred = credentials.Certificate("dasom-771e7-firebase-adminsdk-fbsvc-6dfc067219.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

app = Flask(__name__)

def generate_monthly_timetable():
    days_in_month = 30  
    timetable = {}

    for day in range(1, days_in_month + 1):
        timetable[str(day)] = {
            "schedule": []  
        }

    return timetable

@app.route('/teachers', methods=['GET', 'POST'])
def handle_teacher_schedule():
    if request.method == 'POST':
        data = request.json
        db.collection('teachers').add(data)

        return jsonify({"message": "Teachers schedule added"}), 201
    
    elif request.method == 'GET':
        teachers_ref = db.collection('teachers').stream()
        teachers = [
            {**doc.to_dict(), "id": doc.id}  
            for doc in teachers_ref
        ]

        return jsonify(teachers), 200


@app.route('/students', methods=['POST'])
def add_student():
    data = request.json
    db.collection('students').add(data)
    return jsonify({"message": "Student schedule added"}), 201

@app.route('/schedules', methods=['GET'])
def get_schedules():
    month = request.args.get('month', type=int)
    schedules_ref = db.collection('schedules').where('month', '==', month).stream()
    schedules = [{**doc.to_dict(), 'id': doc.id} for doc in schedules_ref]
    return jsonify(schedules), 200

@app.route('/generate_timetable', methods=['POST'])
def generate_timetable():
 
    monthly_timetable = generate_monthly_timetable()
    timetable_ref = db.collection('timetables').document('month_1')  
    timetable_ref.set(monthly_timetable)

    return jsonify({"message": "Monthly timetable generated", "timetable": monthly_timetable}), 201


@app.route('/update_timetable', methods=['POST'])
def update_timetable():
    data = request.get_json()
    date = data['date']  
    updated_schedule = data['schedule']  

    timetable_ref = db.collection('timetables').document('month_1')
    timetable = timetable_ref.get().to_dict()

    if date in timetable:
        timetable[date]['schedule'] = updated_schedule
        timetable_ref.set(timetable)

        return jsonify({"message": "Timetable for day {date} updated", "updated_schedule": updated_schedule}), 200
    else:
        return jsonify({"message": "Date not found"}), 404


@app.route('/get_timetable', methods=['GET'])
def get_timetable():
    date = request.args.get('date', default=None)  
    timetable_ref = db.collection('timetables').document('month_1')
    timetable = timetable_ref.get().to_dict()

    if date:
        if date in timetable:
            return jsonify({date: timetable[date]}), 200
        else:
            return jsonify({"message": "Date not found"}), 404
    else:
        return jsonify(timetable), 200

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)