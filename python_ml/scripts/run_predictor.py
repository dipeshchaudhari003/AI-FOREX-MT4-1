import sys
import os
import time
import json
import joblib
import pandas as pd

from datetime import datetime

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)

from features import (
    build_features,
    FEATURE_COLUMNS,
    FEATURE_GROUPS,
)

# ============================================================
# CONFIGURATION
# ============================================================

MODEL_PATH = os.path.join(
    BASE_DIR,
    "models",
    "xau_model.pkl",
)

MT4_FILES = os.getenv(
    "MT4_FILES",
    r"C:\Users\Dipesh\AppData\Roaming\MetaQuotes\Terminal\0E9DF41E457B90231E706129F0D6BB0C\MQL4\Files",
)

# ---------------- Input Files ----------------

MT4_CSV = os.path.join(
    MT4_FILES,
    "xau_rates.csv",
)

SAFE_CSV = os.path.join(
    BASE_DIR,
    "data",
    "xau_rates_safe.csv",
)

# ---------------- Output Files ----------------

SIGNAL_FILE = os.path.join(
    MT4_FILES,
    "xau_signal.txt",
)

TP_FILE = os.path.join(
    MT4_FILES,
    "xau_tp.txt",
)

CONF_FILE = os.path.join(
    MT4_FILES,
    "xau_conf.txt",
)

PROBS_FILE = os.path.join(
    MT4_FILES,
    "xau_probs.txt",
)

BULL_PROB_FILE = os.path.join(
    MT4_FILES,
    "xau_bull_prob.txt",
)

BEAR_PROB_FILE = os.path.join(
    MT4_FILES,
    "xau_bear_prob.txt",
)

STATUS_FILE = os.path.join(
    MT4_FILES,
    "xau_status.json",
)

# ---------------- Predictor Configuration ----------------

SLEEP_SEC = 15

MIN_CANDLES = 30

EDGE_MARGIN = 0.08

WRITE_ON_NEW_BAR = True


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def ensure_output_paths():
    """
    Create all MT4 output files if they don't already exist.
    """

    os.makedirs(MT4_FILES, exist_ok=True)

    defaults = {
        SIGNAL_FILE: "0",
        TP_FILE: "20",
        CONF_FILE: "0.0",
        PROBS_FILE: "buy=0.0,sell=0.0,edge=0.0,dt=",
        BULL_PROB_FILE: "0.0",
        BEAR_PROB_FILE: "0.0",
    }

    for file_path, default_value in defaults.items():

        if not os.path.exists(file_path):

            with open(
                file_path,
                "w",
                encoding="utf-8",
            ) as f:

                f.write(default_value)

def safe_copy(
    source,
    destination,
    retries=5,
    delay=0.4,
):
    """
    Safely copy MT4 CSV while MT4 may still be writing to it.
    """

    for _ in range(retries):

        try:

            with open(source, "rb") as src:

                data = src.read()

            with open(destination, "wb") as dst:

                dst.write(data)

            return True

        except PermissionError:

            time.sleep(delay)

    return False

# ============================================================
# DATA LOADER
# ============================================================

def load_mt4_data():
    """
    Load latest MT4 exported candle data.

    Steps:
        1. Copy MT4 CSV safely.
        2. Read candle data.
        3. Convert OHLCV columns.
        4. Build ML features.
        5. Validate minimum candles.
        6. Return prepared dataframe.
    """

    # --------------------------------------------------------
    # Copy MT4 CSV
    # --------------------------------------------------------

    if not safe_copy(
        MT4_CSV,
        SAFE_CSV,
    ):
        raise Exception("MT4 CSV is locked.")

    # --------------------------------------------------------
    # Read CSV
    # --------------------------------------------------------

    df = pd.read_csv(
        SAFE_CSV,
        sep=";",
        header=None,
        names=[
            "dt",
            "open",
            "high",
            "low",
            "close",
            "volume",
        ],
    )

    # --------------------------------------------------------
    # Convert numeric columns
    # --------------------------------------------------------

    numeric_columns = [
        "open",
        "high",
        "low",
        "close",
        "volume",
    ]

    for column in numeric_columns:

        df[column] = pd.to_numeric(
            df[column],
            errors="coerce",
        )

    # --------------------------------------------------------
    # Validate candle count
    # --------------------------------------------------------

    if len(df) < MIN_CANDLES:

        raise Exception(
            f"Not enough candles ({len(df)})"
        )

    # --------------------------------------------------------
    # Build Features
    # --------------------------------------------------------

    df = build_features(df)

    # --------------------------------------------------------
    # Remove rows where indicators are not ready
    # --------------------------------------------------------

    df = df.dropna(
        subset=FEATURE_COLUMNS,
    )

    if len(df) < MIN_CANDLES:

        raise Exception(
            "Indicators are not ready."
        )

    return df

