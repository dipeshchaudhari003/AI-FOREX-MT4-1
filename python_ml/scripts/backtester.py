import os
import json
import joblib
import pandas as pd
from datetime import datetime

import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)

from features import (
    build_features,
    FEATURE_COLUMNS,
    FEATURE_GROUPS,
)

# ============================================================
# BACKTEST FILTERS
# ============================================================

BACKTEST_CONFIDENCE_THRESHOLD = 0.65

BACKTEST_EDGE_MARGIN = 0.08

# ============================================================
# CONFIGURATION
# ============================================================

MODEL_PATH = os.path.join(
    BASE_DIR,
    "models",
    "xau_model.pkl",
)

HISTORICAL_DATA = os.path.join(
    BASE_DIR,
    "data",
    "xauusd_m1_history.csv",
)

REPORT_FOLDER = os.path.join(
    BASE_DIR,
    "reports",
    "backtesting",
)

REPORT_JSON = os.path.join(
    REPORT_FOLDER,
    "backtest_summary.json",
)

TRADES_CSV = os.path.join(
    REPORT_FOLDER,
    "backtest_trades.csv",
)

EQUITY_CSV = os.path.join(
    REPORT_FOLDER,
    "equity_curve.csv",
)

INITIAL_BALANCE = 10000.0

LOT_SIZE = 0.01

SPREAD = 0.30

COMMISSION = 0.00

SLIPPAGE = 0.00

BUY_SIGNAL = 1

SELL_SIGNAL = -1

NO_SIGNAL = 0

# ============================================================
# BACKTEST SETTINGS
# ============================================================

ENABLE_LONG = True

ENABLE_SHORT = True

USE_DYNAMIC_TP = True

USE_FIXED_SL = False

FIXED_STOPLOSS = 300

# ============================================================
# HELPER FUNCTIONS
# ============================================================

def print_header(title):
    """
    Print section header.
    """

    print()

    print("=" * 70)

    print(title)

    print("=" * 70)


def print_subheader(title):
    """
    Print subsection header.
    """

    print()

    print(title)

    print("-" * 70)


def create_report_directory():
    """
    Create report directory if it does not exist.
    """

    os.makedirs(
        REPORT_FOLDER,
        exist_ok=True,
    )


def current_timestamp():
    """
    Return formatted timestamp.
    """

    return datetime.now().strftime(
        "%Y-%m-%d %H:%M:%S"
    )


def current_date():
    """
    Return formatted date.
    """

    return datetime.now().strftime(
        "%d-%b-%Y"
    )


def safe_divide(a, b):
    """
    Safe division helper.
    """

    if b == 0:

        return 0.0

    return a / b

# ============================================================
# LOAD ML MODEL
# ============================================================

def load_model():
    """
    Load the trained ML model from disk.

    Returns
    -------
    model
        Trained Machine Learning model.
    """

    print()

    print("=" * 70)
    print("Loading ML Model")
    print("=" * 70)

    # --------------------------------------------------------
    # Validate Model File
    # --------------------------------------------------------

    if not os.path.exists(MODEL_PATH):

        raise FileNotFoundError(

            f"Model not found : {MODEL_PATH}"

        )

    # --------------------------------------------------------
    # Load Model
    # --------------------------------------------------------

    model = joblib.load(
        MODEL_PATH
    )

    print()

    print("Model Loaded Successfully")

    print()

    return model

# ============================================================
# LOAD HISTORICAL DATA
# ============================================================

def load_historical_data():
    """
    Load historical candle data used for backtesting.

    Returns
    -------
    pd.DataFrame
        Historical OHLCV data.
    """

    print_header(
        "Loading Historical Data"
    )

    # --------------------------------------------------------
    # Validate File
    # --------------------------------------------------------

    if not os.path.exists(HISTORICAL_DATA):

        raise FileNotFoundError(

            f"Historical data not found : {HISTORICAL_DATA}"

        )

    # --------------------------------------------------------
    # Read CSV
    # --------------------------------------------------------

    df = pd.read_csv(
        HISTORICAL_DATA,
        header=None,
        names=[
            "date",
            "time",
            "open",
            "high",
            "low",
            "close",
            "volume",
        ],
    )

    # --------------------------------------------------------
    # Create DateTime Column
    # --------------------------------------------------------

    df["dt"] = (
        df["date"].astype(str)
        + " "
        + df["time"].astype(str)
    )

    # --------------------------------------------------------
    # Convert Numeric Columns
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
    # Remove Invalid Rows
    # --------------------------------------------------------

    df = df.dropna()

    df = df.reset_index(
        drop=True,
    )

    # --------------------------------------------------------
    # Information
    # --------------------------------------------------------

    print()

    print(f"Historical File     : xauusd_m1_history.csv")

    print(f"Total Candles       : {len(df):,}")

    print(f"First Candle        : {df.iloc[0]['dt']}")

    print(f"Last Candle         : {df.iloc[-1]['dt']}")

    print()

    return df

