from flask import Flask, jsonify
import sys

if len(sys.argv) > 1:
    port = sys.argv[1]
else:
    port = "8080"

app = Flask(__name__)
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def catch_all(path):
    message = {
        "app": "Contenttech application",
        "version": 0
    }
    return (jsonify(message))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=port)