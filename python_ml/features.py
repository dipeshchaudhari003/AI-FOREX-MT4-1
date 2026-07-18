import pandas as pd

FEATURE_COLUMNS = [
    # Existing
    "ma_fast",
    "ma_slow",
    "momentum",
    "ret",
    "range_5",

    # EMA
    "ema20",
    "ema50",
    "ema100",
    "ema200",

    # RSI
    "rsi14",

    # ATR
    "atr14",

    # Bollinger 
    "bb_upper",
    "bb_lower",
    "bb_width",

    # Candle Features
    "body_size",
    "upper_wick",
    "lower_wick",
    "candle_range",

    # MACD
    "macd",
    "macd_signal",
    "macd_hist",

    # =================================================
    # ADX Features
    # =================================================

    "adx14",
    "plus_di14",
    "minus_di14",

    # =================================================
    # Volume Features
    # =================================================

    "volume_sma20",
    "relative_volume",
    "volume_change",

    # =================================================
    # EMA Distance Features
    # =================================================

    "dist_ema20",
    "dist_ema50",
    "dist_ema100",
    "dist_ema200",

]

# ============================================================
# FEATURE GROUPS
# ============================================================

FEATURE_GROUPS = {

    # Core Features
    "Base": 5,

    # Trend
    "EMA": 4,
    "EMA Distance": 4,

    # Momentum
    "RSI": 1,
    "MACD": 3,

    # Trend Strength
    "ADX": 3,

    # Volatility
    "ATR": 1,
    "Bollinger": 3,

    # Volume
    "Volume": 3,

    # Price Action
    "Candle": 4,

}

