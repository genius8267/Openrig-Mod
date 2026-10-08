#!/usr/bin/env python3
"""Check this repository for secrets and personal data before a push.

Usage: python3 tools/check-publish-safety.py

It scans every tracked or new (not ignored) file for:
  - secrets: private keys, API tokens, passwords in assignments
  - personal data: e-mail addresses, home folder paths, Tailscale and LAN addresses
  - your own private words, one regular expression per line, from
    .git/info/private-patterns (never committed) or the file named in
    OPENRIG_MOD_PRIVATE_PATTERNS. Put names, host names and project names there.
It also checks that every commit author e-mail is a GitHub noreply address,
and it runs gitleaks on the files and the history when gitleaks is installed.

A line that contains the text "publish-safety: allow" is skipped.
The exit code is 0 when nothing was found, 1 when something was found.
Findings show the file, the line and the rule, never the matched text.
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True,
                           text=True, check=True).stdout.strip())
ALLOW_MARK = "publish-safety: allow"

RULES = [
    ("private key", r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    ("GitHub token", r"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}|\bgithub_pat_[A-Za-z0-9_]{20,}"),
    ("API key (sk-)", r"\bsk-(ant-)?[A-Za-z0-9_-]{20,}"),
    ("Slack token", r"\bxox[abprs]-[A-Za-z0-9-]{10,}"),
    ("AWS key", r"\bAKIA[0-9A-Z]{16}\b"),
    ("Google API key", r"\bAIza[0-9A-Za-z_-]{35}\b"),
    ("JWT", r"\beyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\."),
    ("secret assignment",
     r"(?i)\b(api[_-]?key|token|secret|passw(or)?d|bearer)\b[\"']?\s*[:=]\s*[\"'][^\"'\s<>$]{8,}[\"']"),
    ("e-mail address",
     r"\b[A-Za-z0-9._%+-]+@(?!users\.noreply\.github\.com\b|example\.(com|org|net)\b)"
     r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}\b"),
    ("home folder path", r"(/Users|/home)/(?!<|\$|you\b|me\b|USER\b|runner\b)[A-Za-z0-9._-]+"),
    ("Tailscale address", r"\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.\d{1,3}\.\d{1,3}\b"),
    ("Tailscale name", r"\b[a-z0-9-]+\.ts\.net\b"),
    ("LAN address", r"\b(10\.\d{1,3}|192\.168|172\.(1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b"),
]


def private_rules():
    candidates = [os.environ.get("OPENRIG_MOD_PRIVATE_PATTERNS", ""), str(ROOT / ".git/info/private-patterns")]
    for name in candidates:
        if name and Path(name).is_file():
            rules = []
            for n, line in enumerate(Path(name).read_text().splitlines(), 1):
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                try:
                    rules.append((f"private word ({Path(name).name}:{n})", re.compile(line, re.I)))
                except re.error as e:
                    sys.exit(f"Bad pattern in {name}:{n}: {e}")
            return name, rules
    return None, []


def files():
    out = subprocess.run(["git", "ls-files", "-z", "-co", "--exclude-standard"], cwd=ROOT,
                         capture_output=True, check=True).stdout.decode()
    return [ROOT / f for f in out.split("\0") if f]


def main():
    rules = [(name, re.compile(rx)) for name, rx in RULES]
    source, extra = private_rules()
    rules += extra
    findings = []
    scanned = 0
    for path in files():
        rel = path.relative_to(ROOT)
        if not path.is_file():
            continue
        if path.name.startswith(".env"):
            findings.append(f"{rel}: an .env file must not be published")
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            findings.append(f"{rel}: binary file; check it by hand")
            continue
        scanned += 1
        for n, line in enumerate(text.splitlines(), 1):
            if ALLOW_MARK in line:
                continue
            for name, rx in rules:
                if rx.search(line):
                    findings.append(f"{rel}:{n}: {name}")
        for name, rx in extra:
            if rx.search(str(rel)):
                findings.append(f"{rel}: file name matches {name}")

    has_commits = subprocess.run(["git", "rev-parse", "-q", "--verify", "HEAD"], cwd=ROOT,
                                 capture_output=True).returncode == 0
    if has_commits:
        emails = subprocess.run(["git", "log", "--all", "--format=%ae%n%ce"], cwd=ROOT,
                                capture_output=True, text=True, check=True).stdout.split()
        bad = sorted({e for e in emails if not e.endswith("@users.noreply.github.com")})
        if bad:
            findings.append(f"git history: {len(bad)} commit e-mail(s) are not GitHub noreply addresses")

    leaks = "not installed (skipped)"
    if shutil.which("gitleaks"):
        modes = [["dir", "."]] + ([["git", "."]] if has_commits else [])
        results = []
        for mode in modes:
            r = subprocess.run(["gitleaks", *mode, "--no-banner", "--redact", "--log-level", "error"],
                               cwd=ROOT, capture_output=True, text=True)
            results.append(f"{mode[0]} {'clean' if r.returncode == 0 else 'FOUND LEAKS'}")
            if r.returncode != 0:
                findings.append(f"gitleaks {mode[0]}: leaks found; run: gitleaks {' '.join(mode)} --redact -v")
        leaks = ", ".join(results)

    print(f"Scanned {scanned} files with {len(rules)} rules "
          f"({len(extra)} private, from {source or 'no private-patterns file'}). gitleaks: {leaks}.")
    if not source:
        print("Tip: list your own names, host names and project names in .git/info/private-patterns.")
    if findings:
        print(f"\n{len(findings)} finding(s):")
        for f in findings:
            print("  " + f)
        return 1
    print("Nothing found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
