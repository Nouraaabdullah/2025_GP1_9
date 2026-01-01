# backend/services/gold_lstm_service.py
import os
import joblib
import requests
import pandas as pd
import numpy as np
import tensorflow as tf
from datetime import datetime, timedelta, timezone
from pathlib import Path
from dotenv import load_dotenv

# Load backend/.env (same style as your main.py)
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")

API_KEY = os.getenv("METALPRICE_API_KEY", "")
TROY_OUNCE_TO_GRAM = 31.1034768
CARAT_MULTIPLIERS = {"24K": 1.0, "21K": 21/24, "18K": 18/24}

BASE_DIR = Path(__file__).resolve().parents[1]   # backend/
MODEL_DIR = BASE_DIR / "goldmodel"

_model = None
_scaler = None
_SEQ_LEN = None

def load_gold_lstm():
    global _model, _scaler, _SEQ_LEN
    if _model is None:
        _model = tf.keras.models.load_model(MODEL_DIR / "gold_lstm_next_day.keras")
        assets = joblib.load(MODEL_DIR / "gold_lstm_assets.pkl")
        _scaler = assets["scaler"]
        _SEQ_LEN = int(assets["seq_len"])

def sar_per_gram_from_rates(rate: dict) -> float:
    return (float(rate["USDXAU"]) * float(rate["SAR"])) / TROY_OUNCE_TO_GRAM

def fetch_latest_24k() -> float:
    if not API_KEY:
        raise ValueError("METALPRICE_API_KEY missing in backend/.env")

    r = requests.get(
        "https://api.metalpriceapi.com/v1/latest",
        params={"api_key": API_KEY, "base": "USD", "currencies": "XAU,SAR"},
        timeout=30
    )
    r.raise_for_status()
    data = r.json()
    if not data.get("success"):
        raise ValueError(data)
    return sar_per_gram_from_rates(data["rates"])

def fetch_last_n_days_df(n_days: int) -> pd.DataFrame:
    if not API_KEY:
        raise ValueError("METALPRICE_API_KEY missing in backend/.env")

    end_day = (datetime.now(timezone.utc).date() - timedelta(days=1))
    start_day = end_day - timedelta(days=n_days - 1)

    r = requests.get(
        "https://api.metalpriceapi.com/v1/timeframe",
        params={
            "api_key": API_KEY,
            "start_date": start_day.isoformat(),
            "end_date": end_day.isoformat(),
            "base": "USD",
            "currencies": "XAU,SAR"
        },
        timeout=30
    )
    r.raise_for_status()
    data = r.json()
    if not data.get("success"):
        raise ValueError(data)

    rows = [{"date": d, "sar_per_gram": sar_per_gram_from_rates(rate)} for d, rate in data["rates"].items()]
    df = pd.DataFrame(rows)
    df["date"] = pd.to_datetime(df["date"])
    df = df.sort_values("date").reset_index(drop=True)

    if len(df) < n_days:
        raise ValueError(f"Expected {n_days} daily points, got {len(df)}. Missing dates in API response.")
    return df

def mc_dropout_predict_distribution_24k(seq, n_samples: int = 60):
    load_gold_lstm()

    preds = []
    seq = tf.convert_to_tensor(seq, dtype=tf.float32)

    for _ in range(n_samples):
        y_scaled = float(_model(seq, training=True).numpy()[0, 0])
        y = float(_scaler.inverse_transform([[y_scaled]])[0, 0])
        preds.append(y)

    preds = np.array(preds, dtype=np.float64)
    mean = float(preds.mean())
    std = float(preds.std(ddof=1)) if n_samples > 1 else 0.0
    p10 = float(np.percentile(preds, 10))
    p90 = float(np.percentile(preds, 90))
    return mean, std, p10, p90

def confidence_from_cv(std_sar: float, mean_sar: float):
    cv = std_sar / max(abs(mean_sar), 1e-6)
    cv_low, cv_high = 0.003, 0.02

    if cv <= cv_low:
        score = 90.0
    elif cv >= cv_high:
        score = 30.0
    else:
        score = 90.0 - (cv - cv_low) * (60.0 / (cv_high - cv_low))

    score = int(round(max(0.0, min(100.0, score))))
    level = "high" if score >= 75 else "medium" if score >= 50 else "low"
    return score, level, float(cv)

def predict_tomorrow_all_karats(n_samples: int = 60):
    load_gold_lstm()

    df_hist = fetch_last_n_days_df(_SEQ_LEN)

    past_24k = float(df_hist.iloc[-1]["sar_per_gram"])
    past_date = df_hist.iloc[-1]["date"].strftime("%Y-%m-%d")

    current_24k = fetch_latest_24k()

    # Replace last daily point with current live price
    df_hist.loc[df_hist.index[-1], "sar_per_gram"] = current_24k

    series = df_hist["sar_per_gram"].values.reshape(-1, 1)
    scaled = _scaler.transform(series)
    seq = scaled.reshape(1, _SEQ_LEN, 1)

    mean24, std24, p10_24, p90_24 = mc_dropout_predict_distribution_24k(seq, n_samples=n_samples)

    result = {"unit": "SAR_per_gram", "past_price_date": past_date, "prices": {}}

    for karat, mult in CARAT_MULTIPLIERS.items():
        mean_k = mean24 * mult
        std_k = std24 * mult
        p10_k = p10_24 * mult
        p90_k = p90_24 * mult

        score, level, cv = confidence_from_cv(std_k, mean_k)

        result["prices"][karat] = {
            "past": past_24k * mult,
            "current": current_24k * mult,
            "predicted_tomorrow": mean_k,
            "prediction_interval_p10_p90": {"p10": p10_k, "p90": p90_k},
            "uncertainty_std": std_k,
            "confidence": {
                "score_0_100": score,
                "level": level,
                "cv": cv,
                "method": "MC Dropout",
                "samples": n_samples
            }
        }

    return result
