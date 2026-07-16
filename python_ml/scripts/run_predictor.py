import os
import time
import joblib
import pandas as pd
import json
from datetime import datetime


# ================= PATHS =================
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, "models", "xau_model.pkl")

MT4_FILES = os.getenv(
    "MT4_FILES",
    r"C:\Users\Dipesh\AppData\Roaming\MetaQuotes\Terminal\0E9DF41E457B90231E706129F0D6BB0C\MQL4\Files",
)

MT4_CSV = os.path.join(MT4_FILES, "xau_rates.csv")
SIGNAL_FILE = os.path.join(MT4_FILES, "xau_signal.txt")
TP_FILE = os.path.join(MT4_FILES, "xau_tp.txt")
CONF_FILE = os.path.join(MT4_FILES, "xau_conf.txt")
PROBS_FILE = os.path.join(MT4_FILES, "xau_probs.txt")
SAFE_CSV = os.path.join(BASE_DIR, "data", "xau_rates_safe.csv")

BULL_PROB_FILE = os.path.join(MT4_FILES, "xau_bull_prob.txt")
BEAR_PROB_FILE = os.path.join(MT4_FILES, "xau_bear_prob.txt")

STATUS_FILE = os.path.join(MT4_FILES, "xau_status.json")

SLEEP_SEC = 15
MIN_CANDLES = 30

EDGE_MARGIN = 0.08  # require buy_p > sell_p + EDGE_MARGIN

# Only pulse once per closed candle (recommended). If False, predictor will
# re-write signal every loop while the same closed candle is active.
WRITE_ON_NEW_BAR = True


def ensure_output_paths():
    os.makedirs(MT4_FILES, exist_ok=True)
    if not os.path.exists(SIGNAL_FILE):
        with open(SIGNAL_FILE, "w", encoding="utf-8") as f:
            f.write("0")
    if not os.path.exists(TP_FILE):
        with open(TP_FILE, "w", encoding="utf-8") as f:
            f.write("20")
    if not os.path.exists(CONF_FILE):
        with open(CONF_FILE, "w", encoding="utf-8") as f:
            f.write("0.0")
    if not os.path.exists(PROBS_FILE):
        with open(PROBS_FILE, "w", encoding="utf-8") as f:
            f.write("buy=0.0,sell=0.0,edge=0.0,dt=\n")


def safe_copy(src, dst, retries=5, delay=0.4):
    for _ in range(retries):
        try:
            with open(src, "rb") as f:
                data = f.read()
            with open(dst, "wb") as f:
                f.write(data)
            return True
        except PermissionError:
            time.sleep(delay)
    return False


def build_features(df):
    df = df.copy()
    df["ma_fast"] = df["close"].rolling(5).mean()
    df["ma_slow"] = df["close"].rolling(20).mean()
    df["momentum"] = df["close"] - df["close"].shift(5)
    df["ret"] = df["close"].pct_change(fill_method=None)
    df["range_5"] = (df["high"] - df["low"]).rolling(5).mean()
    return df


if not os.path.exists(MODEL_PATH):
    raise FileNotFoundError(f"Model not found: {MODEL_PATH}")

model = joblib.load(MODEL_PATH)
print("=== FINAL XAUUSD M1 ML PREDICTOR STARTED ===")
ensure_output_paths()

