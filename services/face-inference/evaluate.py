"""Offline, consented holdout evaluation. Never downloads images or uploads a gallery.

Input JSON (keep outside source control):
  {"consent_attested": true,
   "enrollments": [{"subject": "opaque-a", "image": "enroll-a.jpg"}, ...],
   "probes": [{"subject": "opaque-a", "image": "scan-a.jpg", "condition": "normal"},
              {"subject": null, "image": "unknown.jpg", "condition": "dim_light"}]}
Subject keys only group locally consented captures; no identities are inferred.
The output contains aggregate counts, conditions and timing, never images/vectors/keys.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import time

import numpy as np

from inference import CaptureError, FaceModel

CONDITIONS = {"normal", "dim_light", "backlit", "front_camera", "rear_camera", "other"}


def evaluate(manifest, min_score, min_margin):
    source = json.loads(manifest.read_text())
    if source.get("consent_attested") is not True:
        raise ValueError("An explicit consent attestation is required")
    enrollments, probes = source["enrollments"], source["probes"]
    owners = [row["subject"] for row in enrollments]
    if len(owners) < 2 or len(set(owners)) != len(owners) or not all(isinstance(x, str) and x for x in owners):
        raise ValueError("Use at least two distinct, opaque gallery subject keys")
    if not probes or not any(p["subject"] is None for p in probes):
        raise ValueError("Include separate known-subject and unknown-subject probes")
    if set(p["subject"] for p in probes if p["subject"] is not None) != set(owners):
        raise ValueError("Every enrolled subject needs a separate holdout probe")
    seen = set()

    def capture(row):
        # Exact duplicates are rejected across enrollment and probes, even if renamed.
        data = (manifest.parent / row["image"]).read_bytes()
        digest = hashlib.sha256(data).digest()
        if digest in seen:
            raise ValueError("Use independent captures, not duplicate image bytes")
        seen.add(digest)
        return data

    started = time.perf_counter()
    model = FaceModel()
    load_ms = (time.perf_counter() - started) * 1000
    gallery = []
    for row in enrollments:
        try:
            gallery.append(model.embed(capture(row))["values"])
        except CaptureError as error:
            raise ValueError(f"Enrollment capture rejected: {error.code}") from None
    gallery = np.asarray(gallery, dtype=np.float32)
    totals, per_condition = Counter(), defaultdict(Counter)
    timings = []
    for row in probes:
        condition = row.get("condition", "other")
        if condition not in CONDITIONS:
            raise ValueError("Use a supported non-identifying condition label")
        known = row["subject"] is not None
        totals["known_probes" if known else "unknown_probes"] += 1
        data = capture(row)
        started = time.perf_counter()
        try:
            feature = np.asarray(model.embed(data)["values"], dtype=np.float32)
            scores = gallery @ feature
            ranking = np.argsort(-scores)
            first, second = ranking[:2]
            if scores[first] < min_score:
                result = "known_no_match" if known else "unknown_rejected"
            elif scores[first] - scores[second] < min_margin:
                result = "ambiguous"
            elif owners[first] == row["subject"]:
                result = "correct_match"
            else:
                result = "wrong_candidate"  # Includes an unknown person accepted as enrolled.
        except CaptureError as error:
            result = "capture_retry_" + error.code.lower()
        timings.append((time.perf_counter() - started) * 1000)
        totals[result] += 1
        per_condition[condition][result] += 1
        per_condition[condition]["probes"] += 1
    return {
        "model_version": model.contract["version"], "dimensions": model.dimensions,
        "policy": {"min_score": min_score, "min_margin": min_margin},
        "gallery_size": len(owners), "probe_count": len(probes),
        "counts": dict(totals), "conditions": dict(per_condition),
        "local_model_load_ms": round(load_ms, 2),
        "local_probe_ms": {"p50": round(float(np.percentile(timings, 50)), 2),
                           "p95": round(float(np.percentile(timings, 95)), 2)},
        "limitations": "Local exhaustive cosine evaluation; no Vectorize, network, device, operator or production-scale acceptance. Small cohorts do not prove universal accuracy."
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--min-score", type=float, required=True)
    parser.add_argument("--min-margin", type=float, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not -1 <= args.min_score <= 1 or not 0 < args.min_margin <= 2:
        parser.error("Invalid cosine policy")
    report = evaluate(args.manifest.resolve(), args.min_score, args.min_margin)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print("Aggregate evaluation saved. Review wrong-candidate counts before accepting a policy.")
