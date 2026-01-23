import joblib
import numpy as np
from pathlib import Path
import threading

# Path to the model file, always relative to this file
MODEL_PATH = Path(__file__).with_name("receipt_cat_model.joblib")
CATEGORIES = ["groceries", "transportation", "utilities", "health", "entertainment", "others"]

_model = None
_model_lock = threading.Lock()  # protects training and saving


def _load():
    """
    Load the receipt categorization model once and cache it in memory.
    """
    global _model
    if _model is None:
        _model = joblib.load(MODEL_PATH)
    return _model


def predict_category(text: str) -> dict:
    """
    Predict a category for the given receipt text.
    Returns:
        {"category": "<label>"}
    """
    obj = _load()
    pipe = obj["pipeline"]
    pred = pipe.predict([text])[0]
    return {"category": str(pred)}


def update_with_feedback(text: str, correct_category: str) -> dict:
    """
    Online update of the classifier with a single feedback example.
    This function acquires a lock so concurrent updates in the same process
    do not corrupt the model file.
    """
    with _model_lock:
        obj = _load()
        pipe = obj["pipeline"]
        classes = obj["classes"]

        y = str(correct_category).strip().lower()
        if y not in classes:
            raise ValueError(f"Invalid category '{y}'. Must be one of: {classes}")

        vec = pipe.named_steps["vec"]
        clf = pipe.named_steps["clf"]
        X_vec = vec.transform([text])

        if not hasattr(clf, "classes_"):
            clf.partial_fit(X_vec, np.array([y]), classes=np.array(classes))
        else:
            clf.partial_fit(X_vec, np.array([y]))

        joblib.dump({"pipeline": pipe, "classes": classes}, MODEL_PATH)

        return {"status": "updated", "category": y}