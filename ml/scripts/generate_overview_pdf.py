"""
Generate a professional PDF from docs/PROJECT_OVERVIEW.md
Usage: python3 scripts/generate_overview_pdf.py
Output: docs/PROJECT_OVERVIEW.pdf
"""

import re
import sys
from pathlib import Path
import markdown
from weasyprint import HTML, CSS

ROOT     = Path(__file__).parent.parent
MD_FILE  = ROOT / "docs" / "PROJECT_OVERVIEW.md"
PDF_FILE = ROOT / "docs" / "PROJECT_OVERVIEW.pdf"

# ── CSS ──────────────────────────────────────────────────────────────────────
CSS_STYLE = """
@page {
    size: A4;
    margin: 24mm 20mm 22mm 20mm;

    @top-left {
        content: "Intelligent Plant Disease Detection System";
        font-family: Arial, sans-serif;
        font-size: 7pt;
        color: #9ca3af;
        padding-bottom: 3pt;
        border-bottom: 0.5pt solid #d1d5db;
    }
    @top-right {
        content: "Project Overview — 2026";
        font-family: Arial, sans-serif;
        font-size: 7pt;
        color: #9ca3af;
        padding-bottom: 3pt;
        border-bottom: 0.5pt solid #d1d5db;
    }
    @bottom-center {
        content: counter(page) " / " counter(pages);
        font-family: Arial, sans-serif;
        font-size: 7pt;
        color: #9ca3af;
    }
}

@page cover-page {
    margin: 0;
    @top-left   { content: none; }
    @top-right  { content: none; }
    @bottom-center { content: none; }
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
    font-family: Arial, 'Helvetica Neue', sans-serif;
    font-size: 9.5pt;
    line-height: 1.6;
    color: #1f2937;
}

/* ═══════════════════════════════ COVER PAGE ════════════════════════════════ */
.cover {
    page: cover-page;
    page-break-after: always;
    width: 210mm;
    min-height: 297mm;
    background: #064e3b;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 20mm 18mm;
    text-align: center;
}

.cover-logo-ring {
    width: 56pt;
    height: 56pt;
    border-radius: 50%;
    background: rgba(255,255,255,0.12);
    border: 2pt solid rgba(255,255,255,0.25);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 26pt;
    margin: 0 auto 18pt auto;
    line-height: 1;
}

.cover-badge {
    display: inline-block;
    background: rgba(255,255,255,0.12);
    border: 1pt solid rgba(255,255,255,0.3);
    color: #a7f3d0;
    font-size: 7pt;
    font-weight: bold;
    letter-spacing: 1.8pt;
    text-transform: uppercase;
    padding: 3pt 12pt;
    border-radius: 20pt;
    margin-bottom: 20pt;
}

.cover h1 {
    font-size: 26pt;
    font-weight: bold;
    color: #ffffff;
    line-height: 1.25;
    margin: 0 0 10pt 0;
    border: none;
    padding: 0;
    text-align: center;
    page-break-before: avoid;
}

.cover .cover-subtitle {
    font-size: 12pt;
    color: #6ee7b7;
    margin: 0 0 24pt 0;
    font-weight: normal;
}

.cover-line {
    width: 50pt;
    height: 2pt;
    background: #10b981;
    margin: 0 auto 24pt auto;
    border-radius: 2pt;
}

.cover-info-box {
    background: rgba(255,255,255,0.08);
    border: 1pt solid rgba(255,255,255,0.18);
    border-radius: 6pt;
    padding: 14pt 20pt;
    margin-bottom: 24pt;
    text-align: left;
    width: 100%;
    max-width: 330pt;
}

.cover-info-row {
    display: flex;
    gap: 8pt;
    padding: 3pt 0;
    border-bottom: 0.5pt solid rgba(255,255,255,0.1);
}
.cover-info-row:last-child { border-bottom: none; }

.cover-info-label {
    font-size: 7.5pt;
    font-weight: bold;
    color: #6ee7b7;
    width: 70pt;
    flex-shrink: 0;
}
.cover-info-value {
    font-size: 7.5pt;
    color: #d1fae5;
}

.cover-team-label {
    font-size: 7pt;
    font-weight: bold;
    letter-spacing: 1.5pt;
    text-transform: uppercase;
    color: #6ee7b7;
    margin-bottom: 10pt;
}

.cover-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 6pt;
    justify-content: center;
    margin-bottom: 28pt;
}

.cover-chip {
    background: rgba(255,255,255,0.1);
    border: 1pt solid rgba(255,255,255,0.2);
    color: #d1fae5;
    font-size: 8pt;
    padding: 4pt 10pt;
    border-radius: 20pt;
}

.cover-stat-row {
    display: flex;
    gap: 10pt;
    margin-bottom: 20pt;
}

.cover-stat {
    flex: 1;
    background: rgba(255,255,255,0.08);
    border-radius: 5pt;
    padding: 8pt 6pt;
    text-align: center;
}

.cover-stat-value {
    font-size: 14pt;
    font-weight: bold;
    color: #ffffff;
    line-height: 1.1;
}

.cover-stat-label {
    font-size: 6.5pt;
    color: #6ee7b7;
    margin-top: 3pt;
}

.cover-footer-note {
    font-size: 7pt;
    color: rgba(255,255,255,0.35);
    margin-top: auto;
    padding-top: 10pt;
}

/* ═══════════════════════════════ HEADINGS ══════════════════════════════════ */
h1 {
    font-size: 17pt;
    font-weight: bold;
    color: #064e3b;
    border-bottom: 2pt solid #064e3b;
    padding-bottom: 5pt;
    margin: 0 0 14pt 0;
    page-break-after: avoid;
}

h2 {
    font-size: 12.5pt;
    font-weight: bold;
    color: #064e3b;
    padding: 7pt 10pt;
    margin: 0 0 10pt 0;
    background: #ecfdf5;
    border-left: 4pt solid #10b981;
    border-radius: 0 4pt 4pt 0;
    page-break-before: always;
    page-break-after: avoid;
}

/* Never break before the very first h2 (comes right after cover) */
.content > h2:first-child {
    page-break-before: avoid;
}

h3 {
    font-size: 10.5pt;
    font-weight: bold;
    color: #1f2937;
    margin: 16pt 0 6pt 0;
    page-break-after: avoid;
}

h4 {
    font-size: 9.5pt;
    font-weight: bold;
    color: #374151;
    margin: 10pt 0 4pt 0;
    page-break-after: avoid;
}

h2 + p, h2 + ul, h2 + ol, h2 + table, h2 + pre, h2 + blockquote,
h3 + p, h3 + ul, h3 + ol, h3 + table, h3 + pre,
h4 + p, h4 + ul, h4 + ol, h4 + table {
    page-break-before: avoid;
}

/* ═══════════════════════════════ PARAGRAPHS ════════════════════════════════ */
p {
    margin: 0 0 8pt 0;
    orphans: 3;
    widows: 3;
}

/* ═══════════════════════════════ TABLES ════════════════════════════════════ */
table {
    width: 100%;
    border-collapse: collapse;
    font-size: 8.5pt;
    margin: 6pt 0 14pt 0;
    break-inside: avoid;
}

thead tr {
    background: #064e3b;
}

thead th {
    color: #ffffff;
    padding: 6pt 8pt;
    text-align: left;
    font-weight: bold;
    font-size: 8pt;
    letter-spacing: 0.2pt;
}

tbody tr:nth-child(even)  { background: #f0fdf4; }
tbody tr:nth-child(odd)   { background: #ffffff; }

td {
    padding: 5pt 8pt;
    border-bottom: 0.5pt solid #e5e7eb;
    vertical-align: top;
}

td strong { color: #064e3b; }

/* ═══════════════════════════════ CODE ══════════════════════════════════════ */
pre {
    background: #1a1f2e;
    color: #e2e8f0;
    font-family: 'Courier New', Courier, monospace;
    font-size: 7.5pt;
    line-height: 1.5;
    padding: 10pt 12pt;
    border-radius: 5pt;
    margin: 8pt 0 14pt 0;
    border-left: 3pt solid #10b981;
    break-inside: avoid;
    white-space: pre-wrap;
    word-break: break-word;
}

code {
    font-family: 'Courier New', Courier, monospace;
    font-size: 8pt;
    background: #f3f4f6;
    color: #064e3b;
    padding: 1pt 4pt;
    border-radius: 3pt;
}

pre code {
    background: transparent;
    color: inherit;
    padding: 0;
    font-size: 7.5pt;
}

/* ═══════════════════════════════ BLOCKQUOTE ════════════════════════════════ */
blockquote {
    background: #fffbeb;
    border-left: 3pt solid #f59e0b;
    margin: 6pt 0 12pt 0;
    padding: 8pt 12pt;
    border-radius: 0 5pt 5pt 0;
    font-size: 8.5pt;
    break-inside: avoid;
}

blockquote p {
    margin: 0;
    color: #78350f;
}

/* ═══════════════════════════════ LISTS ═════════════════════════════════════ */
ul, ol {
    margin: 4pt 0 10pt 0;
    padding-left: 18pt;
}

li { margin-bottom: 3pt; }

/* ═══════════════════════════════ HR ════════════════════════════════════════ */
hr {
    border: none;
    border-top: 1pt solid #e5e7eb;
    margin: 14pt 0;
}

/* ═══════════════════════════════ LINKS ═════════════════════════════════════ */
a { color: #064e3b; }

/* ═══════════════════════════════ FOOTER NOTE ═══════════════════════════════ */
.doc-footer {
    text-align: center;
    font-size: 7.5pt;
    color: #9ca3af;
    border-top: 0.5pt solid #e5e7eb;
    padding-top: 8pt;
    margin-top: 20pt;
}
"""


