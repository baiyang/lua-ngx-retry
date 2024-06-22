ARG BASE_IMAGE=python:3.10.9-slim
FROM ${BASE_IMAGE}
WORKDIR /src


COPY requirements.txt /tmp/

RUN apt-get update && \
    apt-get install -y --allow-downgrades --fix-missing --no-install-recommends tini && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm -rf /tmp/*


RUN ls -alh && pwd

COPY app.py ./

ENTRYPOINT [ "/usr/bin/tini", "--" ]
