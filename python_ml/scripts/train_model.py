import sys
import os
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)

from features import build_features, FEATURE_COLUMNS


CSV_PATH = os.path.join(BASE_DIR, "data", "xauusd_m1_history.csv")
MODEL_PATH = os.path.join(BASE_DIR, "models", "xau_model.pkl")


# ================= READ HISTORICAL DATA =================
df = pd.read_csv(
    CSV_PATH,
    header=None,
    names=["date", "time", "open", "high", "low", "close", "volume"],
)

for col in ["open", "high", "low", "close", "volume"]:
    df[col] = pd.to_numeric(df[col], errors="coerce")

# ================= FEATURES =================
df = build_features(df)

# ================= LABEL: NEXT CANDLE DIRECTION =================
df["future_close"] = df["close"].shift(-1)
df["signal"] = np.where(df["future_close"] > df["close"], 1, -1)

# ================= CLEAN =================
df = df.dropna(subset=[*FEATURE_COLUMNS, "signal"])

X = df[FEATURE_COLUMNS]
y = df["signal"]

# ================= TRAIN MODEL =================
model = RandomForestClassifier(
    n_estimators=300,
    max_depth=7,
    min_samples_leaf=5,
    random_state=42,
    class_weight="balanced",
)

model.fit(X, y)

joblib.dump(model, MODEL_PATH)
print("✅ MODEL TRAINED (REAL ML – MOMENTUM + VOLATILITY BASED)")
