import os
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, "data", "XAUUSD_M1.csv")
MODEL_PATH = os.path.join(BASE_DIR, "models", "xau_model.pkl")
FEATURES = ["ma_fast", "ma_slow", "momentum", "ret", "range_5"]


def build_features(df):
    df = df.copy()
    df["ma_fast"] = df["close"].rolling(5).mean()
    df["ma_slow"] = df["close"].rolling(20).mean()
    df["momentum"] = df["close"] - df["close"].shift(5)
    df["ret"] = df["close"].pct_change(fill_method=None)
    df["range_5"] = (df["high"] - df["low"]).rolling(5).mean()
    return df


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
df = df.dropna(subset=[*FEATURES, "signal"])

X = df[FEATURES]
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
