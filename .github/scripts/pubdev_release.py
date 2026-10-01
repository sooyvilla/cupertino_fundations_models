import json
import os
import re
import subprocess
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


PACKAGE = "cupertino_fundations_models"
VERSION_PATTERN = re.compile(
    r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
)


def field(manifest, key):
    matches = re.findall(
        rf"^{key}:[ \t]*(['\"]?)([0-9A-Za-z_.+-]+)\1[ \t]*(?:#.*)?$",
        manifest,
        re.MULTILINE,
    )
    if len(matches) != 1:
        raise SystemExit(f"Expected one literal {key} field in pubspec.yaml.")
    return matches[0][1]


def git(*args):
    return subprocess.run(
        ["git", *args], check=True, capture_output=True, text=True
    ).stdout.strip()


def published(version):
    url = f"https://pub.dev/api/packages/{PACKAGE}/versions/{quote(version, safe='')}"
    request = Request(url, headers={"Accept": "application/json"})
    try:
        with urlopen(request, timeout=30) as response:
            data = json.load(response)
    except HTTPError as error:
        if error.code == 404:
            return False
        raise SystemExit(f"pub.dev returned HTTP {error.code}; release stopped.")
    except (URLError, TimeoutError, ValueError):
        raise SystemExit("Could not read pub.dev version status; release stopped.")
    if not isinstance(data, dict) or data.get("version") != version:
        raise SystemExit("Unexpected pub.dev version response; release stopped.")
    return True


def finish(message, *, tag="", create_tag=False, publish=False):
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        output.write(f"tag={tag}\n")
        output.write(f"create_tag={str(create_tag).lower()}\n")
        output.write(f"publish={str(publish).lower()}\n")
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
        summary.write(f"{message}\n")
    print(message)


def main():
    manifest = Path("pubspec.yaml").read_text(encoding="utf-8")
    if field(manifest, "name") != PACKAGE:
        raise SystemExit("Package name differs from the configured pub.dev package.")
    version = field(manifest, "version")
    if not VERSION_PATTERN.fullmatch(version):
        raise SystemExit("Expected a semantic version in pubspec.yaml.")
    prerelease = version.split("+", 1)[0].partition("-")[2]
    if any(
        part.isdigit() and len(part) > 1 and part.startswith("0")
        for part in prerelease.split(".")
    ):
        raise SystemExit("Numeric prerelease identifiers cannot have leading zeros.")
    tag = f"v{version}"
    ref = os.environ["GITHUB_REF"]
    if ref == "refs/heads/main":
        event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
        before = event.get("before", "")
        if not re.fullmatch(r"[0-9a-f]{40}", before) or before == "0" * 40:
            raise SystemExit("Cannot compare with the previous main commit; release stopped.")
        previous = field(git("show", f"{before}:pubspec.yaml"), "version")
        if previous == version:
            finish(f"Version {version} is unchanged. Publication skipped.")
            return
        if git("rev-parse", "HEAD") != os.environ["GITHUB_SHA"]:
            raise SystemExit("Checkout does not match the main push commit.")
    elif ref.startswith("refs/tags/"):
        if ref != f"refs/tags/{tag}":
            raise SystemExit("Tag must exactly match v<version> from pubspec.yaml.")
        result = subprocess.run(
            ["git", "merge-base", "--is-ancestor", "HEAD", "origin/main"],
            capture_output=True,
        )
        if result.returncode != 0:
            raise SystemExit("Release commit must belong to main.")
    else:
        raise SystemExit("Releases require a main push or a version tag push.")
    if published(version):
        finish(f"Version {version} already exists on pub.dev. Publication skipped.")
        return
    if ref.startswith("refs/tags/"):
        finish(f"Publish {version} from {tag}.", tag=tag, publish=True)
        return
    existing = subprocess.run(
        ["git", "rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}"],
        capture_output=True, text=True,
    )
    if existing.returncode == 0:
        if existing.stdout.strip() != os.environ["GITHUB_SHA"]:
            raise SystemExit(f"Tag {tag} already points to another commit; release stopped.")
        finish(
            f"Tag {tag} already exists. If publishing failed, rerun its original tag workflow."
        )
        return
    finish(
        f"Version changed from {previous} to {version}. Create {tag}.",
        tag=tag,
        create_tag=True,
    )


if __name__ == "__main__":
    main()
