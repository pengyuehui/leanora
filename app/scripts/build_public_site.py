#!/usr/bin/env python3
"""Build the static Leanora product website and a self-contained SCP package."""

from hashlib import sha256
from html import escape
import json
from pathlib import Path
import shutil
from string import Template
from zipfile import ZIP_DEFLATED, ZipFile

from render_privacy_policy import render_body


APP = Path(__file__).resolve().parent.parent
SOURCE = APP / "website-src"
OUTPUT = APP / "website"

PAGES = (
    ("/", "home.html", "Leanora · 围棋复盘与健身饮食记录", "探索 Leanora AI 围棋复盘与 Leanora Fitness 训练饮食日记，找到适合自己的日常练习工具。", "home-page", "home"),
    ("/go/", "go.html", "Leanora AI · 围棋复盘与练习", "看懂一盘棋的亮点与关键手，完成短训练，为下一盘找到明确目标。", "product-theme go-theme", "go"),
    ("/fitness/", "fitness.html", "Leanora Fitness · 训练与饮食日记", "自建训练计划、逐组记录、按餐记饮食、回看身体趋势，按需连接 Apple Health。", "product-theme fitness-theme", "fitness"),
    ("/support/", "support.html", "支持中心 · Leanora", "按产品查找 Leanora 围棋复盘和健身饮食的使用帮助、联系入口与隐私说明。", "support-page", "support"),
    ("/go/support/", "go-support.html", "围棋使用支持 · Leanora AI", "了解围棋复盘总结、关键手、训练、周报与隐私问题的联系入口。", "support-page", "support"),
    ("/policies/", "policies.html", "隐私中心 · Leanora", "分别了解 Leanora AI 围棋产品和 Leanora Fitness 健身产品的数据处理与隐私选择。", "policies-page", "policies"),
)

NAVIGATION = (("/", "首页", "home"), ("/go/", "围棋复盘", "go"), ("/fitness/", "训练与饮食", "fitness"), ("/support/", "支持", "support"))

ASSETS = {
    "fitness-today.png": APP / "store/zh-Hans/source/store-01-today.png",
    "fitness-workout.png": APP / "store/zh-Hans/source/store-03-workout.png",
    "fitness-food.png": APP / "store/zh-Hans/source/store-04-nutrition.png",
    "fitness-trends.png": APP / "store/zh-Hans/source/store-06-trends.png",
    "fitness-icon.png": APP / "store/brand/app-icon-1024.png",
}


def navigation(active: str) -> str:
    return "\n".join(
        f'<a href="{path}"' + (' aria-current="page"' if key == active else "") + f'>{label}</a>'
        for path, label, key in NAVIGATION
    )


def page(path: str, title: str, description: str, body_class: str, active: str, content: str) -> str:
    template = Template((SOURCE / "base.html").read_text(encoding="utf-8"))
    return template.substitute(
        path=escape(path, quote=True), title=escape(title), description=escape(description, quote=True),
        body_class=escape(body_class, quote=True), navigation=navigation(active), content=content,
    )


def legal_content(body: str, product: str, product_path: str, label: str) -> str:
    return (
        '<div class="legal-wrap"><nav class="breadcrumbs" aria-label="当前位置">'
        '<a href="/">Leanora</a><span aria-hidden="true">/</span>'
        f'<a href="{product_path}">{product}</a><span aria-hidden="true">/</span><span>{label}</span>'
        f'</nav><article class="legal-content">{body}</article></div>'
    )


def write_page(path: str, html: str) -> Path:
    target = OUTPUT / path.lstrip("/") / "index.html"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(html, encoding="utf-8")
    return target


def build() -> list[Path]:
    files = []
    for path, source, title, description, body_class, active in PAGES:
        content = (SOURCE / "pages" / source).read_text(encoding="utf-8")
        files.append(write_page(path, page(path, title, description, body_class, active, content)))

    # Preserve the published policy text and existing App Store URL.
    go_body = (SOURCE / "pages/go-privacy.html").read_text(encoding="utf-8")
    files.append(write_page("/privacy/", page(
        "/privacy/", "围棋隐私政策 · Leanora AI", "Leanora AI 围棋产品的隐私政策、可选诊断、儿童隐私及数据删除说明。",
        "legal-page", "", legal_content(go_body, "Leanora AI", "/go/", "隐私政策"),
    )))
    for source, path, title, description, label in (
        ("privacy-policy.md", "/fitness/privacy/", "健身隐私政策 · Leanora Fitness", "Leanora Fitness 的本机记录、Apple Health、文件备份、导出及删除说明。", "隐私政策"),
        ("support.md", "/fitness/support/", "健身使用支持 · Leanora Fitness", "Leanora Fitness 训练、饮食、健康同步及备份的使用帮助与联系方式。", "使用支持"),
    ):
        body = render_body((APP / "docs" / source).read_text(encoding="utf-8"))
        files.append(write_page(path, page(
            path, title, description, "legal-page", "fitness",
            legal_content(body, "Leanora Fitness", "/fitness/", label),
        )))

    target_assets = OUTPUT / "site-assets"
    target_assets.mkdir(parents=True, exist_ok=True)
    for asset in sorted((SOURCE / "assets").iterdir()):
        if asset.is_file():
            target = target_assets / asset.name
            shutil.copyfile(asset, target)
            files.append(target)
    for name, source in ASSETS.items():
        target = target_assets / name
        shutil.copyfile(source, target)
        files.append(target)

    routes = [{"path": path, "file": str(file.relative_to(OUTPUT))} for path, file in (
        ("/" if file.parent == OUTPUT else "/" + str(file.parent.relative_to(OUTPUT)) + "/", file)
        for file in files if file.name == "index.html"
    )]
    manifest = {
        "domain": "https://leanora.ai", "routes": routes, "tracking": False,
        "files": [{"path": str(file.relative_to(OUTPUT)), "bytes": file.stat().st_size,
                   "sha256": sha256(file.read_bytes()).hexdigest()} for file in sorted(files)],
    }
    (OUTPUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    archive = APP / "build/leanora-dual-product-website.zip"
    archive.parent.mkdir(parents=True, exist_ok=True)
    # Include only generated public files; no app repository, account data or build logs.
    with ZipFile(archive, "w", compression=ZIP_DEFLATED) as bundle:
        for file in sorted(files):
            bundle.write(file, file.relative_to(OUTPUT))
        bundle.write(OUTPUT / "manifest.json", "manifest.json")
    print(f"Built {len(routes)} pages, {len(files) - len(routes)} assets: {archive}")
    return files


if __name__ == "__main__":
    build()
