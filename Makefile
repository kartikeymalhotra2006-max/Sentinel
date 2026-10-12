.PHONY: install train tune test lint serve demo benchmark replay clean
PY ?= python3
export PYTHONPATH := src

install:
	pip install -r requirements.txt -r requirements-serve.txt -r requirements-dev.txt

train:                 ## synthetic data, ~1 min on a laptop CPU
	$(PY) -m sentinel.pipeline --out artifacts

tune:                  ## + Optuna search with time-ordered CV
	$(PY) -m sentinel.pipeline --out artifacts --tune 30

ieee:                  ## real data: make ieee DIR=/path/to/ieee-fraud-detection
	$(PY) -m sentinel.pipeline --data ieee --ieee-dir $(DIR) --out artifacts_ieee --tune 30

test:
	$(PY) -m pytest

lint:
	ruff check src tests scripts demo

serve:
	SENTINEL_BUNDLE=artifacts/bundle.joblib uvicorn sentinel.serve.app:app --port 8000

demo:
	streamlit run demo/app.py

benchmark:
	$(PY) scripts/benchmark.py

replay:                ## needs `make serve` running
	$(PY) scripts/replay.py --url http://127.0.0.1:8000 -n 100000

clean:
	rm -rf .pytest_cache **/__pycache__