# ============================================================
# PREPARE FEATURES
# ============================================================

def prepare_features(df):
    """
    Build all ML features required for backtesting.

    Parameters
    ----------
    df : pd.DataFrame

    Returns
    -------
    pd.DataFrame
    """

    print_header(
        "Preparing ML Features"
    )

    # --------------------------------------------------------
    # Build Features
    # --------------------------------------------------------

    df = build_features(
        df
    )

    # --------------------------------------------------------
    # Remove Incomplete Rows
    # --------------------------------------------------------

    df = df.dropna(
        subset=FEATURE_COLUMNS
    )

    df = df.reset_index(
        drop=True,
    )

    # --------------------------------------------------------
    # Information
    # --------------------------------------------------------

    print()

    print(f"Feature Groups      : {len(FEATURE_GROUPS)}")

    print(f"Total Features      : {len(FEATURE_COLUMNS)}")

    print(f"Rows Available      : {len(df):,}")

    print()

    return df

# ============================================================
# GENERATE MODEL PREDICTIONS
# ============================================================

def generate_predictions(model, df):
    """
    Generate ML predictions for all historical candles.

    Parameters
    ----------
    model : Trained ML Model

    df : pd.DataFrame

    Returns
    -------
    pd.DataFrame
    """

    print_header(
        "Generating Predictions"
    )

    # --------------------------------------------------------
    # Feature Matrix
    # --------------------------------------------------------

    X = df[FEATURE_COLUMNS]

    # --------------------------------------------------------
    # Predict Class
    # --------------------------------------------------------

    df["prediction"] = model.predict(
        X
    )

    # --------------------------------------------------------
    # Predict Probabilities
    # --------------------------------------------------------

    probabilities = model.predict_proba(
        X
    )

    class_map = {
        cls: idx
        for idx, cls in enumerate(model.classes_)
    }

    df["buy_probability"] = probabilities[
        :,
        class_map[1],
    ]

    df["sell_probability"] = probabilities[
        :,
        class_map[-1],
    ]

    df["confidence"] = df[
        [
            "buy_probability",
            "sell_probability",
        ]
    ].max(axis=1)

    # ========================================================
    # CONFIDENCE DISTRIBUTION ANALYSIS
    # ========================================================

    print_header(
        "Confidence Distribution"
    )

    print(
        df["confidence"].describe()
    )

    print()

    print(
        "Confidence >= 0.55 :",
        (df["confidence"] >= 0.55).sum()
    )

    print(
        "Confidence >= 0.60 :",
        (df["confidence"] >= 0.60).sum()
    )

    print(
        "Confidence >= 0.65 :",
        (df["confidence"] >= 0.65).sum()
    )

    print(
        "Confidence >= 0.70 :",
        (df["confidence"] >= 0.70).sum()
    )

    print()

    # --------------------------------------------------------
    # Information
    # --------------------------------------------------------

    print()

    print(f"Rows Predicted      : {len(df):,}")

    print(f"Predictions Created : Yes")

    print()

    return df

# ============================================================
# RUN BACKTEST
# ============================================================

def run_backtest(df):
    """
    Execute a simple one-candle backtest.
    """

    print_header(
        "Running Backtest"
    )

    trades = []

    print_header("Prediction Analysis")

    print(f"Maximum Confidence : {df['confidence'].max():.4f}")

    print(f"Minimum Confidence : {df['confidence'].min():.4f}")

    print(f"Maximum Edge       : {(abs(df['buy_probability'] - df['sell_probability'])).max():.4f}")

    print(f"Average Confidence : {df['confidence'].mean():.4f}")

    print()
        
    # --------------------------------------------------------
    # Simulate Trades
    # --------------------------------------------------------

    for i in range(len(df) - 1):

        signal = int(df.iloc[i]["prediction"])

        # --------------------------------------------------------
        # Apply Trading Rules
        # --------------------------------------------------------

        buy_probability = df.iloc[i]["buy_probability"]

        sell_probability = df.iloc[i]["sell_probability"]

        confidence = df.iloc[i]["confidence"]

        edge = abs(

            buy_probability
            - sell_probability

        )

        market_range = df.iloc[i]["range_5"]

        # Dynamic confidence threshold

        # if market_range >= 3.0:

        #     confidence_threshold = 0.75

        # elif market_range >= 2.0:

        #     confidence_threshold = 0.78

        # else:

        #     confidence_threshold = 0.80

        confidence_threshold = BACKTEST_CONFIDENCE_THRESHOLD
        
        # Skip weak signals

        if signal == BUY_SIGNAL:

            if confidence < confidence_threshold:

                continue

            if buy_probability <= sell_probability + BACKTEST_EDGE_MARGIN:

                continue

        elif signal == SELL_SIGNAL:

            if confidence < confidence_threshold:

                continue

            if sell_probability <= buy_probability + BACKTEST_EDGE_MARGIN:

                continue

        else:

            continue

        entry_price = float(df.iloc[i]["close"])

        exit_price = float(df.iloc[i + 1]["close"])

        if signal == BUY_SIGNAL:

            profit = exit_price - entry_price

        else:

            profit = entry_price - exit_price

        trades.append({

            "entry_time": df.iloc[i]["dt"],

            "exit_time": df.iloc[i + 1]["dt"],

            "signal": signal,

            "entry_price": entry_price,

            "exit_price": exit_price,

            "profit": profit,

        })

    trades_df = pd.DataFrame(
        trades
    )

    print()

    print(f"Trades Executed     : {len(trades_df):,}")

    print()
    
    print("Sample Trades")

    print("-" * 70)

    print(
        trades_df.head(5)
    )

    return trades_df

