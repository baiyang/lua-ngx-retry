import logging
import httpx
import tempfile
import os
import pytest
import asyncio

logging.basicConfig(level=logging.INFO)

BASE_URL = "http://127.0.0.1/test"
HTTPS_BASE_URL = "https://127.0.0.1/test"

@pytest.fixture
def temp_file():
    # 创建临时文件
    with tempfile.NamedTemporaryFile(delete=False) as temp:
        yield temp.name

    # 测试结束后自动删除临时文件
    os.remove(temp.name)

def getClient():
    return httpx.Client(base_url=BASE_URL)

def getHttp2Client(*args, **kwargs):
    return httpx.Client(base_url=HTTPS_BASE_URL, http2=True, verify=False, *args, **kwargs)

def get_with_header_and_query(client):
    query = {
        "name": u"百度"
    }
    headers = {
        "test-key": "test-value"
    }
    path = "/"
    response = client.get(path, params=query, headers=headers)
    assert response.status_code == 200
    assert response.headers['test-key'] == "test-value"
    assert response.text == f'Hello, {query["name"]}!'
    return response

def test_get_with_header_and_query():
    with getClient() as client:
        get_with_header_and_query(client)

def test_http2_get_with_header_and_query():
    with getHttp2Client() as client:
        response = get_with_header_and_query(client)
    assert response.http_version == "HTTP/2"

#测试uri中含有非英文字符
def get_items(client):
    item = u"我爱你"
    path = f"/items/{item}"
    response = client.get(path)
    assert response.text == item

def test_get_items():
    with getClient() as client:
        get_items(client)

def test_http2_get_items():
    with getHttp2Client() as client:
        get_items(client)

def get_500_error(client):
    path = "/test_error"
    response = client.get(path)
    assert response.status_code == 500
    return response

def test_get_500_error():
    with getClient() as client:
        get_500_error(client)

#测试post请求
def post_request(client):
    data = {
        "key": "value"
    }
    path = "/test_post"
    response = client.post(path, json=data)
    res_data = response.json()
    assert response.status_code == 200
    assert res_data['value'] == "value"

def test_post_request():
    with getClient() as client:
        post_request(client)

def test_http2_post_request():
    with getHttp2Client() as client:
        post_request(client)

def test_http2_post_request_without_body():
    with getHttp2Client() as client:
        path = "/test_post_without_body"
        response = client.post(path)
        assert response.status_code == 200

def test_post_request_without_body():
    with getClient() as client:
        path = "/test_post_without_body"
        response = client.post(path)
        assert response.status_code == 200

def test_http2_get_500_error():
    with getHttp2Client() as client:
        response = get_500_error(client)
    assert response.http_version == "HTTP/2"

# 重试机制
def test_http2_get_error_with_random_status():
    with getHttp2Client(timeout=10) as client:
        path = "/test_error_with_random_status"
        response = client.get(path)
    assert response.status_code == 200
    assert response.http_version == "HTTP/2"

#测试上传文件
@pytest.mark.order(1)
def test_http2_upload_file(temp_file):
    # 在测试中使用temp_file
    with open(temp_file, 'w') as f:
        f.write('a' * 1024 * 10)

    files = {'file': ('tmpfile', open(temp_file, 'rb'))}
    with getHttp2Client(timeout=10) as client:
        path = "/upload"
        response = client.post(path, files=files)
    assert response.status_code == 200

#测试下载文件
@pytest.mark.order(2)
def test_http2_download_file():
    with getHttp2Client(timeout=10) as client:
        # test_http2_upload_file上传的文件
        path = "/download/tmpfile"
        response = client.get(path)
    assert response.status_code == 200

#测试stream返回
def test_stream():
    url = f"{BASE_URL}/stream"
    count = 0
    with httpx.stream("GET", url) as r:
        for chunk in r.iter_text():
            assert chunk == f"{count}\n"
            count += 1
