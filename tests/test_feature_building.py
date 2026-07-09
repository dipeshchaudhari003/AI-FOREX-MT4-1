import os
import sys

import pandas as pd

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'python_ml', 'scripts')))

from train_model import build_features


def test_build_features_returns_expected_columns():
    df = pd.DataFrame(
        {
            'close': [10.0, 11.0, 12.0, 13.0, 14.0, 15.0],
            'high': [10.5, 11.5, 12.5, 13.5, 14.5, 15.5],
            'low': [9.5, 10.5, 11.5, 12.5, 13.5, 14.5],
        }
    )

    result = build_features(df)

    assert 'ma_fast' in result.columns
    assert 'ma_slow' in result.columns
    assert 'momentum' in result.columns
    assert 'ret' in result.columns
    assert 'range_5' in result.columns
    assert result['ma_fast'].iloc[4] == 12.0
