# Strategy Overview

The current workflow uses a simple machine-learning approach for XAUUSD:

- Feature engineering from moving averages, momentum, return, and volatility.
- A Random Forest classifier trained on historical candle data.
- Signal generation that can be consumed by the MT4 Expert Advisor.