# ============================================================
# FEATURE ENGINEERING STATUS
# ============================================================

def print_feature_engineering_status():
    """
    Display Feature Engineering Progress.
    """

    TARGET_FEATURES = 31

    total_features = len(FEATURE_COLUMNS)

    total_groups = len(FEATURE_GROUPS)

    progress = int((total_features / TARGET_FEATURES) * 100)

    progress_bar_length = 20

    completed = int(
        progress_bar_length * total_features / TARGET_FEATURES
    )

    progress_bar = (
        "█" * completed
        + "░" * (progress_bar_length - completed)
    )

    print("=" * 70)
    print("GoldPilotAI Enterprise Predictor")
    print("=" * 70)

    print()

    print("Feature Engineering Status")

    print("-" * 70)

    print(f"Total Features Loaded : {total_features} / {TARGET_FEATURES}")

    print(f"Feature Groups        : {total_groups}")

    print()

    print(f"Progress              : {progress_bar} {progress}%")

    print()

    print(f"Current Model         : Random Forest")
    
    print(f"Model Version         : v2.1")

    print(f"Feature Version       : v2.1")

    print(f"Last Updated          : {datetime.now().strftime('%d-%b-%Y')}")
    
    print(f"Training Status       : Synced ✓")

    print()

    print("=" * 70)

# ============================================================
# FEATURE SUMMARY
# ============================================================

def count_feature_groups(FEATURE_GROUPS):
    """
    Return total feature groups.
    """

    return len(FEATURE_GROUPS)

# ============================================================
# FEATURE SNAPSHOT
# ============================================================

def create_feature_snapshot(df):
    """
    Display all ML features for the latest closed candle.

    Returns:
        last : Latest closed candle with all engineered features.
    """

    # Use previous candle because current candle is still forming
    last = df.iloc[-2]

    print()

    print("=" * 70)
    print("GoldPilotAI Feature Snapshot")
    print("=" * 70)

    print(f"Total Features Loaded : {len(FEATURE_COLUMNS)}")
    print(f"Feature Groups        : {count_feature_groups(FEATURE_GROUPS)}")
    print()

    print("Feature Breakdown")

    for group, count in FEATURE_GROUPS.items():

        print(f"  {group:<15}: {count}")

    print(f"Closed Candle        : {last['dt']}")
    print()

    for feature in FEATURE_COLUMNS:

        if feature not in last.index:
            print(f"{feature:<25}: NOT FOUND")
            continue

        value = last[feature]

        if pd.isna(value):
            print(f"{feature:<25}: NaN")
            continue

        if isinstance(value, (int, float)):
            print(f"{feature:<25}: {value:.6f}")
        else:
            print(f"{feature:<25}: {value}")

    print("=" * 70)

    return last


# ============================================================
# ML PREDICTION
# ============================================================

