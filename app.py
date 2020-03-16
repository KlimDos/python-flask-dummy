from flask import Flask
app = Flask(__name__)

@app.route('/version')
def hello_world():
    return 'Flask Dockerized'

if __name__ == '__main__':
    app.run(debug=True,host='0.0.0.0', port=8080)