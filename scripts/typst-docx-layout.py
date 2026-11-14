#!/usr/bin/env python3
"""Light layout clean-up for Pandoc Typst→DOCX exports.

House style for any Typst document: A4, ~20–24 mm margins, Gentium,
justified body, hanging bibliography, table header emphasis, and a few
Pandoc/Typst export repairs (metadata title lines, inline image+text mash,
layout-padding spaces, mixed Hebrew/Latin lines). Edits in place.
"""

from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

# OOXML namespaces — register before parse/serialise so prefixes stay valid.
NS = {
    "w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
    "wp": "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing",
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "pic": "http://schemas.openxmlformats.org/drawingml/2006/picture",
    "m": "http://schemas.openxmlformats.org/officeDocument/2006/math",
    "o": "urn:schemas-microsoft-com:office:office",
    "v": "urn:schemas-microsoft-com:vml",
    "w10": "urn:schemas-microsoft-com:office:word",
    "a14": "http://schemas.microsoft.com/office/drawing/2010/main",
    "asvg": "http://schemas.microsoft.com/office/drawing/2016/SVG/main",
    "xml": "http://www.w3.org/XML/1998/namespace",
}
for prefix, uri in NS.items():
    ET.register_namespace(prefix, uri)

W = f"{{{NS['w']}}}"
WP = f"{{{NS['wp']}}}"
A = f"{{{NS['a']}}}"

# A4 and ~20–24 mm margins in twips (1 mm ≈ 56.7 twips).
A4_W, A4_H = "11906", "16838"
MARGIN = {
    "top": "1247",  # 22 mm
    "bottom": "1361",  # 24 mm
    "left": "1134",  # 20 mm
    "right": "1134",
    "header": "708",
    "footer": "708",
    "gutter": "0",
}
# Cap inline images (~4.5 cm wide).
MAX_IMAGE_CX = 2551180

HEBREW_RE = re.compile(r"[\u0590-\u05FF]+(?:\s+[\u0590-\u05FF]+)*")
LATIN_RE = re.compile(r"[A-Za-zÀ-ÖØ-öø-ÿŒœÆæ]")
# Typst/Pandoc sometimes pads with many figure/em spaces; leave single fine spaces alone.
PADDING_SPACES_RE = re.compile(r"[\u2000-\u200b\u202f\xa0]{3,}")


def _q(tag: str) -> str:
    return f"{W}{tag}"


def _ensure_child(parent: ET.Element, tag: str) -> ET.Element:
    child = parent.find(_q(tag))
    if child is None:
        child = ET.SubElement(parent, _q(tag))
    return child


def _set_jc(p_pr: ET.Element, val: str) -> None:
    jc = _ensure_child(p_pr, "jc")
    jc.set(_q("val"), val)


def _set_spacing(
    p_pr: ET.Element,
    *,
    before: str | None = None,
    after: str | None = None,
    line: str | None = None,
    line_rule: str | None = None,
) -> None:
    spacing = _ensure_child(p_pr, "spacing")
    if before is not None:
        spacing.set(_q("before"), before)
    if after is not None:
        spacing.set(_q("after"), after)
    if line is not None:
        spacing.set(_q("line"), line)
    if line_rule is not None:
        spacing.set(_q("lineRule"), line_rule)


def _para_text(p: ET.Element) -> str:
    return "".join((t.text or "") for t in p.iter(_q("t")))


def _para_style(p: ET.Element) -> str | None:
    p_pr = p.find(_q("pPr"))
    if p_pr is None:
        return None
    ps = p_pr.find(_q("pStyle"))
    if ps is None:
        return None
    return ps.get(_q("val"))


def _set_run_fonts(r_pr: ET.Element, latin: str, east_asia: str | None = None) -> None:
    fonts = _ensure_child(r_pr, "rFonts")
    fonts.set(_q("ascii"), latin)
    fonts.set(_q("hAnsi"), latin)
    fonts.set(_q("cs"), latin)
    if east_asia:
        fonts.set(_q("eastAsia"), east_asia)


def _tostring(root: ET.Element) -> bytes:
    """Serialise with an XML declaration and stable prefixes."""
    raw = ET.tostring(root, encoding="utf-8")
    text = raw.decode("utf-8")
    text = text.replace("ns0:", "w:").replace("xmlns:ns0=", "xmlns:w=")
    if not text.startswith("<?xml"):
        text = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n' + text
    return text.encode("utf-8")


