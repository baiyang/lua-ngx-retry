ARG BASE_IMAGE=docker.idatatlas.com/python:3.10.9-slim
FROM ${BASE_IMAGE}


WORKDIR /src


COPY requirements.txt /tmp/

RUN pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm -rf /tmp/*

