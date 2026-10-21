#!/usr/bin/env python3
"""Render the policy's small Markdown subset as a standalone publishable page."""

from html import escape
from pathlib import Path
import re


def inline(text: str) -> str:
    text = escape(text)
    text = re.sub(r"\[([^\]]+)\]\((https://[^\s)]+|mailto:[^\s)]+)\)", r'<a href="\2">\1</a>', text)
    return re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)


def render(markdown: str) -> str:
    sections = []
    for paragraph in markdown.strip().split("\n\n"):
        if paragraph.startswith("## "):
            sections.append(f"<h2>{inline(paragraph[3:])}</h2>")
        elif paragraph.startswith("# "):
            sections.append(f"<h1>{inline(paragraph[2:])}</h1>")
        else:
            sections.append(f"<p>{inline(paragraph)}</p>")
    body = "\n".join(sections)
    return f"""<!doctype html>
<html lang="zh-Hans">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Leanora 训练与饮食记录 App 隐私政策，运营主体 Manyao Li。">
  <title>Leanora 隐私政策</title>
  <style>
    :root {{ color-scheme: light dark; }}
    body {{ margin: 0; background: light-dark(#f5f6f8, #121418); color: light-dark(#20242b, #eef0f3); font: 17px/1.8 system-ui, sans-serif; }}
    main {{ max-width: 46rem; margin: 0 auto; padding: 2.5rem 1.25rem 4rem; overflow-wrap: anywhere; }}
    h1 {{ font-size: 2rem; line-height: 1.3; }}
    h2 {{ font-size: 1.25rem; line-height: 1.4; margin-top: 2rem; }}
    a {{ color: light-dark(#2259bf, #9dbdff); text-underline-offset: .15em; }}
    a:focus-visible {{ outline: 3px solid currentColor; outline-offset: 4px; }}
  </style>
</head>
<body><main>
{body}
</main></body>
</html>
"""


if __name__ == "__main__":
    docs = Path(__file__).resolve().parent.parent / "docs"
    target = docs / "privacy-policy.html"
    target.write_text(render((docs / "privacy-policy.md").read_text(encoding="utf-8")), encoding="utf-8")
    print(target)
