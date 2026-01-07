import joblib
import numpy as np

MODEL_PATH = "receipt_cat_model.joblib"
CATEGORIES = ["groceries", "transportation", "utilities", "health", "entertainment", "others"]

_model = None

def _load():
    global _model
    if _model is None:
        _model = joblib.load(MODEL_PATH)
    return _model


def predict_category(text: str) -> dict:
    obj = _load()
    pipe = obj["pipeline"]
    pred = pipe.predict([text])[0]
    return {"category": str(pred)}


def update_with_feedback(text: str, correct_category: str) -> dict:
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
    return {"status": "updated"}