# ============================================================
# CALCULATE BACKTEST STATISTICS
# ============================================================

def calculate_statistics(trades_df):
    """
    Calculate backtesting performance statistics.
    """

    print_header(
        "Backtest Statistics"
    )

    # --------------------------------------------------------
    # Trade Counts
    # --------------------------------------------------------

    total_trades = len(trades_df)

    winning_trades = (
        trades_df["profit"] > 0
    ).sum()

    losing_trades = (
        trades_df["profit"] < 0
    ).sum()

    breakeven_trades = (
        trades_df["profit"] == 0
    ).sum()

    # --------------------------------------------------------
    # Win Rate
    # --------------------------------------------------------

    win_rate = (
        winning_trades
        / total_trades
        * 100
    )

    # --------------------------------------------------------
    # Profit
    # --------------------------------------------------------

    gross_profit = (
        trades_df.loc[
            trades_df["profit"] > 0,
            "profit",
        ]
        .sum()
    )

    gross_loss = abs(

        trades_df.loc[
            trades_df["profit"] < 0,
            "profit",
        ]
        .sum()

    )

    net_profit = (

        gross_profit
        - gross_loss

    )

    # --------------------------------------------------------
    # Profit Factor
    # --------------------------------------------------------

    if gross_loss == 0:

        profit_factor = 0

    else:

        profit_factor = (

            gross_profit
            / gross_loss

        )

    # --------------------------------------------------------
    # Average Win
    # --------------------------------------------------------

    average_win = (

        trades_df.loc[
            trades_df["profit"] > 0,
            "profit",
        ]
        .mean()

    )

    # --------------------------------------------------------
    # Average Loss
    # --------------------------------------------------------

    average_loss = (

        trades_df.loc[
            trades_df["profit"] < 0,
            "profit",
        ]
        .mean()

    )

    statistics = {

        "total_trades": total_trades,

        "winning_trades": winning_trades,

        "losing_trades": losing_trades,

        "breakeven_trades": breakeven_trades,

        "win_rate": win_rate,

        "gross_profit": gross_profit,

        "gross_loss": gross_loss,

        "net_profit": net_profit,

        "profit_factor": profit_factor,

        "average_win": average_win,

        "average_loss": average_loss,

    }

    print()

    print(f"Total Trades        : {total_trades:,}")

    print(f"Winning Trades      : {winning_trades:,}")

    print(f"Losing Trades       : {losing_trades:,}")

    print(f"Breakeven Trades    : {breakeven_trades:,}")

    print()

    print(f"Win Rate            : {win_rate:.2f}%")

    print()

    print(f"Gross Profit        : {gross_profit:.2f}")

    print(f"Gross Loss          : {gross_loss:.2f}")

    print(f"Net Profit          : {net_profit:.2f}")

    print()

    print(f"Profit Factor       : {profit_factor:.2f}")

    print(f"Average Win         : {average_win:.2f}")

    print(f"Average Loss        : {average_loss:.2f}")

    print()

    return statistics

# ============================================================
# SAVE REPORT
# ============================================================

def save_report():
    ...

# ============================================================
# DASHBOARD
# ============================================================

def print_dashboard():
    ...

# ============================================================
# MAIN
# ============================================================

def main():

    model = load_model()

    df = load_historical_data()

    df = prepare_features(df)

    df = generate_predictions(
        model,
        df,
    )

    trades = run_backtest(
        df,
    )

    statistics = calculate_statistics(
        trades,
    )

if __name__ == "__main__":
    
    main()