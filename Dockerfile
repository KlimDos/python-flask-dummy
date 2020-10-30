FROM python:slim-buster
COPY app.py requirements.txt ./
RUN pip install -r requirements.txt
RUN env
ENTRYPOINT ["sh", "-c", "python app.py ${PORT} ${BUILD}"]