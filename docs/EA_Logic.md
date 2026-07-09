# EA Logic

This document summarizes the Expert Advisor flow.

1. The EA reads the ML-generated signal file from the MT4 Files folder.
2. It evaluates the signal and applies the configured risk settings.
3. It writes trade actions and status updates back to the shared files for the Python predictor.
