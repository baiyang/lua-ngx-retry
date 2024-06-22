# app.py
from flask import Flask, jsonify, request, make_response,Response, send_file
import time
import logging
import random
import os
logger = logging.getLogger(__name__)

app = Flask(__name__)

@app.route('/')
def hello_world():
    name = request.args.get('name', "")
    test_key = request.headers.get("test-key")

    response = make_response(f'Hello, {name}!')
    response.headers['test-key'] = test_key
    return response

@app.route('/items/<item>')
def items(item):
    return item, 200

@app.route('/test_sleep')
def test_sleep():
    time.sleep(2)
    return jsonify({
        "ret": 0,
        "msg": "sleep function called"
    })

@app.route('/test_error')
def test_sleep_error():
    a = 1/0
    return jsonify({
        "ret": 0,
        "msg": ""
    })

# 设置全局变量
app.config['_start'] = 1
@app.route('/test_error_with_random_status')
def test_error():
    app.config['_start'] += 1

    if app.config['_start'] % 2 == 0:

        return '503', 503
    else:
        return '200', 200

@app.route("/test_post", methods = ['POST', 'PUT', 'PATCH'])
def test_post():
    data = request.get_json()
    value = data['key']
    return jsonify({
        "ret": 0,
        "value": value,
    })

@app.route("/test_post_without_body", methods = ['DELETE', 'POST', 'PUT', 'PATCH'])
def test_post_without_body():
    return jsonify({
        "ret": 0
    })

@app.route("/big_get")
def big_get():
    data = "0" * 10000
    return jsonify({
        "ret": 0,
        "msg": "post request received",
        "data": data
    })

@app.route('/auth')
def auth():
    headers = request.headers
    user_id = headers.get('user-id', "111")
    response = make_response('Response with custom header')
    response.headers['mdt-id'] = user_id
    return response

def generate_fake_data():
    for i in range(3):
        time.sleep(0.5)
        yield f"{i}\n"

@app.route('/stream', methods=['GET'])
def stream_data():
    return Response(generate_fake_data(), content_type='text/plain')


UPLOAD_FOLDER = '/tmp/filedir'
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

@app.route('/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return 'No file part', 400

    file = request.files['file']
    if file.filename == '':
        return 'No selected file', 400

    file.save(os.path.join(app.config['UPLOAD_FOLDER'], file.filename))
    return 'File uploaded successfully', 200

@app.route('/download/<filename>', methods=['GET'])
def download_file(filename):
    file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    if os.path.exists(file_path):
        return send_file(file_path, as_attachment=True)
    else:
        return 'File not found', 404