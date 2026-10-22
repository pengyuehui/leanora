#!/usr/bin/env python3
"""Build the two static pages for the user-approved leanora.ai domain."""

from pathlib import Path

from render_privacy_policy import render


if __name__ == "__main__":
    app = Path(__file__).resolve().parent.parent
    pages = (
        ("privacy-policy.md", "index.html", "Leanora 隐私政策", "Leanora Fitness 隐私政策：本机记录、Apple Health、备份及删除。"),
        ("support.md", "support/index.html", "Leanora 支持", "Leanora Fitness 使用帮助、Apple Health 同步、备份与支持联系方式。"),
    )
    for source, destination, title, description in pages:
        target = app / "website" / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render((app / "docs" / source).read_text(encoding="utf-8"), title=title, description=description, navigation=True), encoding="utf-8")
        print(target.relative_to(app))