def _normalise_spaces(text: str) -> str:
    """Collapse layout-padding spaces; keep ordinary single spaces."""
    text = PADDING_SPACES_RE.sub(" ", text)
    return re.sub(r" +", " ", text).strip()


def patch_styles(styles_root: ET.Element) -> None:
    """Tune paragraph styles for readable body copy."""
    targets = {
        "Normal": dict(jc="both", after="120", line="276", line_rule="auto", size="22"),
        "BodyText": dict(jc="both", before="0", after="120", line="276", line_rule="auto", size="22"),
        "FirstParagraph": dict(
            jc="both", before="0", after="120", line="276", line_rule="auto", size="22"
        ),
        "Compact": dict(jc="both", before="40", after="40", line="240", line_rule="auto", size="20"),
        "Title": dict(jc="center", before="0", after="80", size="28", bold=True),
        "Author": dict(jc="center", before="0", after="200", size="20"),
        "Heading1": dict(jc="left", before="360", after="160", size="26", bold=True),
        "Heading2": dict(jc="left", before="280", after="100", size="24", bold=True),
        "Heading3": dict(jc="left", before="200", after="80", size="22", bold=True),
        "TableCaption": dict(jc="left", before="160", after="60", size="20", italic=True),
        "Bibliography": dict(jc="both", before="0", after="80", size="20", hanging="567"),
        "FootnoteText": dict(jc="both", after="40", size="18"),
    }
    for style in styles_root.iter(_q("style")):
        style_id = style.get(_q("styleId"))
        if style_id not in targets:
            continue
        spec = targets[style_id]
        p_pr = _ensure_child(style, "pPr")
        r_pr = _ensure_child(style, "rPr")
        if "jc" in spec:
            _set_jc(p_pr, spec["jc"])
        _set_spacing(
            p_pr,
            before=spec.get("before"),
            after=spec.get("after"),
            line=spec.get("line"),
            line_rule=spec.get("line_rule"),
        )
        if "hanging" in spec:
            ind = _ensure_child(p_pr, "ind")
            ind.set(_q("left"), spec["hanging"])
            ind.set(_q("hanging"), spec["hanging"])
        _set_run_fonts(r_pr, "Gentium", "Gentium")
        if "size" in spec:
            sz = _ensure_child(r_pr, "sz")
            sz.set(_q("val"), spec["size"])
            sz_cs = _ensure_child(r_pr, "szCs")
            sz_cs.set(_q("val"), spec["size"])
        if spec.get("bold"):
            _ensure_child(r_pr, "b")
            _ensure_child(r_pr, "bCs")
        if spec.get("italic"):
            _ensure_child(r_pr, "i")
            _ensure_child(r_pr, "iCs")


def patch_section(document_root: ET.Element) -> None:
    """Force A4 and comfortable margins on the body section."""
    body = document_root.find(_q("body"))
    if body is None:
        return
    sect = None
    for child in list(body):
        if child.tag == _q("sectPr"):
            sect = child
    if sect is None:
        sect = ET.SubElement(body, _q("sectPr"))
    pg_sz = _ensure_child(sect, "pgSz")
    pg_sz.set(_q("w"), A4_W)
    pg_sz.set(_q("h"), A4_H)
    pg_mar = _ensure_child(sect, "pgMar")
    for key, val in MARGIN.items():
        pg_mar.set(_q(key), val)


def _extract_drawings(p: ET.Element) -> list[ET.Element]:
    """Detach ``w:drawing`` nodes (and their parent runs) for reinsertion."""
    drawings: list[ET.Element] = []
    for run in list(p.findall(_q("r"))):
        drawing = run.find(_q("drawing"))
        if drawing is None:
            continue
        drawings.append(drawing)
        run.remove(drawing)
        if len(run) == 0 or (len(run) == 1 and run[0].tag == _q("rPr")):
            p.remove(run)
    return drawings


