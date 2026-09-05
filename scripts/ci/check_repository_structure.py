#!/usr/bin/env python3
"""Validate Mobio's source boundaries, import targets, and tracked-file hygiene."""

from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PACKAGE_ROOTS = {
    "mobi_app": "lib",
    "mobi_design_system": "packages/design-system/lib",
    "mobi_shared_types": "packages/shared-types/lib",
    "lucide_icons": "packages/lucide_icons_compat/lib",
}
RETIRED = (
    "lib/models", "lib/providers", "lib/core/services", "lib/core/providers",
    "lib/core/router", "lib/core/theme", "agents", "integrations", "infra",
)


def dependencies(source):
    # Includes conditional import/export URIs, without matching example comments.
    for directive in re.findall(r"^(?:import|export)\s+[^;]+;", source, re.M):
        yield from re.findall(r"['\"]([^'\"]+)['\"]", directive)


def boundary_errors(path, imports):
    errors = []
    for uri in imports:
        target = uri.removeprefix("package:mobi_app/")
        if path.startswith("lib/core/") and uri.startswith("package:mobi_app/"):
            if target.startswith(("app/", "features/", "shared/")):
                errors.append(f"{path}: core cannot depend on app code ({uri})")
        if path.startswith("lib/features/") and "/data/" in path:
            if uri.startswith("package:mobi_app/") and ("/application/" in target or "/presentation/" in target or target.startswith("app/")):
                errors.append(f"{path}: data cannot depend on application or presentation ({uri})")
        if path.startswith("lib/features/") and "/domain/" in path:
            if any(token in uri for token in ("package:flutter", "package:supabase", "/data/", "/application/", "/presentation/")):
                errors.append(f"{path}: domain must remain independent of UI and services ({uri})")
        if path.startswith("packages/") and uri.startswith("package:mobi_app/"):
            errors.append(f"{path}: packages cannot import the app ({uri})")
        if path.startswith("packages/shared-types/") and uri.startswith(("package:flutter", "package:supabase")):
            errors.append(f"{path}: shared contracts must remain pure Dart ({uri})")
    return errors


def main():
    files = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
    ).decode().split("\0")
    files = sorted({path for path in files if path and (ROOT / path).is_file()})
    errors = []
    for path in RETIRED:
        if (ROOT / path).exists():
            errors.append(f"Retired boundary reintroduced: {path}")
    for path in files:
        if "/failures/" in path or path.endswith((".log", ".pyc", ".freezed.dart", ".g.dart")) or path == "android/fastlane/report.xml":
            errors.append(f"Generated output must not be tracked: {path}")
        if path.startswith("lib/features/"):
            layer = Path(path).parts[3]
            if layer not in {"application", "data", "domain", "presentation"}:
                errors.append(f"Feature file has no layer: {path}")
        if not path.endswith(".dart") or not path.startswith(("lib/", "packages/", "test/", "tool/")):
            continue
        imports = list(dependencies((ROOT / path).read_text()))
        errors.extend(boundary_errors(path, imports))
        for uri in imports:
            if not uri.startswith("package:"):
                if uri.startswith("dart:"):
                    continue
                target = ROOT / Path(path).parent / uri
            else:
                package, _, relative = uri[len("package:"):].partition("/")
                if package not in PACKAGE_ROOTS:
                    continue
                target = ROOT / PACKAGE_ROOTS[package] / relative
            if not target.is_file():
                errors.append(f"{path}: missing import/export target {uri}")
    for package in (ROOT / "packages").iterdir():
        if package.is_dir() and not (package / "pubspec.yaml").is_file():
            errors.append(f"Placeholder package has no pubspec: {package.name}")
    for app in (ROOT / "apps").iterdir():
        if app.is_dir() and not any((app / name).is_file() for name in ("pubspec.yaml", "build.gradle.kts")):
            errors.append(f"Placeholder app has no build definition: {app.name}")
    version = (ROOT / ".flutter-version").read_text().strip()
    for workflow in (ROOT / ".github/workflows").glob("*.yml"):
        for configured in re.findall(r"flutter-version: ['\"]([^'\"]+)['\"]", workflow.read_text()):
            if configured != version:
                errors.append(f"{workflow.name}: Flutter {configured} differs from .flutter-version ({version})")
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Repository structure passed: {len(files)} source/document files; Flutter {version}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
