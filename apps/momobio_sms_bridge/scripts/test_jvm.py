#!/usr/bin/env python3
"""Run Kotlin collector component tests using already cached, pinned JUnit.

No Gradle daemon, Android artifact, runtime configuration or network calls.
The JVM org.json implementation is a test oracle; Android uses its platform API.
The queue uses a preference double implementing the actual Android SDK interface.
Upload tests inject a synthetic signer/connection; no socket or key is created.
This does not test Android disk persistence, permissions or device behavior.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--android-jar", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    app = root / "apps/momobio_sms_bridge"
    cache = Path(os.environ.get("GRADLE_USER_HOME", Path.home() / ".gradle")) / "caches/modules-2/files-2.1"

    def jar(group, artifact, version):
        matches = sorted((cache / group / artifact / version).glob(f"*/{artifact}-{version}.jar"))
        if len(matches) != 1:
            raise SystemExit(f"Need exactly one cached {group}:{artifact}:{version}; found {len(matches)}. No download attempted.")
        return matches[0]

    compiler = [
        jar("org.jetbrains.kotlin", "kotlin-compiler-embeddable", "2.2.20"),
        jar("org.jetbrains.kotlin", "kotlin-stdlib", "2.2.20"),
        jar("org.jetbrains.kotlin", "kotlin-script-runtime", "2.2.20"),
        jar("org.jetbrains.kotlin", "kotlin-reflect", "1.6.10"),
        jar("org.jetbrains.kotlin", "kotlin-daemon-embeddable", "2.2.20"),
        jar("org.jetbrains.kotlinx", "kotlinx-coroutines-core-jvm", "1.8.0"),
        jar("org.jetbrains.intellij.deps", "trove4j", "1.0.20200330"),
        jar("org.jetbrains", "annotations", "13.0"),
    ]
    runtime = [
        compiler[1],
        jar("junit", "junit", "4.13.2"),
        jar("org.hamcrest", "hamcrest-core", "1.3"),
        jar("org.json", "json", "20250517"),
    ]
    sdk = Path(os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT", Path.home() / "Library/Android/sdk")))
    android_jar = args.android_jar or sdk / "platforms/android-36/android.jar"
    if not android_jar.is_file():
        raise SystemExit("Existing Android 36 android.jar required; use --android-jar. No download attempted.")
    runtime.append(android_jar)
    sources = [
        app / "app/src/main/java/com/momobio/app/MomoSms.kt",
        app / "app/src/test/java/com/momobio/app/MomoSmsTest.kt",
        app / "app/src/main/java/com/momobio/app/SmsQueue.kt",
        app / "app/src/test/java/com/momobio/app/SmsQueueTest.kt",
        app / "app/src/main/java/com/momobio/app/UploadClient.kt",
        app / "app/src/test/java/com/momobio/app/UploadClientTest.kt",
        app / "app/src/main/java/com/momobio/app/CollectorIdentity.kt",
        app / "app/src/main/java/com/momobio/app/SmsReceiptDecoder.kt",
        app / "app/src/test/java/com/momobio/app/SmsReceiptDecoderTest.kt",
    ]
    # Resolve the public constructor's constants from an actual prior QA build.
    # Do not fabricate a production-looking runtime configuration for tests.
    build_config = app / "app/build/generated/source/buildConfig/qa/com/momobio/app/BuildConfig.java"
    if not build_config.is_file():
        raise SystemExit("Run the isolated :app:generateQaBuildConfig task first; no BuildConfig stub is generated here.")
    sources.append(build_config)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    classes = output / "classes"
    classes.mkdir(exist_ok=True)
    manifest = {
        "scope": "Actual codec, queue and upload orchestration on JVM/JUnit with preference/transport/signing doubles; not Android runtime/provider acceptance",
        "kotlin": "2.2.20",
        "files": [
            {"path": str(p), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
            for p in dict.fromkeys([Path(__file__).resolve(), *sources, *compiler, *runtime])
        ],
    }
    (output / "inputs.json").write_text(json.dumps(manifest, indent=2) + "\n")
    command = [
        "java", "-Xmx256m", "-cp", os.pathsep.join(map(str, compiler)),
        "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler", "-no-stdlib", "-no-reflect",
        "-jvm-target", "17", "-classpath", os.pathsep.join(map(str, runtime)),
        "-d", str(classes), *map(str, sources),
    ]
    subprocess.run(command, check=True)
    result = subprocess.run([
        "java", "-Xmx128m", "-cp", os.pathsep.join(map(str, [classes, *runtime])),
        "org.junit.runner.JUnitCore", "com.momobio.app.MomoSmsTest", "com.momobio.app.SmsQueueTest", "com.momobio.app.UploadClientTest", "com.momobio.app.SmsReceiptDecoderTest",
    ])
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
