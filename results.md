# Results (synthetic data, 149,957 rows, fraud rate 3.03%)

All numbers are on the chronologically last 15% of the data (never seen in training, calibration or threshold selection).

| Model | PR-AUC (95% CI) | ROC-AUC | Recall @ 1% FPR | ECE | Expected cost | Saving vs approve-all |
|---|---|---|---|---|---|---|
| logistic | 0.602 (0.509-0.684) | 0.946 | 0.576 | 0.0068 | $12,180 | 60.1% |
| lightgbm **(final)** | 0.669 (0.584-0.742) | 0.953 | 0.667 | 0.0058 | $9,381 | 69.3% |
| stacked | 0.665 (0.579-0.744) | 0.918 | 0.659 | 0.0066 | $9,772 | 68.0% |

Approve-everything baseline cost on test: $30,561.

## By attack type (final model, test)

| Attack | Fraud rows | Flagged | Declined |
|---|---|---|---|
| ato | 104 | 95.2% | 85.6% |
| ring | 131 | 95.4% | 87.8% |
| slow | 159 | 10.1% | 1.3% |
| testing | 114 | 100.0% | 100.0% |

## Ablation (test PR-AUC)

- all features: 0.669
- - amount: 0.650
- - velocity: 0.659
- - device_graph: 0.453
- - time: 0.652
- - categorical: 0.674

## Drift: frozen vs retrained

| Block | Fraud | Frozen PR-AUC | Retrained PR-AUC |
|---|---|---|---|
| 1 | 170 | 0.656 | 0.663 |
| 2 | 162 | 0.689 | 0.729 |
| 3 | 137 | 0.674 | 0.739 |
