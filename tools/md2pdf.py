#!/usr/bin/env python3
"""Player's manual Markdown -> self-contained HTML -> PDF (headless Chrome).

Usage: md2pdf.py <manual.md> [<out.pdf>]

Handles the subset the manuals use: headings, paragraphs, lists, tables,
images, code blocks, **bold**, *italic* and `code`. Images are embedded,
so the HTML stands alone; Chrome (Windows, reached through WSL) prints it.
Set CHROME to use another browser binary.
"""
import base64
import html
import os
import re
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
CHROME = os.environ.get("CHROME", "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe")

CSS = """
@page { size: A4; margin: 16mm 15mm; }
body { font-family: "Segoe UI", "Noto Sans", Arial, sans-serif; font-size: 10.5pt;
       line-height: 1.45; color: #1d1d2b; }
h1 { font-size: 24pt; color: #c2185b; margin: 0 0 2mm; }
h1 + p em { color: #555; }
h2 { font-size: 15pt; color: #1a3fa6; border-bottom: 2px solid #f48fb1;
     padding-bottom: 1mm; margin-top: 8mm; page-break-after: avoid; }
h3 { font-size: 12pt; color: #c2185b; margin-top: 6mm; page-break-after: avoid; }
p, li { orphans: 3; widows: 3; }
img { display: block; margin: 3mm auto; width: 120mm; image-rendering: pixelated;
      border: 3px solid #1a3fa6; border-radius: 4px; page-break-inside: avoid; }
table { border-collapse: collapse; width: 100%; margin: 3mm 0; font-size: 9.5pt;
        page-break-inside: avoid; }
th { background: #1a3fa6; color: #fff; text-align: left; }
th, td { border: 1px solid #b8c4e8; padding: 1.5mm 2mm; vertical-align: top; }
tr:nth-child(even) td { background: #fdf0f5; }
code { font-family: Consolas, "DejaVu Sans Mono", monospace; background: #eef1fb;
       padding: 0 1mm; }
pre { background: #1a3fa6; color: #fff59d; padding: 3mm 4mm; border-radius: 4px;
      font-size: 11pt; }
pre code { background: none; color: inherit; }
"""


def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<!\*)\*([^*]+)\*(?!\*)", r"<em>\1</em>", text)
    return text


def image(alt, src, base):
    with open(os.path.join(base, src), "rb") as f:
        data = base64.b64encode(f.read()).decode()
    return f'<img alt="{html.escape(alt)}" src="data:image/png;base64,{data}">'


def convert(md, base):
    out, lines, i = [], md.split("\n"), 0
    para = []

    def flush():
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if s.startswith("```"):
            flush()
            i += 1
            code = []
            while not lines[i].strip().startswith("```"):
                code.append(html.escape(lines[i]))
                i += 1
            out.append("<pre><code>" + "\n".join(code) + "</code></pre>")
        elif m := re.match(r"(#{1,3}) (.*)", s):
            flush()
            n = len(m.group(1))
            out.append(f"<h{n}>{inline(m.group(2))}</h{n}>")
        elif m := re.match(r"!\[([^\]]*)\]\(([^)]+)\)$", s):
            flush()
            out.append(image(m.group(1), m.group(2), base))
        elif s.startswith("|"):
            flush()
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            i -= 1
            t = ["<table><tr>" + "".join(f"<th>{inline(c)}</th>" for c in rows[0]) + "</tr>"]
            t += ["<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in rows[1:]]
            out.append("".join(t) + "</table>")
        elif re.match(r"(- |\d+\. )", s):
            flush()
            tag = "ul" if s.startswith("- ") else "ol"
            items = []
            while i < len(lines) and lines[i].strip():
                t = lines[i].strip()
                if re.match(r"(- |\d+\. )", t):
                    items.append(re.sub(r"^(- |\d+\. )", "", t))
                else:
                    items[-1] += " " + t                 # continuation line
                i += 1
            i -= 1
            out.append(f"<{tag}>" + "".join(f"<li>{inline(t)}</li>" for t in items) + f"</{tag}>")
        elif not s:
            flush()
        else:
            para.append(s)
        i += 1
    flush()
    return "\n".join(out)


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    src = sys.argv[1]
    pdf = sys.argv[2] if len(sys.argv) == 3 else os.path.splitext(src)[0] + ".pdf"
    base = os.path.dirname(os.path.abspath(src))
    md = open(src, encoding="utf-8").read()
    lang = "el" if src.endswith("-el.md") else "en"
    title = re.search(r"^# (.*)", md, re.M).group(1)
    body = convert(md, base)
    page = (f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8">'
            f"<title>{html.escape(title)}</title><style>{CSS}</style></head>"
            f"<body>{body}</body></html>")
    os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
    tmp = os.path.join(ROOT, "build", os.path.basename(os.path.splitext(src)[0]) + ".html")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(page)
    win = lambda p: subprocess.check_output(["wslpath", "-w", os.path.abspath(p)], text=True).strip()  # noqa: E731
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    "--print-to-pdf=" + win(pdf), win(tmp)], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"md2pdf: {src} -> {pdf}")


if __name__ == "__main__":
    main()
