import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).resolve().parents[1] / "ci/check_repository_structure.py"
spec = importlib.util.spec_from_file_location("structure", MODULE)
structure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(structure)


class ArchitectureBoundaryTest(unittest.TestCase):
    def test_core_cannot_depend_on_a_feature(self):
        self.assertTrue(structure.boundary_errors("lib/core/location/service.dart", ["package:mobi_app/features/bookings/data/trip_service.dart"]))

    def test_data_cannot_import_a_screen(self):
        self.assertTrue(structure.boundary_errors("lib/features/bookings/data/service.dart", ["package:mobi_app/features/bookings/presentation/screen.dart"]))

    def test_domain_cannot_depend_on_platform_plugins(self):
        self.assertTrue(structure.boundary_errors("lib/features/biopay/domain/payment.dart", ["package:flutter_nfc_kit/flutter_nfc_kit.dart"]))

    def test_feature_can_use_shared_contracts(self):
        self.assertEqual(structure.boundary_errors("lib/features/bookings/data/service.dart", ["package:mobi_shared_types/models/trip.dart"]), [])

    def test_conditional_import_targets_are_checked(self):
        source = "import 'stub.dart' if (dart.library.io) 'native.dart';\n// import 'example.dart';"
        self.assertEqual(list(structure.dependencies(source)), ["stub.dart", "native.dart"])


if __name__ == "__main__":
    unittest.main()
