FROM python:slim-buster
COPY app.py requirements.txt ./
RUN pip install -r requirements.txt
RUN env
ARG BUILD
ENTRYPOINT ["sh", "-c", "python app.py ${PORT} ${BUILD}"]