import importlib.util
from pathlib import Path
import tempfile
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


if __name__ == "__main__":
    unittest.main()
