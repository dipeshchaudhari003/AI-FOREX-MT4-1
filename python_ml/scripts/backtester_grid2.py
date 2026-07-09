"""
Finer grid sweep for TP/SL including spread/slippage and commission per lot.
Generates TP range and SL range programmatically.
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


def simulate_trades(df, signals, tp_points=30, sl_points=300, max_holding=10, point=0.01, spread=2.0, slippage=1.0, lot_size=0.01, commission_per_std_lot=5.0):
    trades = []
    n = len(df)
    commission_per_trade = commission_per_std_lot * lot_size
    for i in range(len(signals)):
        sig = signals.iloc[i]
        if sig == 0:
            continue
        idx = signals.index[i]
        if idx+1 >= n:
            continue
        raw_open = df.at[idx+1, 'open']
        if sig == 1:
            entry_price = raw_open + (spread + slippage) * point
        else:
            entry_price = raw_open - (spread + slippage) * point
        entry_index = idx+1
        tp = tp_points * point
        sl = sl_points * point
        win = None
        exit_price = None
        exit_index = None
        for j in range(entry_index, min(entry_index+max_holding, n)):
            high = df.at[j, 'high']
            low = df.at[j, 'low']
            if sig == 1:
                if high >= entry_price + tp:
                    win = True; exit_price = entry_price + tp; exit_index = j; break
                if low <= entry_price - sl:
                    win = False; exit_price = entry_price - sl; exit_index = j; break
            else:
                if low <= entry_price - tp:
                    win = True; exit_price = entry_price - tp; exit_index = j; break
                if high >= entry_price + sl:
                    win = False; exit_price = entry_price + sl; exit_index = j; break
        if win is None:
            exit_index = min(entry_index+max_holding-1, n-1)
            exit_price = df.at[exit_index, 'close']
            if sig == 1:
                pnl_points = (exit_price - entry_price) / point
            else:
                pnl_points = (entry_price - exit_price) / point
        else:
            if sig == 1:
                pnl_points = (exit_price - entry_price) / point
            else:
                pnl_points = (entry_price - exit_price) / point
        usd_per_point_per_std_lot = 100 * point
        usd_pnl = pnl_points * usd_per_point_per_std_lot * lot_size
        usd_pnl_after_commission = usd_pnl - commission_per_trade
        trades.append({'entry_index': entry_index, 'exit_index': exit_index, 'signal': sig, 'pnl_points': pnl_points, 'usd_pnl': usd_pnl_after_commission, 'win': win})
    return pd.DataFrame(trades)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--model', default=MODEL_DEFAULT)
    parser.add_argument('--tp_min', type=int, default=30)
    parser.add_argument('--tp_max', type=int, default=70)
    parser.add_argument('--tp_step', type=int, default=5)
    parser.add_argument('--sl_min', type=int, default=80)
    parser.add_argument('--sl_max', type=int, default=200)
    parser.add_argument('--sl_step', type=int, default=10)
    parser.add_argument('--max_holding', type=int, default=10)
    parser.add_argument('--point', type=float, default=0.01)
    parser.add_argument('--spread', type=float, default=2.0)
    parser.add_argument('--slippage', type=float, default=1.0)
    parser.add_argument('--lot_size', type=float, default=0.01)
    parser.add_argument('--commission_per_std_lot', type=float, default=5.0)
    args = parser.parse_args()

    tp_list = list(range(args.tp_min, args.tp_max+1, args.tp_step))
    sl_list = list(range(args.sl_min, args.sl_max+1, args.sl_step))

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
    signals = pd.Series(preds, index=df.index)

    best = None
    results = []
    for tp in tp_list:
        for sl in sl_list:
            trades = simulate_trades(df, signals, tp_points=tp, sl_points=sl, max_holding=args.max_holding, point=args.point, spread=args.spread, slippage=args.slippage, lot_size=args.lot_size, commission_per_std_lot=args.commission_per_std_lot)
            if trades.empty:
                total_usd = 0.0
            else:
                total_usd = trades['usd_pnl'].sum()
            results.append({'tp': tp, 'sl': sl, 'trades': len(trades), 'total_usd': total_usd})
            if best is None or total_usd > best['total_usd']:
                best = {'tp': tp, 'sl': sl, 'trades': len(trades), 'total_usd': total_usd}
    print('\nGrid results sample: (showing top 10 by total_usd)')
    results_sorted = sorted(results, key=lambda r: r['total_usd'], reverse=True)
    for r in results_sorted[:10]:
        print(r)
    print('\nBest: ', best)
