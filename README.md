# Sentinel — cost-aware, real-time card fraud detection

An end-to-end fraud system built the way a payments risk team would: leakage-safe features, a gradient-boosted
model judged on **business cost** (not accuracy), analyst-readable reason codes, a sub-millisecond scoring API, and
monitoring that is honest about what it can and cannot detect.

> **Read this first.** Every number below comes from the built-in *synthetic* generator (150k transactions, 3% fraud,
> four attack types), because the Kaggle IEEE-CIS data needs a login. The pipeline runs unchanged on IEEE-CIS
> (`make ieee DIR=...`), but **do not quote these figures as real-dataset results.** Re-run on real data and report those.

## Results (final 15% of the timeline, never used for training, calibration or thresholds)

| Model | PR-AUC (95% CI) | ROC-AUC | Recall @ 1% FPR | Expected cost | Saving vs approve-all |
|---|---|---|---|---|---|
| Logistic baseline | 0.602 (0.509–0.684) | 0.946 | 0.576 | $12,180 | 60.1% |
| **LightGBM (final)** | **0.669 (0.584–0.742)** | 0.953 | 0.667 | **$9,381** | **69.3%** |
| LightGBM + anomaly score | 0.665 (0.579–0.744) | 0.918 | 0.659 | $9,772 | 68.0% |

Intervals are cluster bootstrap over cards (fraud arrives in correlated bursts). Cost model (all configurable):
$15 per wrongly declined customer, $3 per manual review, analysts catch 85% of reviewed fraud, a missed fraud costs its amount.

| Plot | |
|---|---|
| ![pr](artifacts/plots/pr_curve.png) | ![cost](artifacts/plots/cost_curve.png) |
| ![drift](artifacts/plots/drift_weekly.png) | ![shap](artifacts/plots/shap_global.png) |

## Findings worth discussing in an interview
1. **Device-graph features carry the model.** Removing them drops test PR-AUC 0.669 → 0.453 (other families cost ≤ 0.02, within noise).
2. **Anomaly stacking did not help.** The CIs overlap completely; the pipeline selects plain LightGBM on validation PR-AUC. Reporting a null result is the point.
3. **A late "low-and-slow" attack evades the model** (10% flagged vs 95–100% for the other attacks) and creates the cliff in the PR curve.
4. **Score-distribution PSI never alerted on that drift** (≈0.01 vs the 0.2 alert level). An attack that evades a model produces *low* scores, so the score distribution barely moves. The label-based recall alert (−15 points vs reference) fired in weeks 14–16. Track both.
5. **Retraining recovers part, not all** (e.g. block 3: 0.674 → 0.739), because few labelled examples of the new attack exist yet.
6. **Fairness-style check:** false-positive rate by segment differs (desktop 2.8% vs mobile 1.9%; $200+ purchases 5.5% vs $10–50 1.3%). On real data you would investigate such gaps.

## Architecture
```
transactions ─► features.py (batch, strictly-past)      ─► train: LR | LightGBM | +IsolationForest
                serve/online.py (same logic, stateful)      │  Platt calibration, cost-optimal thresholds
                         ▲                                  ▼
        Redis / in-memory card+device state ◄── POST /score ─► risk, approve|review|decline, top-3 reasons
                                                  GET /drift ─► PSI of live traffic vs reference
```

## Quickstart
```bash
make install
make train            # ~1 min: data, features, models, plots, artifacts/bundle.joblib
make test             # 39 tests
make serve            # API on :8000      (make demo for the Streamlit replay)
make benchmark
```
```bash
curl -X POST localhost:8000/score -H 'content-type: application/json' \
  -d '{"txn_id":"t1","ts":1700000000,"card_id":"c42","amount":349.99,"device_id":"dNEW","product":"C","email_domain":"other","device_type":"desktop"}'
```
`POST /ingest` backfills history without scoring; `scripts/replay.py` replays the held-out period over HTTP.

### Real data
Download `train_transaction.csv` and `train_identity.csv` from the Kaggle IEEE-CIS competition, then `make ieee DIR=<folder>`.
IEEE-CIS has no real card or device id: `card_id = card1+card2+addr1` and `device_id = DeviceInfo` (a model name, mostly missing),
so device-graph features will be weaker than here. The pipeline refuses to run if any split has fewer than 30 fraud rows.

## What the tests prove (`tests/`)
- **No leakage:** truncating or randomising the future does not change past features; shuffled labels change nothing; unsorted input and null card ids are rejected.
- **No training/serving skew:** online features equal batch features (including exact window-boundary and same-second ties, with a deliberately injected off-by-one confirmed to fail), and the live API's score and *decision* equal the offline pipeline's for every replayed transaction, for both the plain and stacked bundles.
- **Metrics/cost:** hand-computed cost, optimiser vs brute force, calibration and PSI behaviour, threshold robustness to float noise.
- **API:** validation, idempotent retries, dry-run, out-of-order flag, Redis (fakeredis) parity, ingest, readable reasons.
- **Pipeline:** artifacts exist, chronological splits, and the full pipeline runs on files with the IEEE-CIS schema.

Measured on one shared CPU core: 0.40 ms p50 / 0.48 ms p95 for featurise+score+commit in-process; 1.3 ms p50 / 1.9 ms p95
through the full FastAPI stack (in-memory state; Redis adds a network hop). A real load test: `locust -f scripts/locustfile.py`.

## Design decisions and honest limitations
- **Chronological splits only** (55/10/10/10/15 train/early-stop/calibrate/threshold/test). Labels are assumed available immediately; real chargebacks arrive weeks late.
- **Imbalance:** class-weight strategies compared on validation (√-weighting won narrowly). SMOTE deliberately not used: time-dependent behavioural features make synthetic oversampling unrealistic.
- **ONNX export not done;** native LightGBM already meets the latency target.
- **Redis state is not atomic across concurrent writers** for the same card; production needs a Lua script or per-card partition routing.
- **Docker/compose files are untested** (no Docker in the build environment).
- **Synthetic data is simpler than reality;** its fraud patterns were written by me, so strong results here prove the pipeline works, not that fraud is easy.
- No GNN/graph model and no MLflow: possible extensions.

## Describing it on a CV (replace brackets with your IEEE-CIS results)
- Built a leakage-safe fraud pipeline on **[N]** transactions with time-based validation; LightGBM reached **[x]** PR-AUC vs **[y]** for a logistic baseline (cluster-bootstrap CI).
- Optimised a 3-band decision policy against an explicit cost model, cutting expected loss by **[z]%** vs approving everything.
- Shipped a FastAPI scoring service with SHAP reason codes, Redis state and **[p95] ms** latency; proved online/offline parity with tests.
- Showed score-PSI missed a new attack that a recall alert caught; wrote the retraining experiment.