def _replace_para_text(
    p: ET.Element,
    new_text: str,
    *,
    center: bool = False,
    keep_drawings: bool = False,
) -> list[ET.Element]:
    """Replace text runs in a paragraph with a single plain run.

    Returns any extracted drawings when ``keep_drawings`` is true.
    """
    drawings = _extract_drawings(p) if keep_drawings else []
    p_pr = p.find(_q("pPr"))
    for child in list(p):
        if child.tag != _q("pPr"):
            p.remove(child)
    if p_pr is None:
        p_pr = ET.Element(_q("pPr"))
        p.insert(0, p_pr)
    if center:
        _set_jc(p_pr, "center")
    run = ET.SubElement(p, _q("r"))
    r_pr = ET.SubElement(run, _q("rPr"))
    _set_run_fonts(r_pr, "Gentium", "Gentium")
    t = ET.SubElement(run, _q("t"))
    t.set(f"{{{NS['xml']}}}space", "preserve")
    t.text = new_text
    return drawings


def _insert_drawing_para_before(
    body: ET.Element, before: ET.Element, drawing: ET.Element
) -> None:
    """Insert a centred paragraph that only contains ``drawing``."""
    idx = list(body).index(before)
    p = ET.Element(_q("p"))
    p_pr = ET.SubElement(p, _q("pPr"))
    _set_jc(p_pr, "center")
    _set_spacing(p_pr, before="0", after="80")
    run = ET.SubElement(p, _q("r"))
    run.append(drawing)
    body.insert(idx, p)


def _insert_para_after(
    body: ET.Element, after: ET.Element, text: str, *, center: bool = True
) -> None:
    idx = list(body).index(after)
    p = ET.Element(_q("p"))
    p_pr = ET.SubElement(p, _q("pPr"))
    if center:
        _set_jc(p_pr, "center")
    _set_spacing(p_pr, before="40", after="120")
    run = ET.SubElement(p, _q("r"))
    r_pr = ET.SubElement(run, _q("rPr"))
    _set_run_fonts(r_pr, "Gentium", "Gentium")
    sz = ET.SubElement(r_pr, _q("sz"))
    sz.set(_q("val"), "22")
    t = ET.SubElement(run, _q("t"))
    t.set(f"{{{NS['xml']}}}space", "preserve")
    t.text = text
    body.insert(idx + 1, p)


def _has_drawing(p: ET.Element) -> bool:
    return p.find(f".//{_q('drawing')}") is not None


def drop_leading_metadata(body: ET.Element) -> None:
    """Remove Pandoc Title/Author paragraphs when they lead the body."""
    for p in list(body):
        if p.tag != _q("p"):
            break
        if _para_style(p) in {"Title", "Author"}:
            body.remove(p)
        else:
            break


def repair_export_artefacts(body: ET.Element) -> None:
    """Fix common Pandoc/Typst DOCX artefacts, without document-specific strings."""
    for p in list(body):
        if p.tag != _q("p"):
            continue

        text = _para_text(p)
        has_draw = _has_drawing(p)
        needs_space_fix = bool(PADDING_SPACES_RE.search(text))
        collapsed = _normalise_spaces(text) if (needs_space_fix or has_draw) else text.strip()

        hebrew_chunks = HEBREW_RE.findall(collapsed)
        has_hebrew = bool(hebrew_chunks)
        has_latin = bool(LATIN_RE.search(collapsed))
        mixed_scripts = has_hebrew and has_latin

        if not has_draw and not needs_space_fix and not mixed_scripts:
            continue

        if mixed_scripts:
            latin = HEBREW_RE.sub("", collapsed).strip(" ·—-\t")
            hebrew = " ".join(hebrew_chunks)
            drawings = _replace_para_text(
                p, latin or collapsed, center=True, keep_drawings=True
            )
            p_pr = p.find(_q("pPr"))
            if p_pr is not None:
                _set_spacing(p_pr, before="80", after="40")
            for drawing in reversed(drawings):
                _insert_drawing_para_before(body, p, drawing)
            if hebrew:
                _insert_para_after(body, p, hebrew, center=True)
            continue

        if has_draw and collapsed:
            drawings = _replace_para_text(
                p, collapsed, center=True, keep_drawings=True
            )
            for drawing in reversed(drawings):
                _insert_drawing_para_before(body, p, drawing)
            continue

        if needs_space_fix and collapsed != text.strip():
            _replace_para_text(p, collapsed, center=False)


def _centre_short_para(p: ET.Element) -> None:
    p_pr = p.find(_q("pPr"))
    if p_pr is None:
        p_pr = ET.Element(_q("pPr"))
        p.insert(0, p_pr)
    _set_jc(p_pr, "center")
    _set_spacing(p_pr, before="40", after="40")


