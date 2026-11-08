#!/usr/bin/env python3
"""检查 App 的 String Catalog：每条要翻译的文字都有简体、繁体、英文、日文，占位符（%@、%lld）和原文对得上；
App 代码里的 String(localized:) 都带 bundle: .ui（换语言马上生效靠它）。

App 的开发语言是英文（别的语言的手机看英文），所以一条文字没有简体值时，简体手机会看到英文。
改了 Localizable.xcstrings 以后跑一下：python3 tools/check-strings.py
"""
import json, re, sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parent.parent / "app/MajiangApp/Resources/Localizable.xcstrings"
LANGS = ["zh-Hans", "zh-Hant", "en", "ja"]
SPEC = re.compile(r"%(?:\d\$)?(lld|@)")


def values(loc):
    unit = loc.get("stringUnit")
    if unit:
        yield unit["value"]
    for cases in loc.get("variations", {}).values():
        for case in cases.values():
            yield from values(case)


problems = []
strings = json.loads(CATALOG.read_text())["strings"]
for key, entry in strings.items():
    if entry.get("shouldTranslate") is False:
        continue
    locs = entry.get("localizations", {})
    source = next(values(locs["zh-Hans"]), key) if "zh-Hans" in locs else key
    want = sorted(SPEC.findall(source))
    for lang in LANGS:
        if lang not in locs:
            problems.append(f"{lang} 没有：{key!r}")
            continue
        for value in values(locs[lang]):
            # 英文的复数写法（one / other）里，one 可以不带数字
            if sorted(SPEC.findall(value)) != want and "variations" not in locs[lang]:
                problems.append(f"{lang} 占位符和原文不一样：{key!r} → {value!r}")

# App 里取字要带 bundle: .ui，不然在「更多 › 语言」里换了语言，这句还是启动时的语言（见 AppLanguage.swift）
APP = CATALOG.parent.parent
for swift in sorted(APP.rglob("*.swift")):
    text = swift.read_text()
    for m in re.finditer(r"String\(localized:", text):
        # 一次调用最多看到下一个 String( 或 30 行为止
        rest = text[m.end():]
        stop = rest.find("String(")
        chunk = rest[: stop if stop >= 0 else len(rest)]
        chunk = "\n".join(chunk.splitlines()[:30])
        if "bundle: .ui" not in chunk:
            line = text[: m.start()].count("\n") + 1
            problems.append(f"没带 bundle: .ui：{swift.relative_to(APP.parent)}:{line}")

print("\n".join(problems) or f"没问题：{len(strings)} 条")
sys.exit(1 if problems else 0)