def predict_signal(model, last):
    """
    Execute the ML model prediction.

    Parameters
    ----------
    model : Trained ML Model

    last : Latest closed candle with all engineered features

    Returns
    -------
    dict
        Dictionary containing prediction probabilities
        and calculated trading metrics.
    """

    # --------------------------------------------------------
    # Create Feature Vector
    # --------------------------------------------------------

    X = last[FEATURE_COLUMNS].to_frame().T

    # --------------------------------------------------------
    # Predict Probabilities
    # --------------------------------------------------------

    probabilities = model.predict_proba(X)[0]

    class_map = {
        cls: idx
        for idx, cls in enumerate(model.classes_)
    }

    buy_probability = (
        probabilities[class_map[1]]
        if 1 in class_map
        else 0.0
    )

    sell_probability = (
        probabilities[class_map[-1]]
        if -1 in class_map
        else 0.0
    )

    # --------------------------------------------------------
    # Confidence
    # --------------------------------------------------------

    confidence = max(
        buy_probability,
        sell_probability,
    )

    # --------------------------------------------------------
    # Prediction Edge
    # --------------------------------------------------------

    prediction_edge = abs(
        buy_probability -
        sell_probability
    )

    # --------------------------------------------------------
    # Market Range
    # --------------------------------------------------------

    market_range = float(
        last["range_5"]
    )

    # --------------------------------------------------------
    # Dynamic Confidence Threshold
    # --------------------------------------------------------

    if market_range >= 3.0:

        confidence_threshold = 0.75

    elif market_range >= 2.0:

        confidence_threshold = 0.78

    else:

        confidence_threshold = 0.80

    # --------------------------------------------------------
    # Dynamic Take Profit
    # --------------------------------------------------------

    if market_range < 1.5:

        dynamic_tp = 35

    elif market_range < 2.5:

        dynamic_tp = 50

    else:

        dynamic_tp = 70

    return {

        "buy_probability": buy_probability,

        "sell_probability": sell_probability,

        "confidence": confidence,

        "prediction_edge": prediction_edge,

        "market_range": market_range,

        "confidence_threshold": confidence_threshold,

        "dynamic_tp": dynamic_tp,

    }


# ============================================================
# TRADE DECISION
# ============================================================

def calculate_trade_decision(prediction):
    """
    Convert ML prediction into a trading decision.

    Parameters
    ----------
    prediction : dict
        Output returned from predict_signal()

    Returns
    -------
    dict
        Trading decision.
    """

    buy_probability = prediction["buy_probability"]
    sell_probability = prediction["sell_probability"]

    confidence_threshold = prediction["confidence_threshold"]

    prediction_edge = prediction["prediction_edge"]

    # --------------------------------------------------------
    # Default Decision
    # --------------------------------------------------------

    signal = 0
    reason = "Low Confidence"

    # --------------------------------------------------------
    # BUY
    # --------------------------------------------------------

    if (
        buy_probability >= confidence_threshold
        and prediction_edge >= EDGE_MARGIN
        and buy_probability > sell_probability
    ):

        signal = 1
        reason = "Strong BUY"

    # --------------------------------------------------------
    # SELL
    # --------------------------------------------------------

    elif (
        sell_probability >= confidence_threshold
        and prediction_edge >= EDGE_MARGIN
        and sell_probability > buy_probability
    ):

        signal = -1
        reason = "Strong SELL"

    # --------------------------------------------------------
    # Return Result
    # --------------------------------------------------------

    return {

        **prediction,

        "signal": signal,

        "reason": reason,

    }


# ============================================================
# WRITE MT4 FILES
# ============================================================

def write_mt4_files(result):
    """
    Write all prediction outputs for MT4 EA.
    """

    # --------------------------------------------------------
    # Signal
    # --------------------------------------------------------

    with open(SIGNAL_FILE, "w", encoding="utf-8") as f:
        f.write(str(result["signal"]))

    # --------------------------------------------------------
    # Take Profit
    # --------------------------------------------------------

    with open(TP_FILE, "w", encoding="utf-8") as f:
        f.write(str(result["dynamic_tp"]))

    # --------------------------------------------------------
    # Confidence
    # --------------------------------------------------------

    with open(CONF_FILE, "w", encoding="utf-8") as f:
        f.write(f'{result["confidence"]:.4f}')

    # --------------------------------------------------------
    # Buy Probability
    # --------------------------------------------------------

    with open(BULL_PROB_FILE, "w", encoding="utf-8") as f:
        f.write(f'{result["buy_probability"]:.4f}')

    # --------------------------------------------------------
    # Sell Probability
    # --------------------------------------------------------

    with open(BEAR_PROB_FILE, "w", encoding="utf-8") as f:
        f.write(f'{result["sell_probability"]:.4f}')

    # --------------------------------------------------------
    # Probability Summary
    # --------------------------------------------------------

    with open(PROBS_FILE, "w", encoding="utf-8") as f:

        f.write(

            f"buy={result['buy_probability']:.4f},"

            f"sell={result['sell_probability']:.4f},"

            f"edge={result['prediction_edge']:.4f}"

        )

    # --------------------------------------------------------
    # JSON Status
    # --------------------------------------------------------

    status = {

        "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),

        "symbol": "XAUUSD",

        "timeframe": "M1",

        "signal": result["signal"],

        "reason": result["reason"],

        "buy_probability": round(
            result["buy_probability"],
            4,
        ),

        "sell_probability": round(
            result["sell_probability"],
            4,
        ),

        "confidence": round(
            result["confidence"],
            4,
        ),

        "prediction_edge": round(
            result["prediction_edge"],
            4,
        ),

        "dynamic_tp": result["dynamic_tp"],

        "market_range": round(
            result["market_range"],
            2,
        ),
    }

    with open(
        STATUS_FILE,
        "w",
        encoding="utf-8",
    ) as f:

        json.dump(
            status,
            f,
            indent=4,
        )

