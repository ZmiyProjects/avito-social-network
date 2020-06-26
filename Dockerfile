FROM python:3.8
WORKDIR /api
COPY . /api
RUN pip install --no-cache-dir -r requirements.txt
ADD ./db/create_db.sql /docker-entrypoint-initdb.d/
