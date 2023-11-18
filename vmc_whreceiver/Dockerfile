# Basic Docker image for VMconf WH Receiver

FROM python:3.8.10

RUN export DEBIAN_FRONTEND=noninteractive && apt-get update \
&& apt-get install -y --no-install-recommends
RUN mkdir /usr/src/app
WORKDIR /usr/src/app
COPY ./requirements.txt .
RUN pip3 install -r requirements.txt
ENV PYTHONUNBUFFERED 1
COPY . /usr/src/app/

CMD ["python3", "start_whreceiver.py"]