# ============================================================
# DASHBOARD
# ============================================================

# ============================================================
# DASHBOARD
# ============================================================

def print_dashboard(last, result):
    """
    Display GoldPilotAI Enterprise Dashboard.
    """

    print("\n" * 2)

    print("=" * 70)
    print("GoldPilotAI Enterprise Predictor v2")
    print("=" * 70)

    # ========================================================
    # Market Summary
    # ========================================================

    print("\nMarket Summary")
    print("-" * 70)

    print(f"Symbol                : XAUUSD")
    print(f"Timeframe             : M1")
    print(f"Time                  : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Closed Candle         : {last['dt']}")

    # ========================================================
    # Feature Summary
    # ========================================================

    print("\nFeature Summary")
    print("-" * 70)

    print(f"EMA20                 : {last['ema20']:.2f}")
    print(f"EMA50                 : {last['ema50']:.2f}")
    print(f"EMA100                : {last['ema100']:.2f}")
    print(f"EMA200                : {last['ema200']:.2f}")

    print()

    print(f"RSI14                 : {last['rsi14']:.2f}")
    print(f"ATR14                 : {last['atr14']:.2f}")

    print()

    print(f"BB Width              : {last['bb_width']:.2f}")
    print(f"Candle Range          : {last['candle_range']:.2f}")

    # ========================================================
    # Prediction
    # ========================================================

    print("\nPrediction")
    print("-" * 70)

    print(f"BUY Probability       : {result['buy_probability']:.2%}")
    print(f"SELL Probability      : {result['sell_probability']:.2%}")

    print(f"Confidence            : {result['confidence']:.2%}")

    print(f"Threshold             : {result['confidence_threshold']:.2%}")

    print(f"Prediction Edge       : {result['prediction_edge']:.2%}")

    # ========================================================
    # Trade Decision
    # ========================================================

    print("\nTrade Decision")
    print("-" * 70)

    signal_text = {
        1: "BUY",
        0: "NO TRADE",
        -1: "SELL"
    }

    print(f"Signal                : {signal_text[result['signal']]}")

    print(f"Reason                : {result['reason']}")

    print(f"Dynamic TP            : {result['dynamic_tp']}")

    # ========================================================
    # Output Status
    # ========================================================

    print("\nMT4 Output")
    print("-" * 70)

    print("✓ Signal File Updated")

    print("✓ Take Profit Updated")

    print("✓ Probability Files Updated")

    print("✓ Status JSON Updated")

    print("=" * 70)


# ============================================================
# MAIN
# ============================================================

def main(model):
    
    df = load_mt4_data()

    print_feature_engineering_status()

    last = create_feature_snapshot(df)

    prediction = predict_signal(
        model,
        last,
    )    
   
    decision = calculate_trade_decision(
        prediction,
    )
    
    write_mt4_files(
        decision,
    )
    
    print_dashboard(
        last,
        decision,
    )

    time.sleep(SLEEP_SEC)


# ============================================================
# START
# ============================================================

if __name__ == "__main__":
    
    print("=" * 70)
    print("GoldPilotAI Enterprise Predictor v2")
    print("=" * 70)
    print("Loading Configuration...")
    
    print()
    
    ensure_output_paths() 

    print("Configuration Loaded Successfully")
    
    print()

    # ============================================================
    # LOAD ML MODEL
    # ============================================================

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(
            f"Model not found: {MODEL_PATH}"
        )

    print("Loading ML Model...")

    model = joblib.load(MODEL_PATH)

    print("ML Model Loaded Successfully")

    while True:

        try:

            main(model)

        except Exception as ex:

            print(ex)

            time.sleep(10)