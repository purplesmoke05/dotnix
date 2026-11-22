"""Index an FFmpeg source tree for nix-vuln-status-judge.

Usage: python3 -I ffmpeg-map.py SOURCE_DIR > map.json

The judge reads CVE descriptions that name source files, functions or
components, and needs to know under which build conditions that code is
compiled. This index records it, so the source tree is not needed at scan
time:

  objects    object file -> condition sets; a set lists CONFIG_/HAVE_ symbols
             that must all hold, and an empty set means always compiled
  names      "KIND NAME" of CONFIG_<NAME>_<KIND> -> the registered component
             name, which can differ (CONFIG_BINK_DECODER is "binkvideo");
             components built by a macro take the name the macro gives them
  longnames  "KIND NAME" -> the component's descriptive name ("Go2Meeting")
  parsers    CONFIG_<NAME>_PARSER name -> codec names the parser handles
  selects    subsystem -> components and subsystems whose configure entry
             selects it
  files      file base name -> source paths
  includes   .c file pulled in with #include -> the .c files that include it
  functions  function name -> files that define it
"""

import collections
import json
import os
import re
import sys

LIBS = [
    "libavcodec",
    "libavdevice",
    "libavfilter",
    "libavformat",
    "libavutil",
    "libpostproc",
    "libswresample",
    "libswscale",
    "fftools",
]
SOURCE_SUFFIXES = (".c", ".h", ".S", ".asm", ".cpp", ".m")

root = sys.argv[1]
objects = collections.defaultdict(list)
names = {}
longnames = {}
parsers = {}
# Files whose components come from a macro that names each one after its
# variable (const FFCodec ff_ ## name_ ## _encoder = { .p.name = #name_, ...),
# directly or through an included header.
macro_named = set()
header_macros = set()
c_includes = collections.defaultdict(set)
selects = collections.defaultdict(set)
files = collections.defaultdict(list)
includes = collections.defaultdict(set)
functions = collections.defaultdict(set)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def parse_makefile(lib, path):
    """Record OBJS-style assignments, including $(call ALLYES, ...) guards."""
    text = read(path).replace("\\\n", " ")
    for line in text.splitlines():
        m = re.match(r"^\s*((?:[A-Z0-9_]+-)*[A-Z0-9_]*OBJS)", line)
        if not m or m.group(1) in ("TESTOBJS", "TOOLOBJS", "FUZZOBJS", "CHECKASMOBJS"):
            continue
        rest = line[m.end():]
        guard = ""
        if rest.startswith("-"):
            rest = rest[1:]
            if not rest.startswith("$("):
                continue
            depth, end = 0, None
            for i, ch in enumerate(rest):
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        end = i
                        break
            if end is None:
                continue
            guard, rest = rest[: end + 1], rest[end + 1:]
        a = re.match(r"^\s*\+?=\s*(.*)$", rest)
        if not a:
            continue
        symbols = sorted(set(re.findall(r"\b(?:CONFIG|HAVE)_\w+", guard)))
        if guard and not symbols:
            continue
        for obj in a.group(1).split():
            if obj.endswith(".o"):
                objects[f"{lib}/{obj}"].append(symbols)


DEFINITION = re.compile(
    r"^(?:const\s+)?(?:FFCodec|FFInputFormat|FFOutputFormat|FFBitStreamFilter|URLProtocol"
    r"|FFFilter|AVFilter|FFCodecParser|AVCodecParser)\s+ff_(\w+)\s*=\s*\{(.*?)^\};",
    re.M | re.S,
)
FUNCTION = re.compile(r"^(?!\s)(?!#)(?!(?:if|for|while|switch|return|else|do)\b)[A-Za-z_][\w\s\*]*?\b([A-Za-z_]\w*)\s*\(")
INCLUDE = re.compile(r'^\s*#\s*include\s+"([\w/.+-]+\.c)"', re.M)
HEADER_INCLUDE = re.compile(r'^\s*#\s*include\s+"([\w/.+-]+\.h)"', re.M)
FILTER_PREFIX = re.compile(r"^(?:vf|af|vsrc|asrc|avsrc|vsink|asink|avf|vaf)_")
MACRO_VARIABLE = re.compile(r"ff_\s*##\s*(\w+)\s*##\s*_(?:decoder|encoder|demuxer|muxer|bsf|protocol)\b")
MACRO_NAME = re.compile(r"\.(?:p\.)?name\s*=\s*#\s*(\w+)")
LONG_NAME = re.compile(r'CODEC_LONG_NAME\(\s*"([^"]+)"|long_name\s*=\s*NULL_IF_CONFIG_SMALL\(\s*"([^"]+)"')


