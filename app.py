from flask import Flask, jsonify
import sys
import logging

## Uncomment to write logs
# logging.basicConfig(
#     filename="/opt/logs/application.log",
#     level=logging.DEBUG,
#     format='%(asctime)s %(name)s %(levelname)s %(message)s', 
#     )

if len(sys.argv) > 1:
    port = sys.argv[1]
else:
    port = "8080"

if len(sys.argv) > 2:
    build = sys.argv[2]
else:
    build = "--"

app = Flask(__name__)
@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def catch_all(path):
    message = {
        "app": "Contenttech application for Mark",
        "version": build
    }
    return (jsonify(message))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=port)

