"""
Simple backtester for XAUUSD M1 using RandomForest model predictions.
Simulates trades using candle high/low to determine TP/SL hits.
"""
import os
import joblib
import argparse
import pandas as pd
import numpy as np

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, "data", "XAUUSD_M1.csv")
MODEL_DEFAULT = os.path.join(BASE_DIR, "models", "xau_model.pkl")


def build_features(df):
    df = df.copy()
    df['ma_fast'] = df['close'].rolling(5).mean()
    df['ma_slow'] = df['close'].rolling(20).mean()
    df['momentum'] = df['close'] - df['close'].shift(5)
    df['ret'] = df['close'].pct_change(fill_method=None)
    df['range_5'] = (df['high'] - df['low']).rolling(5).mean()
    return df


def simulate_trades(df, signals, tp_points=30, sl_points=300, max_holding=10, point=0.01):
    trades = []
    n = len(df)
    for i in range(len(signals)):
        sig = signals.iloc[i]
        if sig == 0:
            continue
        # entry at next candle open
        idx = signals.index[i]
        if idx+1 >= n:
            continue
        entry_price = df.at[idx+1, 'open']
        entry_index = idx+1
        tp = tp_points * point
        sl = sl_points * point
        win = None
        exit_price = None
        exit_index = None
        # simulate up to max_holding candles
        for j in range(entry_index, min(entry_index+max_holding, n)):
            high = df.at[j, 'high']
            low = df.at[j, 'low']
            if sig == 1:
                if high >= entry_price + tp:
                    win = True; exit_price = entry_price + tp; exit_index = j; break
                if low <= entry_price - sl:
                    win = False; exit_price = entry_price - sl; exit_index = j; break
            elif sig == -1:
                if low <= entry_price - tp:
                    win = True; exit_price = entry_price - tp; exit_index = j; break
                if high >= entry_price + sl:
                    win = False; exit_price = entry_price + sl; exit_index = j; break
        if win is None:
            # exit at close of last observed candle
            exit_index = min(entry_index+max_holding-1, n-1)
            exit_price = df.at[exit_index, 'close']
            if sig == 1:
                pnl_points = (exit_price - entry_price) / point
            else:
                pnl_points = (entry_price - exit_price) / point
            win = pnl_points > 0
        else:
            if sig == 1:
                pnl_points = (exit_price - entry_price) / point
            else:
                pnl_points = (entry_price - exit_price) / point
        trades.append({'entry_index': entry_index, 'exit_index': exit_index, 'signal': sig, 'pnl_points': pnl_points, 'win': win})
    return pd.DataFrame(trades)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', default=MODEL_DEFAULT)
    parser.add_argument('--tp', type=int, default=30)
    parser.add_argument('--sl', type=int, default=300)
    parser.add_argument('--max_holding', type=int, default=10)
    parser.add_argument('--point', type=float, default=0.01)  # points value (depends on broker)
    args = parser.parse_args()

    print('Loading data...')
    df = pd.read_csv(CSV_PATH, header=None, names=['date','time','open','high','low','close','volume'])
    for col in ['open','high','low','close','volume']:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    df = build_features(df)
    df = df.dropna(subset=['ma_fast','ma_slow','momentum','ret','range_5'])

    print('Loading model:', args.model)
    model = joblib.load(args.model)

    X = df[['ma_fast','ma_slow','momentum','ret','range_5']]
    preds = model.predict(X)

    # Build signals series aligned to df index
    signals = pd.Series(preds, index=df.index)

    trades = simulate_trades(df, signals, tp_points=args.tp, sl_points=args.sl, max_holding=args.max_holding, point=args.point)

    if trades.empty:
        print('No trades simulated')
        exit(0)

    total = len(trades)
    wins = trades['win'].sum()
    avg_points = trades['pnl_points'].mean()
    total_points = trades['pnl_points'].sum()
    win_rate = wins/total

    print('Trades:', total)
    print('Wins:', wins, f'({win_rate:.2%})')
    print('Avg pnl (points):', f"{avg_points:.2f}")
    print('Total pnl (points):', f"{total_points:.2f}")
    # simple profit factor
    gross_win = trades.loc[trades['pnl_points']>0, 'pnl_points'].sum()
    gross_loss = -trades.loc[trades['pnl_points']<0, 'pnl_points'].sum()
    pf = (gross_win / gross_loss) if gross_loss>0 else float('inf')
    print('Profit factor:', f"{pf:.2f}")

    # show first 5 trades
    print('\nFirst 5 trades:')
    print(trades.head().to_string(index=False))