# ── Helpers ───────────────────────────────────────────────────────────────────
def build_cover_html() -> str:
    return """
<div class="cover">
  <div class="cover-badge">Graduation Project &nbsp;·&nbsp; MUST &nbsp;·&nbsp; 2026</div>

  <h1>Intelligent Plant Disease<br>Detection System</h1>
  <p class="cover-subtitle">Project Overview Report</p>
  <div class="cover-line"></div>

  <div class="cover-stat-row">
    <div class="cover-stat">
      <div class="cover-stat-value">98.85%</div>
      <div class="cover-stat-label">Test Accuracy</div>
    </div>
    <div class="cover-stat">
      <div class="cover-stat-value">42</div>
      <div class="cover-stat-label">Disease Classes</div>
    </div>
    <div class="cover-stat">
      <div class="cover-stat-value">50,400</div>
      <div class="cover-stat-label">Balanced Images</div>
    </div>
    <div class="cover-stat">
      <div class="cover-stat-value">5-Fold</div>
      <div class="cover-stat-label">Cross Validation</div>
    </div>
  </div>

  <div class="cover-info-box">
    <div class="cover-info-row">
      <span class="cover-info-label">University</span>
      <span class="cover-info-value">Misr University for Science and Technology</span>
    </div>
    <div class="cover-info-row">
      <span class="cover-info-label">Supervisor</span>
      <span class="cover-info-value">Dr. Heba ELnemr</span>
    </div>
    <div class="cover-info-row">
      <span class="cover-info-label">Date</span>
      <span class="cover-info-value">April 2026</span>
    </div>
    <div class="cover-info-row">
      <span class="cover-info-label">Model</span>
      <span class="cover-info-value">ResNet50 — PyTorch — Google Colab (NVIDIA L4)</span>
    </div>
  </div>

  <div class="cover-team-label">Project Team</div>
  <div class="cover-chips">
    <span class="cover-chip">Yousef Ellawah</span>
    <span class="cover-chip">Omar Walid</span>
    <span class="cover-chip">Mohamed Emad</span>
    <span class="cover-chip">Nour Mohamed</span>
    <span class="cover-chip">Menna Mohamed</span>
    <span class="cover-chip">Ahmed Abdul-Wahab</span>
  </div>

  <div class="cover-footer-note">For educational and research purposes only</div>
</div>
"""


