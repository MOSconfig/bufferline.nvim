#!/usr/bin/env python3
"""Documentation tests for the wiki-as-source pipeline.

Standard library only. No network access, no third-party packages, no Neovim.

    python3 scripts/test_docs.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# Import the generator without leaving a __pycache__ directory behind, so a test
# run never adds untracked files to the checkout.
sys.dont_write_bytecode = True

import gen_help  # noqa: E402  (path set above)

ROOT = Path(__file__).resolve().parent.parent
WIKI = ROOT / "wiki"
HELP_SOURCES = WIKI / "help"
GENERATED = ROOT / "doc" / "bufferline.txt"
README_EN = ROOT / "README.md"
README_ZH = ROOT / "README.zh-CN.md"
WORKFLOW = ROOT / ".github" / "workflows" / "wiki-release.yml"

ZH_PREFIX = "zh-CN-"

MD_IMAGE = re.compile(r"!\[[^\]]*\]\((https://[^)\s]+)\)")
HTML_IMAGE = re.compile(r"<img[^>]*\ssrc=\"(https://[^\"]+)\"")
MD_LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
HELP_TAG_DEF = re.compile(r"\*(bufferline[A-Za-z0-9._-]*)\*")
HELP_TAG_REF = re.compile(r"\|(bufferline[A-Za-z0-9._-]*)\|")
WIKI_URL = re.compile(r"https://github\.com/MOSconfig/bufferline\.nvim/wiki/([A-Za-z0-9._-]+)")
CODE_BLOCK = re.compile(r"```(?:lua|vim|sh)?\n(.*?)```", re.DOTALL)

# Nerd Font glyphs live in the Unicode Private Use Area, so an editor, a
# terminal or a copy-paste step can silently drop them and leave a plausible
# looking empty string behind. Written here as escapes, never as literals, and
# pinned to the values in the pre-wiki README.
PUA_START, PUA_END = 0xE000, 0xF8FF
GLYPH_ERROR = ""
GLYPH_WARNING = ""
GLYPH_INFO = ""
GLYPH_HINT = ""
GLYPH_CHEVRON_LEFT = ""
GLYPH_CHEVRON_RIGHT = ""

# page -> every glyph that page must still contain.
REQUIRED_PAGE_GLYPHS = {
    "Features.md": [GLYPH_ERROR, GLYPH_WARNING, GLYPH_INFO, GLYPH_HINT],
    "Multiline-Buffer-Tabs.md": [GLYPH_CHEVRON_LEFT, GLYPH_CHEVRON_RIGHT],
}

# Pages whose fenced code blocks must be byte-identical in both languages:
# only the surrounding prose is translated.
CODE_PARITY_PAGES = ["Features.md", "Multiline-Buffer-Tabs.md"]

# Every image that must survive any README slimming. Captured from the README
# before the wiki split so a dropped screenshot fails loudly.
REQUIRED_README_IMAGES = [
    "https://github.com/akinsho/bufferline.nvim/actions/workflows/ci.yaml/badge.svg",
    "https://user-images.githubusercontent.com/22454918/111992693-9c6a9b00-8b0d-11eb-8c39-19db58583061.gif",
    "https://user-images.githubusercontent.com/22454918/111992989-fec39b80-8b0d-11eb-851b-010641196a04.png",
    "https://user-images.githubusercontent.com/22454918/111993296-5bbf5180-8b0e-11eb-9ad9-fcf9619436fd.gif",
    "https://user-images.githubusercontent.com/22454918/111993343-6da0f480-8b0e-11eb-8d93-44019458d2c9.png",
    "https://user-images.githubusercontent.com/22454918/111993390-7a254d00-8b0e-11eb-9951-43b4350f6a29.gif",
    "https://user-images.githubusercontent.com/22454918/111993463-91643a80-8b0e-11eb-87f0-26acfe92c021.gif",
    "https://user-images.githubusercontent.com/22454918/113215394-b1180300-9272-11eb-9632-8a9f9aae99fa.png",
    "https://user-images.githubusercontent.com/22454918/117363338-5fd3e280-aeb4-11eb-99f2-5ec33dff6f31.png",
    "https://user-images.githubusercontent.com/22454918/118527523-4d219f00-b739-11eb-889f-60fb06fd71bc.png",
    "https://user-images.githubusercontent.com/22454918/119562833-b5f2c200-bd9e-11eb-81d3-06876024bf30.png",
    "https://user-images.githubusercontent.com/22454918/130784872-936d4c55-b9dd-413b-871d-7bc66caf8f17.png",
    "https://user-images.githubusercontent.com/22454918/132410772-0a4c0b95-63bb-4281-8a4e-a652458c3f0f.gif",
    "https://user-images.githubusercontent.com/22454918/157337891-1848da24-69d6-4970-96ee-cf65b2a25c46.png",
    "https://user-images.githubusercontent.com/22454918/161112867-ba48fdf6-42ee-4cd3-9e1a-7118c4a2738b.png",
    "https://user-images.githubusercontent.com/22454918/185873089-2ae20db0-f292-4d96-afe4-ef0683a60709.png",
    "https://user-images.githubusercontent.com/22454918/189106657-163b0550-897c-42c8-a571-d899bdd69998.gif",
    "https://user-images.githubusercontent.com/22454918/220115787-0ba2264f-1cf5-4f18-a322-7c7cfa3d8f42.png",
    "https://user-images.githubusercontent.com/4028913/112573484-9ee92100-8da9-11eb-9ffd-da9cb9cae3a6.png",
    "https://user-images.githubusercontent.com/58056722/119390133-e5d19500-bccc-11eb-915d-f5d11f8e652c.jpeg",
    "https://user-images.githubusercontent.com/58056722/119390136-e66a2b80-bccc-11eb-9a87-e622e3e20563.jpeg",
]

# Headings the README must keep, matching its own table of contents.
REQUIRED_README_EN_HEADINGS = [
    "Requirements",
    "Installation",
    "Usage",
    "Configuration",
    "Features",
    "Multiline buffer tabs",
    "Alternate styling",
    "Slanted tabs",
    "Sloped tabs",
    "Hover events",
    "Underline indicator",
    "Tabpages",
    "LSP indicators",
    "Groups",
    "Sidebar offsets",
    "Numbers",
    "Unique names",
    "Close icons",
    "Re-ordering",
    "Picking",
    "Pinning",
    "Custom areas",
    "How do I see only buffers per tab?",
    "Caveats",
    "FAQ",
    "Tests",
]

# Fork-specific help tags that must never be dropped by a docs refactor.
REQUIRED_HELP_TAGS = [
    "bufferline",
    "bufferline-contents",
    "bufferline-introduction",
    "bufferline-usage",
    "bufferline-configuration",
    "bufferline-multiline",
    "bufferline-hover-events",
    "bufferline-styling",
    "bufferline-style-presets",
    "bufferline-tabpages",
    "bufferline-numbers",
    "bufferline-diagnostics",
    "bufferline-groups",
    "bufferline-sorting",
    "bufferline-filtering",
    "bufferline-commands",
    "bufferline-functions",
    "bufferline-pick",
    "bufferline-mappings",
    "bufferline-highlights",
    "bufferline-mouse-actions",
    "bufferline-custom-areas",
    "bufferline-working-with-elements",
    "bufferline-issues",
]

# Retired claims. The header never defined a `q` mapping; documentation must not
# reintroduce it.
FORBIDDEN_PHRASES = [
    "Same as <Esc>: return to the editor",
    "`q` does the same",
    "and `q` does the same",
    "`q` and <Esc> return to the editor",
    "`q` and `Esc`",
    "never starts a macro recording",
]

failures: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(message)


def images(text: str) -> set[str]:
    return set(MD_IMAGE.findall(text)) | set(HTML_IMAGE.findall(text))


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def english_pages() -> list[Path]:
    return sorted(p for p in WIKI.glob("*.md") if not p.name.startswith(ZH_PREFIX))


def chinese_pages() -> list[Path]:
    return sorted(WIKI.glob(f"{ZH_PREFIX}*.md"))


def test_generator_has_no_drift() -> None:
    check(GENERATED.exists(), "doc/bufferline.txt is missing")
    if not GENERATED.exists():
        return
    check(
        read(GENERATED) == gen_help.render(),
        "doc/bufferline.txt is out of sync with wiki/help/ (run scripts/gen_help.py)",
    )


def test_generator_is_deterministic() -> None:
    check(gen_help.render() == gen_help.render(), "generator output is not deterministic")


def test_generator_reads_only_the_wiki() -> None:
    """The help file must be assembled from wiki/help/ and nothing else."""
    sources = gen_help.source_files()
    check(bool(sources), "no help sources found")
    for path in sources:
        check(
            path.parent == HELP_SOURCES,
            f"help source outside wiki/help/: {path}",
        )
    generator_src = read(ROOT / "scripts" / "gen_help.py")
    for forbidden in ("urllib", "requests", "subprocess", "socket"):
        check(
            forbidden not in generator_src,
            f"generator must not depend on {forbidden}",
        )


def test_help_tags_are_preserved() -> None:
    if not GENERATED.exists():
        return
    text = read(GENERATED)
    defined = set(HELP_TAG_DEF.findall(text))
    for tag in REQUIRED_HELP_TAGS:
        check(tag in defined, f"help tag lost: *{tag}*")
    for tag in sorted(set(HELP_TAG_REF.findall(text))):
        check(tag in defined, f"help references undefined tag: |{tag}|")


def test_bilingual_page_parity() -> None:
    english = {p.stem for p in english_pages()}
    chinese = {p.stem[len(ZH_PREFIX):] for p in chinese_pages()}
    for name in sorted(english - chinese):
        failures.append(f"English wiki page has no Chinese counterpart: {name}")
    for name in sorted(chinese - english):
        failures.append(f"Chinese wiki page has no English counterpart: {name}")
    global checks
    checks += 1

    for page in english_pages():
        counterpart = WIKI / f"{ZH_PREFIX}{page.name}"
        if not counterpart.exists():
            continue
        en_images = images(read(page))
        zh_images = images(read(counterpart))
        check(
            en_images == zh_images,
            f"image parity mismatch between {page.name} and {counterpart.name}: "
            f"only EN {sorted(en_images - zh_images)}, only ZH {sorted(zh_images - en_images)}",
        )


def test_bilingual_pages_are_substantive() -> None:
    """A translation must not be a stub or an untranslated copy."""
    for page in english_pages():
        counterpart = WIKI / f"{ZH_PREFIX}{page.name}"
        if not counterpart.exists():
            continue
        zh_text = read(counterpart)
        check(len(zh_text) > 400, f"Chinese page looks like a stub: {counterpart.name}")
        han = sum(1 for ch in zh_text if "一" <= ch <= "鿿")
        check(
            han >= 150,
            f"Chinese page has too little Chinese prose ({han} han chars): {counterpart.name}",
        )


def test_internal_wiki_links_resolve() -> None:
    pages = {p.stem for p in WIKI.glob("*.md")}
    for page in sorted(WIKI.glob("*.md")):
        for target in MD_LINK.findall(read(page)):
            if target.startswith(("http://", "https://", "#", "mailto:")):
                continue
            slug = target.split("#", 1)[0].strip()
            if not slug:
                continue
            check(slug in pages, f"{page.name} links to missing wiki page: {slug}")


def test_readme_links_resolve_and_match() -> None:
    pages = {p.stem for p in WIKI.glob("*.md")}
    en_targets = set(WIKI_URL.findall(read(README_EN)))
    zh_targets = set(WIKI_URL.findall(read(README_ZH)))

    for slug in sorted(en_targets | zh_targets):
        check(slug in pages, f"README links to missing wiki page: {slug}")

    en_normalised = {s for s in en_targets if not s.startswith(ZH_PREFIX)}
    zh_normalised = {s[len(ZH_PREFIX):] for s in zh_targets if s.startswith(ZH_PREFIX)}
    check(
        en_normalised == zh_normalised,
        "README wiki links differ between languages: "
        f"only EN {sorted(en_normalised - zh_normalised)}, "
        f"only ZH {sorted(zh_normalised - en_normalised)}",
    )
    check(
        all(s.startswith(ZH_PREFIX) for s in zh_targets),
        "Chinese README must link to Chinese wiki pages",
    )


def test_readme_images_and_headings_are_preserved() -> None:
    en_images = images(read(README_EN))
    zh_images = images(read(README_ZH))
    for url in REQUIRED_README_IMAGES:
        check(url in en_images, f"README.md dropped an image: {url}")
    check(
        en_images == zh_images,
        "README image parity mismatch: "
        f"only EN {sorted(en_images - zh_images)}, only ZH {sorted(zh_images - en_images)}",
    )

    headings = {
        line.lstrip("#").strip()
        for line in read(README_EN).splitlines()
        if line.startswith("#")
    }
    for heading in REQUIRED_README_EN_HEADINGS:
        check(heading in headings, f"README.md dropped heading: {heading}")


def test_multiline_preview_and_wiki_quickstart() -> None:
    previews = []
    examples = []
    for path in (README_EN, README_ZH):
        text = read(path)
        local_images = {
            target for target in re.findall(r"!\[[^\]]*\]\(([^)\s]+)\)", text)
            if not target.startswith(("https://", "http://"))
        }
        previews.append(local_images)
        check(
            "wiki/assets/multiline-buffer-tabs.png" in local_images,
            f"{path.name} is missing the multiline preview",
        )
        for target in local_images:
            check((ROOT / target).is_file(), f"{path.name} references missing image: {target}")
        check(not CODE_BLOCK.findall(text), f"{path.name} should link to wiki examples, not duplicate them")
        guide = WIKI / ("zh-CN-Multiline-Buffer-Tabs.md" if path == README_ZH else "Multiline-Buffer-Tabs.md")
        snippets = [
            block for block in CODE_BLOCK.findall(read(guide))
            if '"MOSconfig/bufferline.nvim"' in block
        ]
        check(len(snippets) == 1, f"{guide.name} needs one fork quickstart")
        examples.append(snippets)
        if len(snippets) == 1:
            for setting in (
                'branch = "main"', 'vim.opt.termguicolors = true',
                'opts = {', 'mode = "buffers"', 'enabled = true', 'max_rows = 3',
            ):
                check(setting in snippets[0], f"{guide.name} quickstart is missing {setting}")
            check("multiline_config" not in snippets[0], f"{guide.name} uses an undefined configuration")
    check(previews[0] == previews[1], "README local image references differ between languages")
    check(examples[0] == examples[1], "Wiki fork quickstarts differ between languages")

    sources = [README_EN, README_ZH, HELP_SOURCES / "05-multiline-buffer-tabs.txt"]
    sources += list(WIKI.glob("*Multiline-Buffer-Tabs.md"))
    for path in sources:
        check(
            "feat/multiline-buffer-tabs" not in read(path),
            f"{path.relative_to(ROOT)} still recommends the old feature branch",
        )


def test_no_retired_q_mapping_claim() -> None:
    targets = list(WIKI.glob("*.md")) + list(HELP_SOURCES.glob("*.txt"))
    targets += [README_EN, README_ZH]
    if GENERATED.exists():
        targets.append(GENERATED)
    for path in targets:
        text = read(path)
        for phrase in FORBIDDEN_PHRASES:
            check(
                phrase not in text,
                f"{path.relative_to(ROOT)} reintroduces the retired q-mapping claim: {phrase!r}",
            )

    # A `q` row in a keymap table is the other way the claim creeps back in.
    for path in list(WIKI.glob("*Multiline*.md")) + [HELP_SOURCES / "05-multiline-buffer-tabs.txt"]:
        if not path.exists():
            continue
        for line in read(path).splitlines():
            stripped = line.strip()
            check(
                not stripped.startswith("| `q` |") and not re.match(r"^q\s{2,}\S", stripped),
                f"{path.relative_to(ROOT)} documents a `q` header mapping: {stripped!r}",
            )


def test_multiline_contract_statements_present() -> None:
    """The corrected contract must be stated, not merely un-contradicted."""
    required = {
        WIKI / "Multiline-Buffer-Tabs.md": [
            "There is no `q` mapping",
            "only** renderer selector",
            "no native single-row fallback",
            "Recovery is event-driven",
            "cannot pick while the multiline header is unavailable",
        ],
        WIKI / "zh-CN-Multiline-Buffer-Tabs.md": [
            "不存在 `q` 映射",
            "唯一**的渲染器选择开关",
            "不存在回退到原生单行的机制",
            "恢复由事件驱动",
            "cannot pick while the multiline header is unavailable",
        ],
        HELP_SOURCES / "05-multiline-buffer-tabs.txt": [
            "There is no `q` mapping in the header",
            "is the only renderer selector",
            "Recovery is event-driven",
            "cannot pick while the multiline header is unavailable",
        ],
    }
    for path, phrases in required.items():
        check(path.exists(), f"missing documentation source: {path}")
        if not path.exists():
            continue
        text = read(path)
        for phrase in phrases:
            check(phrase in text, f"{path.relative_to(ROOT)} is missing: {phrase!r}")


def test_nerd_font_glyphs_are_preserved() -> None:
    """Private Use Area glyphs must survive any docs migration, in both languages.

    A lost glyph degrades into an innocuous-looking empty string, so this check
    pins the exact codepoints rather than merely asserting "something is there".
    """
    for page, glyphs in REQUIRED_PAGE_GLYPHS.items():
        for name in (page, f"{ZH_PREFIX}{page}"):
            path = WIKI / name
            check(path.exists(), f"missing wiki page: {name}")
            if not path.exists():
                continue
            text = read(path)
            for glyph in glyphs:
                check(
                    glyph in text,
                    f"{name} lost the Nerd Font glyph U+{ord(glyph):04X}",
                )

    # An empty inline-code span is what a dropped glyph leaves behind.
    for page in REQUIRED_PAGE_GLYPHS:
        for name in (page, f"{ZH_PREFIX}{page}"):
            path = WIKI / name
            if not path.exists():
                continue
            for number, line in enumerate(read(path).splitlines(), 1):
                check(
                    "``" not in line.replace("```", ""),
                    f"{name}:{number} has an empty inline-code span, "
                    f"which is what a dropped glyph looks like: {line.strip()!r}",
                )


def test_code_blocks_match_across_languages() -> None:
    """Translated pages translate prose, never the code itself."""
    for page in CODE_PARITY_PAGES:
        en_path = WIKI / page
        zh_path = WIKI / f"{ZH_PREFIX}{page}"
        check(en_path.exists() and zh_path.exists(), f"missing a language pair for {page}")
        if not (en_path.exists() and zh_path.exists()):
            continue
        en_blocks = [b.strip() for b in CODE_BLOCK.findall(read(en_path))]
        zh_blocks = [b.strip() for b in CODE_BLOCK.findall(read(zh_path))]
        check(
            len(en_blocks) == len(zh_blocks),
            f"{page}: {len(en_blocks)} code blocks in EN but {len(zh_blocks)} in ZH",
        )
        for index, (en_block, zh_block) in enumerate(zip(en_blocks, zh_blocks)):
            check(
                en_block == zh_block,
                f"{page}: code block {index} differs between languages "
                f"(EN {en_block[:60]!r} vs ZH {zh_block[:60]!r})",
            )


def test_diagnostics_examples_are_functional() -> None:
    """The diagnostics snippets must still demonstrate working indicators.

    Blanked-out glyphs turn every example into one that renders nothing, and the
    conditional example into one that disables diagnostics for *all* buffers
    rather than only the current one.
    """
    for name in ("Features.md", f"{ZH_PREFIX}Features.md"):
        path = WIKI / name
        check(path.exists(), f"missing wiki page: {name}")
        if not path.exists():
            continue
        snippets = [
            block for block in CODE_BLOCK.findall(read(path))
            if "diagnostics_indicator" in block
        ]
        check(len(snippets) == 3, f"{name}: expected 3 diagnostics examples, got {len(snippets)}")

        for index, snippet in enumerate(snippets):
            # Scan the snippet directly: pairing quotes is unreliable here,
            # because an apostrophe in the prose comments ("Don't get too
            # fancy") desynchronises any quote-matching heuristic.
            has_glyph = any(PUA_START <= ord(ch) <= PUA_END for ch in snippet)
            check(
                has_glyph,
                f"{name}: diagnostics example {index} has no glyph left, "
                "so it would render nothing",
            )

        # The conditional example must return empty for the *current* buffer and
        # something visible otherwise. Two empty returns disable it everywhere.
        conditional = next((s for s in snippets if "context.buffer:current()" in s), None)
        check(conditional is not None, f"{name}: the conditional example is missing")
        if conditional is None:
            continue
        returns = re.findall(r"return\s+'([^']*)'", conditional)
        check(
            len(returns) == 2,
            f"{name}: conditional example should have 2 return values, got {len(returns)}",
        )
        if len(returns) == 2:
            check(
                returns[0] == "",
                f"{name}: the current-buffer branch should return an empty string, "
                f"got {returns[0]!r}",
            )
            check(
                returns[1] != "",
                f"{name}: the other-buffers branch returns an empty string, which "
                "disables diagnostics for every buffer instead of just the current one",
            )


def test_generated_file_is_marked_generated() -> None:
    if not GENERATED.exists():
        return
    head = read(GENERATED)[:1500]
    check("GENERATED FILE" in head, "doc/bufferline.txt lacks a generated-file notice")
    check("wiki/help/" in head, "doc/bufferline.txt does not name its source directory")


def test_workflow_safety() -> None:
    check(WORKFLOW.exists(), "missing .github/workflows/wiki-release.yml")
    if not WORKFLOW.exists():
        return
    text = read(WORKFLOW)
    check("release:" in text and "published" in text, "workflow must trigger on published releases")
    check("workflow_dispatch:" in text, "workflow must support manual dispatch")
    check("contents: read" in text, "workflow must request contents: read")
    check("WIKI_TOKEN: ${{ secrets.GITHUB_TOKEN }}" in text, "wiki must use the built-in token")
    check("secrets.WIKI_TOKEN" not in text, "a separate wiki secret must not be required")
    check("contents: write" in text.split("  publish:", 1)[1], "publish job needs wiki write permission")
    check("--force" not in text, "workflow must never force-push")
    check(
        "x-access-token:${{" not in text and "@github.com/${{ secrets" not in text,
        "workflow must not embed the token in a URL",
    )
    check("GIT_ASKPASS" in text, "workflow should supply the token via GIT_ASKPASS")
    check("::add-mask::" in text, "workflow should mask the token")


def main() -> int:
    tests = [value for name, value in sorted(globals().items()) if name.startswith("test_")]
    for test in tests:
        test()

    if failures:
        print(f"FAILED {len(failures)} of {checks} checks\n", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    print(f"ok - {checks} checks passed across {len(tests)} tests")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
