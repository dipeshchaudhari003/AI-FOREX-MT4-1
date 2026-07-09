# AI Forex MT4

This repository contains a MetaTrader 4 Expert Advisor and a Python machine-learning workflow for generating trading signals for XAUUSD.

## Repository structure

- mt4/Experts/ - MT4 EA source files
- mt4/Include/ - future reusable MQL4 modules
- python_ml/scripts/ - training, prediction, and backtesting scripts
- python_ml/data/ - historical market data
- python_ml/models/ - trained model artifacts
- python_ml/datasets/raw/ and python_ml/datasets/processed/ - dataset organization
- backtests/ - historical backtest snapshots
- screenshots/ - test and demo screenshots
- docs/ - documentation and screenshots
- logs/ and output/ - runtime artifacts

## Python setup

```bash
cd python_ml
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Train the model

```bash
python scripts/train_model.py
```

## Run the predictor

```bash
python scripts/run_predictor.py
```

## MT4 setup

1. Copy the EA file from mt4/Experts/ into your MetaTrader 4 Experts folder.
2. Ensure the Python predictor can write to the MT4 Files folder or update the MT4_FILES environment variable.
3. Start the predictor before running the EA.

## Future MQL4 modularization

The main EA is expected to evolve into a thin entry point, with shared logic moved into include files such as TradeManager.mqh, Indicators.mqh, RiskManager.mqh, MoneyManager.mqh, AIEngine.mqh, Notification.mqh, and Utilities.mqh.