def build_body_html(md_text: str) -> str:
    # Remove the top-level H1 title block (it's on the cover)
    md_text = re.sub(
        r'^#[^#].*?\n(?:>.*?\n)*\n---\n',
        '',
        md_text,
        count=1,
        flags=re.MULTILINE | re.DOTALL,
    )

    # Remove the ## Team section (already on cover)
    md_text = re.sub(
        r'## Team\n.*?---\n',
        '',
        md_text,
        count=1,
        flags=re.DOTALL,
    )

    # Remove the trailing italic footer line
    md_text = re.sub(
        r'\n\*For educational.*?\*\s*$',
        '',
        md_text,
        flags=re.DOTALL,
    )

    html = markdown.markdown(
        md_text,
        extensions=["tables", "fenced_code", "attr_list", "md_in_html"],
    )
    return html


def full_html(cover: str, body: str) -> str:
    footer = '<div class="doc-footer">For educational and research purposes — Graduation Project 2026 · Misr University for Science and Technology</div>'
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Project Overview — Intelligent Plant Disease Detection System</title>
</head>
<body>
{cover}
<div class="content">
{body}
{footer}
</div>
</body>
</html>"""


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    if not MD_FILE.exists():
        print(f"ERROR: {MD_FILE} not found", file=sys.stderr)
        sys.exit(1)

    md_text  = MD_FILE.read_text(encoding="utf-8")
    cover    = build_cover_html()
    body     = build_body_html(md_text)
    html_str = full_html(cover, body)

    print("Generating PDF …")
    HTML(string=html_str, base_url=str(ROOT)).write_pdf(
        str(PDF_FILE),
        stylesheets=[CSS(string=CSS_STYLE)],
        presentational_hints=True,
    )
    size_kb = PDF_FILE.stat().st_size // 1024
    print(f"Done — {PDF_FILE}  ({size_kb} KB)")


if __name__ == "__main__":
    main()
