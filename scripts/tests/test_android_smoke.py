import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[2]


class AndroidSmokeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "scripts/release").mkdir(parents=True)
        (self.root / "bin").mkdir()
        self.smoke = self.root / "scripts/release/smoke_android_release.sh"
        shutil.copy2(REPO / "scripts/release/smoke_android_release.sh", self.smoke)
        self.apk = self.root / "release.apk"
        self.apk.write_bytes(b"fixture apk")
        self.env = {
            **os.environ,
            "PATH": str(self.root / "bin") + os.pathsep + os.environ["PATH"],
            "ANDROID_SERIAL": "test-device",
            "ANDROID_RELEASE_APK": str(self.apk),
            "ANDROID_SMOKE_EVIDENCE_DIR": str(self.root / "evidence"),
            "ANDROID_SMOKE_WAIT_SECONDS": "0",
            "ANDROID_SMOKE_ALLOW_EMULATOR": "false",
            "APKSIGNER": str(self.root / "bin/apksigner"),
            "FAKE_ADB_LOG": str(self.root / "adb.log"),
            "FAKE_QEMU": "",
            "FAKE_BOOT_QEMU": "",
            "FAKE_ACTIVITY": "rw.mobi.app/.MainActivity",
        }
        self.write_executable("bin/apksigner", "#!/bin/sh\necho Verifies\n")
        self.write_executable("bin/adb", '''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
args = sys.argv[1:]
with Path(os.environ["FAKE_ADB_LOG"]).open("a") as f:
    f.write(" ".join(args) + "\\n")
if args == ["devices"]:
    print("List of devices attached\\n" + os.environ["ANDROID_SERIAL"] + "\\tdevice")
    sys.exit(0)
if args[:1] == ["-s"]:
    args = args[2:]
if args[:2] == ["shell", "getprop"]:
    prop = args[2]
    print({"ro.kernel.qemu": os.environ["FAKE_QEMU"],
           "ro.boot.qemu": os.environ["FAKE_BOOT_QEMU"]}.get(prop, "fixture"))
elif args[:2] == ["shell", "pidof"]:
    print("1234")
elif args[:4] == ["shell", "cmd", "package", "resolve-activity"]:
    print(os.environ["FAKE_ACTIVITY"])
elif args[:3] == ["shell", "dumpsys", "window"]:
    print("mCurrentFocus=Window{rw.mobi.app/MainActivity}")
elif args[:3] == ["shell", "dumpsys", "package"]:
    print("versionCode=17 versionName=1.0.0")
elif args[:2] == ["exec-out", "uiautomator"]:
    print("<hierarchy/>")
elif args[:1] == ["install"]:
    print("Success")
''')

    def write_executable(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        path.chmod(0o755)

    def run_smoke(self, **overrides):
        return subprocess.run(
            [str(self.smoke)], cwd=self.root,
            env={**self.env, **overrides}, text=True, capture_output=True,
        )

    def assert_rejected_before_install(self, result):
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("physical", result.stderr.lower())
        self.assertNotIn(" install ", (self.root / "adb.log").read_text())

    def test_emulator_serial_cannot_pass_physical_gate(self):
        self.assert_rejected_before_install(
            self.run_smoke(ANDROID_SERIAL="emulator-5580")
        )

    def test_qemu_property_cannot_pass_physical_gate(self):
        self.assert_rejected_before_install(self.run_smoke(FAKE_QEMU="1"))

    def test_boot_qemu_property_cannot_pass_physical_gate(self):
        self.assert_rejected_before_install(self.run_smoke(FAKE_BOOT_QEMU="1"))

    def test_emulator_opt_in_is_labeled_as_nonphysical(self):
        result = self.run_smoke(
            ANDROID_SERIAL="emulator-5580", ANDROID_SMOKE_ALLOW_EMULATOR="true"
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("emulator", result.stdout)
        evidence = next((self.root / "evidence").glob("*.log")).read_text()
        self.assertIn("device_type=emulator", evidence)
        self.assertIn("physical_device_evidence=false", evidence)

    def test_physical_device_passes_default_gate(self):
        result = self.run_smoke()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        evidence = next((self.root / "evidence").glob("*.log")).read_text()
        self.assertIn("device_type=physical", evidence)
        self.assertIn("physical_device_evidence=true", evidence)
        commands = (self.root / "adb.log").read_text()
        self.assertIn("am start -W -n rw.mobi.app/.MainActivity", commands)
        self.assertNotIn("monkey", commands)

    def test_unresolved_launcher_cannot_pass(self):
        result = self.run_smoke(FAKE_ACTIVITY="No activity found")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Could not resolve", result.stderr)
        self.assertNotIn("am start", (self.root / "adb.log").read_text())

    def test_production_gate_overrides_emulator_opt_in(self):
        gate = self.root / "scripts/release/go_no_go_check.sh"
        shutil.copy2(REPO / "scripts/release/go_no_go_check.sh", gate)
        for name in ["ci/verify_flutter.sh", "qa/scan_secrets.sh",
                     "qa/check_secret_history.sh", "ci/verify_backend.sh",
                     "ci/verify_release_config.sh", "qa/verify_mobio_feature_readiness.sh"]:
            self.write_executable("scripts/" + name, "#!/bin/sh\nexit 0\n")
        self.write_executable("scripts/release/smoke_android_release.sh",
                              '#!/bin/sh\nprintf "%s" "$ANDROID_SMOKE_ALLOW_EMULATOR" > emulator-flag.txt\n')
        subprocess.run([str(gate)], cwd=self.root,
                       env={**self.env, "ANDROID_SMOKE_ALLOW_EMULATOR": "true"},
                       capture_output=True, text=True, check=False)
        self.assertEqual((self.root / "emulator-flag.txt").read_text(), "false")


if __name__ == "__main__":
    unittest.main()
