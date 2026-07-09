"""
train_experiment.py
Run configurable training experiments and save result models with descriptive filenames.
"""
import os
import joblib
import argparse
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, "data", "XAUUSD_M1.csv")
OUT_DIR = os.path.join(BASE_DIR, "experiments")
os.makedirs(OUT_DIR, exist_ok=True)


def build_features(df):
    df = df.copy()
    df['ma_fast'] = df['close'].rolling(5).mean()
    df['ma_slow'] = df['close'].rolling(20).mean()
    df['momentum'] = df['close'] - df['close'].shift(5)
    df['ret'] = df['close'].pct_change(fill_method=None)
    df['range_5'] = (df['high'] - df['low']).rolling(5).mean()
    return df


def run_experiment(n_estimators, max_depth, min_samples_leaf, test_size, random_state):
    df = pd.read_csv(CSV_PATH, header=None, names=['date','time','open','high','low','close','volume'])
    for col in ['open','high','low','close','volume']:
        df[col] = pd.to_numeric(df[col], errors='coerce')

    df = build_features(df)
    df['future_close'] = df['close'].shift(-1)
    df['signal'] = np.where(df['future_close'] > df['close'], 1, -1)
    features = ['ma_fast','ma_slow','momentum','ret','range_5']
    df = df.dropna(subset=[*features, 'signal'])

    X = df[features]
    y = df['signal']

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_size, random_state=random_state, stratify=y)

    model = RandomForestClassifier(n_estimators=n_estimators, max_depth=max_depth, min_samples_leaf=min_samples_leaf, random_state=random_state, class_weight='balanced')
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    acc = accuracy_score(y_test, y_pred)
    report = classification_report(y_test, y_pred)

    fname = f"rf_ne{n_estimators}_md{max_depth}_msl{min_samples_leaf}_acc{acc:.4f}.pkl"
    outpath = os.path.join(OUT_DIR, fname)
    joblib.dump(model, outpath)

    return {'model_path': outpath, 'accuracy': acc, 'report': report}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--n_estimators', type=int, default=500)
    parser.add_argument('--max_depth', type=int, default=8)
    parser.add_argument('--min_samples_leaf', type=int, default=5)
    parser.add_argument('--test_size', type=float, default=0.2)
    parser.add_argument('--random_state', type=int, default=42)
    args = parser.parse_args()

    res = run_experiment(args.n_estimators, args.max_depth, args.min_samples_leaf, args.test_size, args.random_state)
    print('Model saved to:', res['model_path'])
    print('Accuracy:', res['accuracy'])
    print(res['report'])