def centre_title_region(body: ET.Element) -> None:
    """Centre short title-region lines (preamble + deck under the first H1)."""
    seen_h1 = False
    deck_count = 0
    for p in body.findall(_q("p")):
        style = _para_style(p)
        text = _para_text(p).strip()
        has_draw = _has_drawing(p)

        if style == "Heading1" and not seen_h1:
            seen_h1 = True
            # First top-level heading is usually the document title.
            p_pr = p.find(_q("pPr"))
            if p_pr is None:
                p_pr = ET.Element(_q("pPr"))
                p.insert(0, p_pr)
            _set_jc(p_pr, "center")
            continue

        if style in {"Heading2", "Heading3"}:
            if seen_h1:
                break
            continue

        if not text and not has_draw:
            continue
        if text and len(text) > 180:
            if seen_h1:
                break
            continue

        if not seen_h1:
            _centre_short_para(p)
            continue

        # Short lines immediately under the first H1 (subtitle / provenance).
        if deck_count >= 6:
            break
        _centre_short_para(p)
        deck_count += 1


def emphasise_table_headers(document_root: ET.Element) -> None:
    """Bold the first row of each table and add light cell shading."""
    for table in document_root.iter(_q("tbl")):
        rows = table.findall(_q("tr"))
        if not rows:
            continue
        for cell in rows[0].findall(_q("tc")):
            tc_pr = _ensure_child(cell, "tcPr")
            shd = _ensure_child(tc_pr, "shd")
            shd.set(_q("val"), "clear")
            shd.set(_q("color"), "auto")
            shd.set(_q("fill"), "E8E8E8")
            for p in cell.findall(_q("p")):
                for run in p.findall(_q("r")):
                    r_pr = _ensure_child(run, "rPr")
                    _ensure_child(r_pr, "b")
                    _ensure_child(r_pr, "bCs")


def shrink_oversized_images(document_root: ET.Element) -> None:
    """Scale down huge inline drawings while keeping aspect ratio."""
    for extent in document_root.iter(f"{WP}extent"):
        try:
            cx = int(extent.get("cx") or "0")
            cy = int(extent.get("cy") or "0")
        except ValueError:
            continue
        if cx <= MAX_IMAGE_CX or cx <= 0:
            continue
        scale = MAX_IMAGE_CX / cx
        extent.set("cx", str(MAX_IMAGE_CX))
        extent.set("cy", str(max(1, int(cy * scale))))

    for ext in document_root.iter(f"{A}ext"):
        try:
            cx = int(ext.get("cx") or "0")
            cy = int(ext.get("cy") or "0")
        except ValueError:
            continue
        if cx <= MAX_IMAGE_CX or cx <= 0 or cy <= 0:
            continue
        # Only scale picture frame extents (large), not tiny offsets.
        if cx < 500000:
            continue
        scale = MAX_IMAGE_CX / cx
        ext.set("cx", str(MAX_IMAGE_CX))
        ext.set("cy", str(max(1, int(cy * scale))))


def process(path: Path) -> None:
    """Rewrite ``path`` with layout clean-ups applied."""
    with zipfile.ZipFile(path, "r") as zin:
        parts = {name: zin.read(name) for name in zin.namelist()}

    document_root = ET.fromstring(parts["word/document.xml"])
    styles_root = ET.fromstring(parts["word/styles.xml"])
    body = document_root.find(_q("body"))

    patch_styles(styles_root)
    patch_section(document_root)
    if body is not None:
        drop_leading_metadata(body)
        repair_export_artefacts(body)
        centre_title_region(body)
    emphasise_table_headers(document_root)
    shrink_oversized_images(document_root)

    parts["word/document.xml"] = _tostring(document_root)
    parts["word/styles.xml"] = _tostring(styles_root)

    tmp = path.with_suffix(path.suffix + ".tmp")
    with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for name, data in parts.items():
            zout.writestr(name, data)
    tmp.replace(path)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"Usage: {Path(argv[0]).name} <file.docx>", file=sys.stderr)
        return 2
    path = Path(argv[1]).expanduser().resolve()
    if not path.is_file():
        print(f"Not found: {path}", file=sys.stderr)
        return 1
    process(path)
    print(f"Laid out: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
