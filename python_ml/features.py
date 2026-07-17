import pandas as pd

FEATURE_COLUMNS = [
    "ma_fast",
    "ma_slow",
    "momentum",
    "ret",
    "range_5",
]


def build_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Build ML features.
    Every training/prediction script should call this function.
    """

    df = df.copy()

    df["ma_fast"] = df["close"].rolling(5).mean()

    df["ma_slow"] = df["close"].rolling(20).mean()

    df["momentum"] = df["close"] - df["close"].shift(5)

    df["ret"] = df["close"].pct_change(fill_method=None)

    df["range_5"] = (
        df["high"] - df["low"]
    ).rolling(5).mean()

    return df