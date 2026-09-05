import importlib.util
from pathlib import Path
import tempfile
import subprocess
import json
import os
import sys
import unittest

MODULE = Path(__file__).resolve().parents[1] / "lib/runtime_defines.py"
spec = importlib.util.spec_from_file_location("runtime_defines", MODULE)
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)


class RuntimeDefinesTest(unittest.TestCase):
    def setUp(self):
        self.public = {key: "public-example" for key in runtime.REQUIRED}

    def test_server_secrets_never_enter_the_client_build(self):
        dotenv = {**self.public, "SUPABASE_SERVICE_ROLE_KEY": "server-only"}
        result = runtime.public_defines(dotenv, {"AWS_SECRET_ACCESS_KEY": "server-only"})
        self.assertEqual(result, self.public)

    def test_environment_overrides_dotenv_and_empty_values_fall_back(self):
        result = runtime.public_defines(
            self.public, {"SUPABASE_URL": "https://override.example", "SUPABASE_ANON_KEY": ""}
        )
        self.assertEqual(result["SUPABASE_URL"], "https://override.example")
        self.assertEqual(result["SUPABASE_ANON_KEY"], "public-example")

    def test_missing_values_fail_without_printing_configuration(self):
        with self.assertRaisesRegex(ValueError, "Missing PRIVACY_POLICY_URL, ACCOUNT_DELETION_URL"):
            runtime.public_defines({"SUPABASE_URL": "private-example", "SUPABASE_ANON_KEY": "private-example"}, {})

    def test_dotenv_is_parsed_literally_without_shell_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text("# comment\nexport SUPABASE_URL='https://example.test?a=b'\nVALUE=$(touch should-not-exist)\n")
            values = runtime.parse_dotenv(path)
            self.assertEqual(values["SUPABASE_URL"], "https://example.test?a=b")
            self.assertEqual(values["VALUE"], "$(touch should-not-exist)")
            self.assertFalse((Path(directory) / "should-not-exist").exists())

    def test_ios_requires_its_own_registration(self):
        with self.assertRaisesRegex(ValueError, "Missing FIREBASE_IOS_APP_ID"):
            runtime.public_defines(self.public, {}, "ios")
        with self.assertRaisesRegex(ValueError, "registered iOS Firebase App ID"):
            runtime.public_defines(
                {**self.public, "FIREBASE_IOS_APP_ID": "1:123:android:abc"}, {}, "ios"
            )

    def test_ios_only_adds_public_platform_fields(self):
        dotenv = {
            **self.public,
            "FIREBASE_IOS_APP_ID": "1:123:ios:abc",
            "FIREBASE_IOS_API_KEY": "ios-public-key",
            "FIREBASE_IOS_BUNDLE_ID": "rw.mobi.app",
            "FIREBASE_PRIVATE_KEY": "server-only",
            "SUPABASE_SERVICE_ROLE_KEY": "server-only",
        }
        result = runtime.public_defines(dotenv, {}, "ios")
        self.assertEqual(result["FIREBASE_IOS_API_KEY"], "ios-public-key")
        self.assertEqual(set(result), set(self.public) | {
            "FIREBASE_IOS_APP_ID", "FIREBASE_IOS_API_KEY", "FIREBASE_IOS_BUNDLE_ID"
        })
        self.assertEqual(runtime.public_defines(dotenv, {}), self.public)

    def test_cli_ios_file_is_private_and_does_not_execute_dotenv(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lines = [f"{key}={value}" for key, value in self.public.items()]
            lines += ["FIREBASE_IOS_APP_ID=1:123:ios:abc",
                      "FIREBASE_IOS_API_KEY=$(touch injected)",
                      "FIREBASE_PRIVATE_KEY=server-only"]
            (root / ".env").write_text("\n".join(lines))
            output = root / "defines.json"
            output.write_text("old")
            output.chmod(0o644)
            env = {key: value for key, value in os.environ.items()
                   if key not in self.public and not key.startswith("FIREBASE_")}
            result = subprocess.run(
                [sys.executable, str(MODULE), str(output), "--platform", "ios"],
                cwd=root, env=env, capture_output=True, text=True, check=True,
            )
            values = json.loads(output.read_text())
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)
            self.assertEqual(values["FIREBASE_IOS_API_KEY"], "$(touch injected)")
            self.assertNotIn("FIREBASE_PRIVATE_KEY", values)
            self.assertFalse((root / "injected").exists())
            self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
