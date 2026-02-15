import os
import joblib
import requests
import pandas as pd
import numpy as np
import tensorflow as tf
from datetime import datetime, timedelta, timezone
from pathlib import Path
from dotenv import load_dotenv

# Load backend/.env
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")

API_KEY = os.getenv("METALPRICE_API_KEY", "")
TROY_OUNCE_TO_GRAM = 31.1034768
CARAT_MULTIPLIERS = {"24K": 1.0, "21K": 21 / 24, "18K": 18 / 24}

BASE_DIR = Path(__file__).resolve().parents[1]  # backend/
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
        timeout=30,
    )
    r.raise_for_status()
    data = r.json()
    if not data.get("success"):
        raise ValueError(data)
    return sar_per_gram_from_rates(data["rates"])


def fetch_last_n_days_df(n_days: int) -> pd.DataFrame:
    """
    Daily points up to yesterday (UTC). We'll replace last point with live price.
    """
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
            "currencies": "XAU,SAR",
        },
        timeout=30,
    )
    r.raise_for_status()
    data = r.json()
    if not data.get("success"):
        raise ValueError(data)

    rows = [
        {"date": d, "sar_per_gram": sar_per_gram_from_rates(rate)}
        for d, rate in data["rates"].items()
    ]
    df = pd.DataFrame(rows)
    df["date"] = pd.to_datetime(df["date"])
    df = df.sort_values("date").reset_index(drop=True)

    if len(df) < n_days:
        raise ValueError(f"Expected {n_days} daily points, got {len(df)}. Missing dates in API response.")
    return df


def mc_dropout_predict_distribution_24k(seq, n_samples: int = 300):
    """
    MC dropout distribution.
    We return mean/std and 25–75 interval (to match your new UI range).
    """
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
    lo = float(np.percentile(preds, 25))
    hi = float(np.percentile(preds, 75))

    return mean, std, lo, hi


def confidence_from_cv(std_sar: float, mean_sar: float):
    """
    Simple CV-based confidence.
    Adjust thresholds as you like.
    """
    cv = float(std_sar / max(abs(mean_sar), 1e-6))

    # fallback thresholds (you can tune)
    p33 = 0.006
    p66 = 0.015

    if cv <= p33:
        level = "high"
        score = 80
    elif cv <= p66:
        level = "medium"
        score = 55
    else:
        level = "low"
        score = 35

    return int(score), level, cv


def predict_next_week_all_karats(n_samples: int = 300):
    """
    Output format (no past here):
      prices[karat] = {
        current,
        predicted_tplus7_interval:{lo,hi,mean,std,percentiles,samples},
        confidence:{score_0_100, level, cv, method}
      }
    """
    load_gold_lstm()

    df_hist = fetch_last_n_days_df(_SEQ_LEN)

    current_24k = fetch_latest_24k()

    # replace last daily point with live
    df_hist.loc[df_hist.index[-1], "sar_per_gram"] = current_24k

    series = df_hist["sar_per_gram"].values.reshape(-1, 1)
    scaled = _scaler.transform(series)
    seq = scaled.reshape(1, _SEQ_LEN, 1)

    mean24, std24, lo24, hi24 = mc_dropout_predict_distribution_24k(seq, n_samples=n_samples)

    result = {
        "unit": "SAR_per_gram",
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "prices": {},
    }

    for karat, mult in CARAT_MULTIPLIERS.items():
        mean_k = mean24 * mult
        std_k = std24 * mult
        lo_k = lo24 * mult
        hi_k = hi24 * mult

        score, level, cv = confidence_from_cv(std_k, mean_k)

        result["prices"][karat] = {
            "current": current_24k * mult,
            "predicted_tplus7_interval": {
                "lo": lo_k,
                "hi": hi_k,
                "mean": mean_k,
                "std": std_k,
                "interval_percentiles": {"lo": 25, "hi": 75},
                "samples": int(n_samples),
            },
            "confidence": {
                "score_0_100": score,
                "level": level,
                "cv": cv,
                "method": "MC Dropout",
            },
        }

    return result