def names_by_macro(text):
    """True when a macro in the text names components after their variable."""
    return bool(set(MACRO_VARIABLE.findall(text)) & set(MACRO_NAME.findall(text)))

for lib in LIBS:
    for dirpath, _, filenames in os.walk(os.path.join(root, lib)):
        for name in filenames:
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root)
            if name == "Makefile":
                parse_makefile(lib, path)
                continue
            if not name.endswith(SOURCE_SUFFIXES):
                continue
            files[name].append(rel)
            if name.endswith(".h"):
                if names_by_macro(read(path)):
                    header_macros.add(rel)
                continue
            if not name.endswith(".c"):
                continue
            text = read(path)
            if names_by_macro(text):
                macro_named.add(rel)
            for inc in HEADER_INCLUDE.findall(text):
                c_includes[rel].add(os.path.normpath(os.path.join(os.path.dirname(rel), inc)))
                c_includes[rel].add(f"{lib}/{inc}")
            for line in text.splitlines():
                if line.rstrip().endswith(";"):
                    continue
                m = FUNCTION.match(line)
                if m:
                    functions[m.group(1)].add(rel)
            for inc in INCLUDE.findall(text):
                for cand in (os.path.normpath(os.path.join(os.path.dirname(rel), inc)), f"{lib}/{inc}"):
                    if os.path.exists(os.path.join(root, cand)):
                        includes[cand].add(rel)
                        break
            for var, body in DEFINITION.findall(text):
                kind = re.search(r"_(decoder|encoder|demuxer|muxer|bsf|protocol|parser)$", var)
                if kind and kind.group(1) == "parser":
                    ids = re.findall(r"AV_CODEC_ID_(\w+)", body)
                    if ids:
                        parsers[var[: -len(kind.group(0))].upper()] = sorted({i.lower() for i in ids})
                    continue
                m = re.search(r'\.(?:p\.)?name\s*=\s*"([^"]+)"', body)
                if not m:
                    continue
                registered = m.group(1).split(",")[0]
                if kind:
                    key = f"{kind.group(1).upper()} {var[: -len(kind.group(0))].upper()}"
                elif lib == "libavfilter":
                    key = f"FILTER {FILTER_PREFIX.sub('', var).upper()}"
                else:
                    continue
                names[key] = registered
                long_name = LONG_NAME.search(body)
                if long_name:
                    longnames[key] = long_name.group(1) or long_name.group(2)

for m in re.finditer(r'^(\w+)_(?:select|suggest)="([^"]*)"', read(os.path.join(root, "configure")), re.M):
    for dep in m.group(2).split():
        selects[dep.upper()].add(m.group(1).upper())

# Components that a naming macro builds: the registered name is the variable
# stem, which is the CONFIG name in lower case.
for obj, conds in objects.items():
    source = re.sub(r"\.o$", ".c", obj)
    if source not in macro_named and not (c_includes.get(source, set()) & header_macros):
        continue
    for cond in conds:
        for sym in cond:
            m = re.match(r"CONFIG_(\w+?)_(DECODER|ENCODER|DEMUXER|MUXER|BSF|PROTOCOL)$", sym)
            if m and f"{m.group(2)} {m.group(1)}" not in names:
                names[f"{m.group(2)} {m.group(1)}"] = m.group(1).lower()

version = read(os.path.join(root, "RELEASE")).strip() if os.path.exists(os.path.join(root, "RELEASE")) else None
json.dump(
    {
        "version": version,
        "objects": objects,
        "names": names,
        "longnames": longnames,
        "parsers": parsers,
        "selects": {k: sorted(v) for k, v in selects.items()},
        "files": files,
        "includes": {k: sorted(v) for k, v in includes.items()},
        "functions": {k: sorted(v) for k, v in functions.items()},
    },
    sys.stdout,
    sort_keys=True,
)
