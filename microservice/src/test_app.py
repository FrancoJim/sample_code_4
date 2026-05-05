import requests
import pytest
from unittest.mock import Mock, patch

from app import app


@pytest.fixture
def client():
    app.testing = True
    with app.test_client() as c:
        yield c


def test_health_returns_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_weather_success(client):
    payload = {"temperature": 22.5, "windspeed": 10.2, "weathercode": 0}
    mock_resp = Mock()
    mock_resp.raise_for_status.return_value = None
    mock_resp.json.return_value = {"current_weather": payload}

    with patch("app.requests.get", return_value=mock_resp):
        resp = client.get("/")

    assert resp.status_code == 200
    assert resp.get_json()["temperature"] == 22.5


def test_weather_timeout_returns_504(client):
    with patch("app.requests.get", side_effect=requests.Timeout):
        resp = client.get("/")
    assert resp.status_code == 504


def test_weather_request_error_returns_502(client):
    with patch("app.requests.get", side_effect=requests.RequestException("fail")):
        resp = client.get("/")
    assert resp.status_code == 502


def test_weather_missing_field_returns_502(client):
    mock_resp = Mock()
    mock_resp.raise_for_status.return_value = None
    mock_resp.json.return_value = {}

    with patch("app.requests.get", return_value=mock_resp):
        resp = client.get("/")

    assert resp.status_code == 502