while True:
    try:
        if not safe_copy(MT4_CSV, SAFE_CSV):
            print("WAIT → file locked by MT4")
            time.sleep(SLEEP_SEC)
            continue

        df = pd.read_csv(
            SAFE_CSV,
            sep=";",
            header=None,
            names=["dt", "open", "high", "low", "close", "volume"],
        )

        for col in ["open", "high", "low", "close", "volume"]:
            df[col] = pd.to_numeric(df[col], errors="coerce")

        if len(df) < MIN_CANDLES:
            print("WAIT → not enough candles")
            time.sleep(SLEEP_SEC)
            continue

        df = build_features(df)
        df = df.dropna(subset=["ma_fast", "ma_slow", "momentum", "ret", "range_5"])

        if len(df) < MIN_CANDLES:
            print("WAIT → indicators not ready")
            time.sleep(SLEEP_SEC)
            continue

        last = df.iloc[-2]
        # determine closed-candle identifier (dt column from MT4 CSV)
        current_dt = str(last["dt"]) if "dt" in last.index else str(df.index[-2])
        if WRITE_ON_NEW_BAR:
            # initialize prev_dt on first run
            if 'prev_dt' not in globals():
                prev_dt = None
            if current_dt == prev_dt:
                print("WAIT → same closed candle, skipping pulse")
                time.sleep(SLEEP_SEC)
                continue
        if last.isna().any():
            print("WAIT → indicators not ready")
            time.sleep(SLEEP_SEC)
            continue

        recent_range = float(last["range_5"])

        if recent_range >= 3.0:
            conf_threshold = 0.56
        elif recent_range >= 2.0:
            conf_threshold = 0.58
        else:
            conf_threshold = 0.60

        # Use grid-optimized TP
        if recent_range < 1.5:
            tp_points = 35
        elif recent_range < 2.5:
            tp_points = 50
        else:
            tp_points = 70

        X = pd.DataFrame(
            [[last["ma_fast"], last["ma_slow"], last["momentum"], last["ret"], last["range_5"]]],
            columns=["ma_fast", "ma_slow", "momentum", "ret", "range_5"],
        )

        proba = model.predict_proba(X)[0]
        class_to_index = {cls: idx for idx, cls in enumerate(model.classes_)}
        buy_p = proba[class_to_index[1]] if 1 in class_to_index else 0.0
        sell_p = proba[class_to_index[-1]] if -1 in class_to_index else 0.0
        edge = abs(buy_p - sell_p)

        print("\n" + "="*60)
        print("GoldPilotAI Enterprise ML Predictor")
        print("="*60)

        print(f"Time           : {datetime.now():%Y-%m-%d %H:%M:%S}")
        print(f"Closed Candle  : {current_dt}")

        print(f"BUY Probability: {buy_p:.2%}")
        print(f"SELL Probability:{sell_p:.2%}")

        print(f"Confidence     : {max(buy_p,sell_p):.2%}")
        print(f"Threshold      : {conf_threshold:.2f}")

        print(f"Market Range   : {recent_range:.2f}")
        print(f"Prediction Edge: {edge:.2f}")
        print(f"Dynamic TP     : {tp_points}")

        print("="*60)

        signal = 0
        reason = "WAIT"

        if buy_p >= conf_threshold and buy_p > sell_p + EDGE_MARGIN:
            signal = 1
            reason = "Strong BUY"

        elif sell_p >= conf_threshold and sell_p > buy_p + EDGE_MARGIN:
            signal = -1
            reason = "Strong SELL"

        else:
            reason = "Low Confidence"

        print(f"Signal         : {signal}")
        print(f"Reason         : {reason}")

        with open(SIGNAL_FILE, "w", encoding="utf-8") as f:
            f.write(str(signal))

        with open(TP_FILE, "w", encoding="utf-8") as f:
            f.write(str(tp_points))

        # write confidence (highest class probability)
        conf = max(buy_p, sell_p)
        with open(CONF_FILE, "w", encoding="utf-8") as f:
            f.write(f"{conf:.4f}")

        # Write probabilities for MT4
        with open(BULL_PROB_FILE, "w", encoding="utf-8") as f:
            f.write(f"{buy_p:.4f}")

        with open(BEAR_PROB_FILE, "w", encoding="utf-8") as f:
            f.write(f"{sell_p:.4f}")
            
        # write human-readable probs for debugging/analysis
        try:
            with open(PROBS_FILE, "w", encoding="utf-8") as f:
                f.write(f"buy={buy_p:.4f},sell={sell_p:.4f},edge={edge:.4f},dt={current_dt}\n")
        except Exception:
            pass
        
        status = {
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "symbol": "XAUUSD",
            "timeframe": "M1",
            "signal": signal,
            "reason": reason,
            "buy_probability": round(float(buy_p),4),
            "sell_probability": round(float(sell_p),4),
            "confidence": round(float(max(buy_p,sell_p)),4),
            "edge": round(float(edge),4),
            "dynamic_tp": tp_points,
            "market_range": round(float(recent_range),2)
        }

        with open(STATUS_FILE, "w") as f:
            json.dump(status, f, indent=4)
            
        # update prev_dt so we don't pulse repeatedly for same candle
        if WRITE_ON_NEW_BAR:
            prev_dt = current_dt

        print(f"Signal Written : {signal}")
        print(f"Take Profit    : {tp_points}")
        print("MT4 Files      : Updated Successfully")
        print("="*60)

        time.sleep(SLEEP_SEC)

    except Exception as e:
        print("ERROR:", e)
        time.sleep(10)
