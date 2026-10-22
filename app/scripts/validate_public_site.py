#!/usr/bin/env python3
"""Check the deployable site's routes, assets and product-policy boundaries."""

from hashlib import sha256
from html.parser import HTMLParser
import json
from pathlib import Path
from urllib.parse import unquote, urlsplit
from zipfile import ZipFile

from render_privacy_policy import render_body


APP = Path(__file__).resolve().parent.parent
ROOT = APP / "website"
VOID_ELEMENTS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}


class Document(HTMLParser):
    def __init__(self):
        super().__init__()
        self.h1_count = 0
        self.references = []
        self.ids = set()
        self.text = []
        self.legal_text = []
        self.legal_depth = 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "h1":
            self.h1_count += 1
        if "id" in attrs:
            assert attrs["id"] not in self.ids, f"Duplicate id: {attrs['id']}"
            self.ids.add(attrs["id"])
        if tag in {"a", "link"} and attrs.get("href"):
            self.references.append(attrs["href"])
        if tag in {"script", "img"} and attrs.get("src"):
            self.references.append(attrs["src"])
        if tag == "img":
            assert "alt" in attrs, "Image missing alternative text"
        if "legal-content" in attrs.get("class", "").split():
            self.legal_depth = 1
        elif self.legal_depth and tag not in VOID_ELEMENTS:
            self.legal_depth += 1

    def handle_endtag(self, tag):
        if self.legal_depth and tag not in VOID_ELEMENTS:
            self.legal_depth -= 1

    def handle_data(self, data):
        self.text.append(data)
        if self.legal_depth:
            self.legal_text.append(data)


def parsed(html):
    document = Document()
    document.feed(html)
    return document


def normalized(chunks):
    return " ".join(" ".join(chunks).split())


if __name__ == "__main__":
    manifest = json.loads((ROOT / "manifest.json").read_text())
    pages = {route["path"]: parsed((ROOT / route["file"]).read_text()) for route in manifest["routes"]}
    assert {"/", "/go/", "/fitness/", "/support/", "/go/support/", "/policies/", "/privacy/", "/fitness/privacy/", "/fitness/support/"} == set(pages)
    checked = 0
    for route, document in pages.items():
        assert document.h1_count == 1, f"Expected one h1: {route}"
        for reference in document.references:
            target = urlsplit(reference)
            if target.scheme == "mailto":
                continue
            if target.netloc and target.netloc != "leanora.ai":
                raise AssertionError(f"Unexpected external dependency: {reference}")
            path = unquote(target.path) or route
            if path.endswith("/"):
                assert path in pages, f"Unknown route: {reference}"
                if target.fragment:
                    assert target.fragment in pages[path].ids, f"Broken anchor: {reference}"
            else:
                assert (ROOT / path.lstrip("/")).is_file(), f"Missing asset: {reference}"
            checked += 1
    for filename, route in (("privacy-policy.md", "/fitness/privacy/"), ("support.md", "/fitness/support/")):
        expected = parsed(render_body((APP / "docs" / filename).read_text()))
        assert normalized(pages[route].legal_text) == normalized(expected.text), f"Fitness body changed: {route}"
    expected_go = parsed((APP / "website-src/pages/go-privacy.html").read_text())
    assert normalized(pages["/privacy/"].legal_text) == normalized(expected_go.text), "Go policy body changed"
    assert "Firebase Crashlytics" not in normalized(pages["/fitness/privacy/"].legal_text)
    assert "Apple Health" not in normalized(pages["/privacy/"].legal_text)
    with ZipFile(APP / "build/leanora-dual-product-website.zip") as bundle:
        expected = {entry["path"] for entry in manifest["files"]} | {"manifest.json"}
        assert set(bundle.namelist()) == expected, "Deployment archive contains unexpected files"
        for entry in manifest["files"]:
            data = (ROOT / entry["path"]).read_bytes()
            assert sha256(data).hexdigest() == entry["sha256"]
            assert bundle.read(entry["path"]) == data
    print(json.dumps({"pages": len(pages), "local_references": checked, "policy_bodies_preserved": True, "archive_matches_manifest": True}))
