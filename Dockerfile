FROM python:slim-buster
COPY app.py requirements.txt ./
RUN pip install -r requirements.txt
ARG Build
#DEBUG -- RUN env
ENV BUILD=$Build
ENTRYPOINT ["sh", "-c", "python app.py ${PORT} ${BUILD}"]