from flask import Flask, jsonify
import requests

app = Flask(__name__)


@app.route("/")
def get_weather():
    url = "https://api.open-meteo.com/v1/forecast?latitude=38.895&longitude=-77.0366&current_weather=true"
    response = requests.get(url)
    weather = response.json().get("current_weather")
    return jsonify(weather)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
