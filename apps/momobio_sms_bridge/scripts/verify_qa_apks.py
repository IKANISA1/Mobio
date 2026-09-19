#!/usr/bin/env python3
"""Inspect actual component-test APKs before installing them on an emulator."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    apk_root = root / "apps/momobio_sms_bridge/app/build/outputs/apk"
    sdk = Path(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", Path.home() / "Library/Android/sdk")))
    analyzer = sdk / "cmdline-tools/latest/bin/apkanalyzer"
    args.output.mkdir(parents=True, exist_ok=True)
    namespace = "{http://schemas.android.com/apk/res/android}"
    artifacts = []
    for kind, path, expected in [
        ("app", apk_root / "qa/app-qa.apk", "com.momobio.app.qa"),
        ("tests", apk_root / "androidTest/qa/app-qa-androidTest.apk", "com.momobio.app.qa.test"),
    ]:
        artifact = args.output / path.name
        shutil.copy2(path, artifact)
        xml = subprocess.check_output([str(analyzer), "manifest", "print", str(artifact)], timeout=60)
        (args.output / f"{kind}-manifest.xml").write_bytes(xml)
        manifest = ET.fromstring(xml)
        if manifest.attrib.get("package") != expected:
            raise SystemExit(f"Refusing unexpected {kind} package")
        permissions = [node.attrib.get(namespace + "name") for node in manifest if node.tag.startswith("uses-permission")]
        if permissions:
            raise SystemExit(f"Refusing {kind} APK requesting permissions: {permissions}")
        application = manifest.find("application")
        if application is None:
            raise SystemExit(f"Missing {kind} application declaration")
        components = [node.tag for node in application if node.tag in {"activity", "activity-alias", "receiver", "provider", "service"}]
        if kind == "app":
            if components or application.attrib.get(namespace + "name"):
                raise SystemExit("Refusing QA app with components or custom Application initialization")
        else:
            instrumentation = manifest.find("instrumentation")
            if instrumentation is None or instrumentation.attrib.get(namespace + "targetPackage") != "com.momobio.app.qa" or instrumentation.attrib.get(namespace + "name") != "androidx.test.runner.AndroidJUnitRunner":
                raise SystemExit("Unexpected instrumentation target or runner")
        artifacts.append({"kind": kind, "path": str(artifact), "package": expected,
                          "sha256": hashlib.sha256(artifact.read_bytes()).hexdigest(),
                          "size": artifact.stat().st_size, "requested_permissions": permissions,
                          "components": components})
    result = {"result": "pass", "scope": "Isolated component-test APKs; not operational collector acceptance", "artifacts": artifacts}
    (args.output / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print("Both component-test APKs passed package, permission and target checks.")


if __name__ == "__main__":
    main()
