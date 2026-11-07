#!/usr/bin/env python3
"""检查 App 的 String Catalog：每条要翻译的文字都有简体、繁体、英文、日文，占位符（%@、%lld）和原文对得上。

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

print("\n".join(problems) or f"没问题：{len(strings)} 条")
sys.exit(1 if problems else 0)