def build_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Build all engineered features used by the ML model.

    This function is shared by:

    - train_model.py
    - run_predictor.py
    - Backtesting
    - Future ML models (XGBoost / LightGBM)

    Returns
    -------
    pd.DataFrame
        DataFrame containing all engineered features.
    """

    df = df.copy()

    # =====================================================
    # Existing Base Features
    # =====================================================

    # Fast Moving Average (5)
    df["ma_fast"] = (
        df["close"]
        .rolling(5)
        .mean()
    )

    # Slow Moving Average (20)
    df["ma_slow"] = (
        df["close"]
        .rolling(20)
        .mean()
    )

    # Price Momentum (Current Close - Close 5 Candles Ago)
    df["momentum"] = (
        df["close"]
        - df["close"].shift(5)
    )

    # Percentage Return
    df["ret"] = (
        df["close"]
        .pct_change(fill_method=None)
    )

    # Average Trading Range (Last 5 Candles)
    df["range_5"] = (
        (df["high"] - df["low"])
        .rolling(5)
        .mean()
    )

    # =====================================================
    # EMA Features
    # =====================================================

    df["ema20"] = (
        df["close"]
        .ewm(
            span=20,
            adjust=False,
        )
        .mean()
    )

    df["ema50"] = (
        df["close"]
        .ewm(
            span=50,
            adjust=False,
        )
        .mean()
    )

    df["ema100"] = (
        df["close"]
        .ewm(
            span=100,
            adjust=False,
        )
        .mean()
    )

    df["ema200"] = (
        df["close"]
        .ewm(
            span=200,
            adjust=False,
        )
        .mean()
    )

    # =====================================================
    # RSI (14) Features
    # =====================================================

    delta = df["close"].diff()

    gain = delta.clip(lower=0)

    loss = -delta.clip(upper=0)

    avg_gain = gain.rolling(14).mean()

    avg_loss = loss.rolling(14).mean()

    rs = avg_gain / avg_loss

    df["rsi14"] = 100 - (100 / (1 + rs))

    # =====================================================
    # ATR (14) Features
    # =====================================================

    high_low = df["high"] - df["low"]

    high_close = (df["high"] - df["close"].shift()).abs()

    low_close = (df["low"] - df["close"].shift()).abs()

    tr = pd.concat(
        [
            high_low,
            high_close,
            low_close,
        ],
        axis=1,
    ).max(axis=1)

    df["atr14"] = tr.rolling(14).mean()

    # =====================================================
    # Bollinger Bands Features
    # =====================================================
   
    bb_mid = (
        df["close"]
        .rolling(20)
        .mean()
    )

    bb_std = (
        df["close"]
        .rolling(20)
        .std()
    )

    df["bb_upper"] = (
        bb_mid
        + (2 * bb_std)
    )

    df["bb_lower"] = (
        bb_mid
        - (2 * bb_std)
    )

    df["bb_width"] = (
        df["bb_upper"]
        - df["bb_lower"]
    )

    df["bb_upper"] = (
        bb_mid
        + (2 * bb_std)
    )

    df["bb_lower"] = (
        bb_mid
        - (2 * bb_std)
    )

    df["bb_width"] = (
        df["bb_upper"]
        - df["bb_lower"]
    )

    # =====================================================
    # Candle Features
    # =====================================================

    df["body_size"] = (df["close"] - df["open"]).abs()

    df["upper_wick"] = df["high"] - df[["open", "close"]].max(axis=1)

    df["lower_wick"] = df[["open", "close"]].min(axis=1) - df["low"]

    df["candle_range"] = df["high"] - df["low"]

    # =====================================================
    # MACD Features
    # =====================================================

    ema12 = (
        df["close"]
        .ewm(
            span=12,
            adjust=False,
        )
        .mean()
    )

    ema26 = (
        df["close"]
        .ewm(
            span=26,
            adjust=False,
        )
        .mean()
    )

    df["macd"] = ema12 - ema26

    df["macd_signal"] = (
        df["macd"]
        .ewm(
            span=9,
            adjust=False,
        )
        .mean()
    )

    df["macd_hist"] = (
        df["macd"]
        - df["macd_signal"]
    )

    # =====================================================
    # ADX Features
    # =====================================================

    plus_dm = (
        df["high"]
        .diff()
    )

    minus_dm = (
        -df["low"]
        .diff()
    )

    plus_dm = plus_dm.where(
        (plus_dm > minus_dm) & (plus_dm > 0),
        0.0,
    )

    minus_dm = minus_dm.where(
        (minus_dm > plus_dm) & (minus_dm > 0),
        0.0,
    )

    tr = pd.concat(
        [
            (df["high"] - df["low"]),
            (df["high"] - df["close"].shift()).abs(),
            (df["low"] - df["close"].shift()).abs(),
        ],
        axis=1,
    ).max(axis=1)

    atr = (
        tr
        .rolling(14)
        .mean()
    )

    plus_di = (
        100
        * (
            plus_dm
            .rolling(14)
            .mean()
            / atr
        )
    )

    minus_di = (
        100
        * (
            minus_dm
            .rolling(14)
            .mean()
            / atr
        )
    )

    dx = (
        (
            (plus_di - minus_di).abs()
            /
            (plus_di + minus_di)
        )
        * 100
    )

    df["adx14"] = (
        dx
        .rolling(14)
        .mean()
    )

    df["plus_di14"] = plus_di

    df["minus_di14"] = minus_di


    # =====================================================
    # Volume Features
    # =====================================================

    df["volume_sma20"] = (
        df["volume"]
        .rolling(20)
        .mean()
    )

    df["relative_volume"] = (
        df["volume"]
        / df["volume_sma20"]
    )

    df["volume_change"] = (
        df["volume"]
        .pct_change(fill_method=None)
    )

    # =====================================================
    # EMA Distance Features
    # =====================================================

    df["dist_ema20"] = (
        df["close"]
        - df["ema20"]
    )

    df["dist_ema50"] = (
        df["close"]
        - df["ema50"]
    )

    df["dist_ema100"] = (
        df["close"]
        - df["ema100"]
    )

    df["dist_ema200"] = (
        df["close"]
        - df["ema200"]
    )

    return df