import logging
import os

import requests
from flask import Flask, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

WEATHER_API_URL = (
    "https://api.open-meteo.com/v1/forecast"
    "?latitude=38.895&longitude=-77.0366&current_weather=true"
)


@app.route("/health")
def health():
    return jsonify({"status": "ok"})


@app.route("/")
def get_weather():
    try:
        resp = requests.get(WEATHER_API_URL, timeout=5)
        resp.raise_for_status()
    except requests.Timeout:
        logging.warning("Weather API timed out")
        return jsonify({"error": "upstream timeout"}), 504
    except requests.RequestException as exc:
        logging.error("Weather API error: %s", exc)
        return jsonify({"error": "upstream error"}), 502

    weather = resp.json().get("current_weather")
    if weather is None:
        return jsonify({"error": "unexpected upstream response"}), 502

    return jsonify(weather)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)
