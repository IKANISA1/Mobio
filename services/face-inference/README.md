# Face inference

Stateless, headless CPU inference for the owner-approved face-to-USSD shortcut.
This service does not authenticate people, authorize payments, perform liveness,
store captures, or choose receiving numbers. One still produces one normalized
template or a structured capture error.

## Reproduce locally

Use Python 3.12.13. The Linux container uses the same locked Python packages.

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install --require-hashes -r requirements.lock
.venv/bin/python fetch_models.py
.venv/bin/python -m unittest discover -s tests -v
.venv/bin/python server.py
```

`GET /health` reports loaded only after checksum checks, actual SFace inference,
and an actual YuNet call. `POST /embed` accepts binary image bytes, not URLs or
client-authored vectors. The HTTP listener belongs inside the private container;
do not publish it directly. Docker validation, when the daemon is available:

```sh
docker build --platform linux/amd64 -t mobio-face-inference:20260920 .
docker run --rm --name mobio-face-smoke -p 127.0.0.1:18080:8080 mobio-face-inference:20260920
```

In another terminal, from this directory:

```sh
FACE_SMOKE_BASE_URL=http://127.0.0.1:18080 .venv/bin/python -m unittest discover -s tests -p test_http.py -v
```

Run the real HTTP smoke against the image as well as the host service before
deployment. The host test passing does not establish Linux image compatibility.

## Immutable model contract

`model-manifest.json` pins the OpenCV Zoo commit, SHA-256 of each ONNX file,
runtime, preprocessing and model version. `fetch_models.py` checks those hashes;
startup never downloads models. The bundle is YuNet March 2023 (MIT) and SFace
December 2021 (Apache 2.0), with the exact upstream licence texts retained beside
the manifest. No InsightFace weights or AWS components are used.

OpenCV 4.11.0.86 uses BGR pixels after EXIF orientation, a longest side of 1024,
YuNet landmarks and SFace `alignCrop`. Actual feature output is checked against
the contract's 128 dimensions, finite float32 values and L2 normalization. The
Worker independently verifies the same contract before querying its versioned
cosine index. A model/preprocessing change requires a new version/index and
re-enrollment, even if its output dimension stays 128.

Engineering limits: one face, face rectangle at least 64 pixels, image at most
1,500,000 bytes and 4,000,000 decoded pixels, JPEG/PNG/single-frame WebP, blur
variance at least 20 after alignment. These are initial capture-quality limits,
not a measured recognition policy. One inference at a time protects OpenCV's
mutable detector; concurrent work gets `SERVICE_BUSY`. Models load once, CPU
threads are capped at one, capture buffers are not persisted, and HTTP request
logging is disabled. Buffer release is not a claim of cryptographic erasure.

## Consented recognition evaluation

Keep captures and the local manifest outside source control. `evaluate.py --help`
describes its JSON schema. Supply explicit consent, at least two enrolled
subjects, independent held-out probes for each, and unknown-person probes.
Duplicate bytes are rejected even under a different filename. Do not scrape
faces or substitute generated fixtures for accuracy evidence.

```sh
.venv/bin/python evaluate.py /private/path/consented-cohort.json \
  --min-score "$MEASURED_CANDIDATE_SCORE" \
  --min-margin "$MEASURED_CANDIDATE_MARGIN" \
  --output /private/path/aggregate-evaluation.json
```

The aggregate report records gallery/probe denominators, wrong candidates,
known no-matches, unknown rejections, ambiguity, capture retries, lighting/device
conditions, local load time and local p50/p95. It omits subject keys, image paths,
raw images and vectors. Evaluate candidate thresholds on a calibration split,
then freeze and evaluate on a separate acceptance split. Do not tune on the
acceptance images. Local exhaustive cosine search is not Vectorize acceptance;
repeat the accepted cohort through the deployed stack and measure network,
index and scan-to-dialer latency separately. No default recognition threshold
is enabled in SQL.

See [deployment and data flow](../../docs/operations/face-ussd-runbook.md) and
[device acceptance](../../docs/testing/face-ussd-device-acceptance.md).
