"""Judge vulnerability matches one CVE at a time for nix-vuln-status-refresh.

  judge.py prepare --config CONFIG --sbom SBOM --out OUT
      Copies the SBOM. A component of a configured family that sbomnix left
      without a CPE gets the family's CPE, so grype matches it too.

  judge.py judge --config CONFIG --grype GRYPE --closure CLOSURE --out OUT
      Decides, for every grype match on a family component, whether the CVE
      is counted. The description is resolved to the source files, functions
      or components it names, and each one is checked against the builds of
      that component in the closure:

        not-built   no build compiles it: the build's own libraries list its
                    components, and the family's source index (ffmpeg-map.py)
                    says under which conditions each file is compiled
        not-called  compiled, but every program linking the build matches a
                    usage profile that cannot reach it
        counted     anything else, including descriptions that name nothing
                    resolvable and builds whose contents cannot be read

Nothing is ignored by package: each new CVE goes through the same checks.
"""

import argparse
import ctypes
import glob
import json
import os
import re
import subprocess
import sys

STORE_NAME = re.compile(r"^/nix/store/[a-z0-9]{32}-")
OUTPUT_NAMES = {"bin", "lib", "data", "dev", "doc", "man", "out", "info", "static", "devdoc"}
NON_RUNTIME = re.compile(r"-(dev|doc|devdoc|man|info)$")
LIBS = ("libavcodec", "libavdevice", "libavfilter", "libavformat", "libavutil",
        "libpostproc", "libswresample", "libswscale")
ARCH_DIRS = {"aarch64", "alpha", "arm", "bfin", "loongarch", "mips", "ppc", "riscv", "s390", "sh4", "sparc", "wasm", "x86"}
KIND_KEYS = {"DECODER": "decoders", "ENCODER": "encoders", "DEMUXER": "demuxers", "MUXER": "muxers",
             "BSF": "bsfs", "FILTER": "filters", "PROTOCOL": "protocols", "INDEV": "indevs", "OUTDEV": "outdevs"}
PHRASE_KEYS = {"decoder": "decoders", "encoder": "encoders", "demuxer": "demuxers", "muxer": "muxers",
               "parser": "parsers", "bitstream filter": "bsfs", "filter": "filters",
               "protocol handler": "protocols", "protocol": "protocols"}
PHRASE_KINDS = {"decoder": "DECODER", "encoder": "ENCODER", "demuxer": "DEMUXER", "muxer": "MUXER",
                "parser": "PARSER", "bitstream filter": "BSF", "filter": "FILTER",
                "protocol handler": "PROTOCOL", "protocol": "PROTOCOL"}
HW_API = {"VAAPI": "vaapi", "VDPAU": "vdpau", "NVDEC": "cuda", "VULKAN": "vulkan", "D3D11VA": "d3d11va",
          "D3D11VA2": "d3d11va", "D3D12VA": "d3d12va", "DXVA2": "dxva2", "VIDEOTOOLBOX": "videotoolbox"}
HW_SYMBOLS = {"vaapi", "vdpau", "vulkan", "cuda", "opencl", "amf", "drm", "qsv", "d3d11va", "d3d12va",
              "dxva2", "videotoolbox", "mediacodec"}
PATHS = re.compile(r"\b((?:" + "|".join(LIBS + ("fftools",)) + r")/[\w./+-]+\.(?:c|h|S|asm|cpp|m))\b")
BARE = re.compile(r"(?<![\w/.])([\w+-]+\.(?:c|S|asm|cpp|m))\b")
PHRASE = re.compile(r"\b(?:the |in )?([\w .+/-]{2,40}?) (decoder|encoder|demuxer|muxer|parser|bitstream filter|protocol handler|protocol|filter)\b")
FUNCTION = re.compile(r"\b([A-Za-z_]\w{3,})\(\)")
STOPWORDS = {"the", "a", "an", "in", "native", "via", "of", "and", "its"}


def store_name(path):
    return STORE_NAME.sub("", path)


# ---------------------------------------------------------------- inventory


def inventory(lib_dir):
    """Components compiled into one FFmpeg build, read from its libraries."""
    def so(name):
        cands = sorted(glob.glob(f"{lib_dir}/lib/lib{name}.so.*"), key=len)
        return cands[0] if cands else None

    codec = so("avcodec")
    if not codec:
        return {"source": "none"}
    with open(codec, "rb") as f:
        head = f.read(5)
        bits = {1: 32, 2: 64}.get(head[4])
        f.seek(0)
        m = re.search(rb"--prefix=[^\x00]{8,}", f.read())
    configure = m.group(0).decode(errors="replace") if m else ""
    out = {"source": "configure", "bits": bits, "configuration": configure}
    if bits != ctypes.sizeof(ctypes.c_void_p) * 8:
        return out

    vp = ctypes.c_void_p

    def iterate(fn):
        fn.restype, fn.argtypes = vp, [ctypes.POINTER(vp)]
        opaque, items = vp(None), []
        while True:
            p = fn(ctypes.byref(opaque))
            if not p:
                return items
            items.append(p)

    def cstr(p, offset=0):
        s = ctypes.cast(p + offset, ctypes.POINTER(ctypes.c_char_p))[0]
        return s.decode(errors="replace") if s else ""

    word = ctypes.sizeof(vp)
    avcodec = ctypes.CDLL(codec)
    avcodec.av_codec_is_decoder.argtypes = [vp]
    avcodec.av_codec_is_encoder.argtypes = [vp]
    avcodec.avcodec_get_name.restype = ctypes.c_char_p
    avcodec.avcodec_descriptor_next.restype = vp
    avcodec.avcodec_descriptor_next.argtypes = [vp]
    decoders, encoders = {}, {}
    for p in iterate(avcodec.av_codec_iterate):
        entry = (cstr(p), cstr(p, word))
        if avcodec.av_codec_is_decoder(p):
            decoders[entry[0]] = entry[1]
        if avcodec.av_codec_is_encoder(p):
            encoders[entry[0]] = entry[1]
    parsers = set()
    for p in iterate(avcodec.av_parser_iterate):
        ids = (ctypes.c_int * 7).from_address(p)
        parsers.update(avcodec.avcodec_get_name(i).decode() for i in ids if i)
    descriptors, d = set(), avcodec.avcodec_descriptor_next(None)
    while d:
        # AVCodecDescriptor starts with an enum id and a media type, then the name.
        descriptors.add(cstr(d, 8))
        d = avcodec.avcodec_descriptor_next(d)
    out.update(source="libraries", decoders=decoders, encoders=encoders, parsers=sorted(parsers),
               descriptors=sorted(descriptors), bsfs=sorted(cstr(p) for p in iterate(avcodec.av_bsf_iterate)))

    fmt = so("avformat")
    if fmt:
        avformat = ctypes.CDLL(fmt)
        out["demuxers"] = {cstr(p).split(",")[0]: cstr(p, word) for p in iterate(avformat.av_demuxer_iterate)}
        out["muxers"] = {cstr(p).split(",")[0]: cstr(p, word) for p in iterate(avformat.av_muxer_iterate)}
        avformat.avio_enum_protocols.restype = ctypes.c_char_p
        avformat.avio_enum_protocols.argtypes = [ctypes.POINTER(vp), ctypes.c_int]
        protocols = set()
        for direction in (0, 1):
            opaque = vp(None)
            while True:
                s = avformat.avio_enum_protocols(ctypes.byref(opaque), direction)
                if not s:
                    break
                protocols.add(s.decode())
        out["protocols"] = sorted(protocols)
    flt = so("avfilter")
    if flt:
        out["filters"] = sorted(cstr(p) for p in iterate(ctypes.CDLL(flt).av_filter_iterate))
    dev = so("avdevice")
    if dev:
        avdevice = ctypes.CDLL(dev)
        for fn, key in (("av_input_audio_device_next", "indevs"), ("av_input_video_device_next", "indevs"),
                        ("av_output_audio_device_next", "outdevs"), ("av_output_video_device_next", "outdevs")):
            f = getattr(avdevice, fn)
            f.restype, f.argtypes = vp, [vp]
            p = f(None)
            while p:
                out.setdefault(key, []).append(cstr(p).split(",")[0])
                p = f(p)
    avutil = ctypes.CDLL(so("avutil"))
    avutil.av_hwdevice_iterate_types.restype = ctypes.c_int
    avutil.av_hwdevice_iterate_types.argtypes = [ctypes.c_int]
    avutil.av_hwdevice_get_type_name.restype = ctypes.c_char_p
    avutil.av_hwdevice_get_type_name.argtypes = [ctypes.c_int]
    hw, t = [], 0
    while True:
        t = avutil.av_hwdevice_iterate_types(t)
        if t == 0:
            break
        hw.append(avutil.av_hwdevice_get_type_name(t).decode())
    out["hwdevices"] = hw
    return out


def normalized_configure(configure):
    """The configure flags without store paths and target-specific tools."""
    s = re.sub(r"/nix/store/[a-z0-9]{32}-[^ ]*", "", configure)
    s = re.sub(r"--(?:arch|cpu|cross-prefix|cc|cxx|ld|host-cc|nm|ar|ranlib|strip|pkg-config)=\S*", "", s)
    return set(s.split())


def covers(wide, narrow):
    """True when the build configured with `wide` has every component of the
    one configured with `narrow`: the lines differ only where `wide` enables
    a feature that `narrow` disables (AMF exists on x86_64 but not on i686)."""
    a, b = normalized_configure(narrow), normalized_configure(wide)
    only_narrow, only_wide = a - b, b - a
    return (all(f.startswith("--disable-") and "--enable-" + f[len("--disable-"):] in only_wide for f in only_narrow)
            and all(f.startswith("--enable-") and "--disable-" + f[len("--enable-"):] in only_narrow for f in only_wide))


# ------------------------------------------------------------------- builds


class Build:
    """One compiled FFmpeg: its components, source index and usage profile."""

    def __init__(self, lib_dir, inv, index, has_cli):
        self.lib_dir, self.inv, self.idx, self.has_cli = lib_dir, inv, index, has_cli
        self.known = inv.get("source") == "libraries"
        conf = inv.get("configuration", "")
        self.flags = set(re.findall(r"--((?:enable|disable)-[\w-]+)", conf))
        arch = re.search(r"--arch=(\S+)", conf)
        arch = arch.group(1) if arch else ""
        self.arch_dir = "x86" if arch in ("x86_64", "i686", "i386", "x86", "amd64") else ("aarch64" if arch in ("aarch64", "arm64") else None)
        self.names = {}
        for key in ("decoders", "encoders", "demuxers", "muxers"):
            self.names[key] = set((inv.get(key) or {}).keys())
        for key in ("bsfs", "filters", "protocols", "indevs", "outdevs", "parsers", "hwdevices", "descriptors"):
            self.names[key] = set(inv.get(key) or [])
        self.long = {k: inv.get(k) or {} for k in ("decoders", "encoders", "demuxers", "muxers")}
        self.memo = {}
        self.phrase_cache = {}
        self.profile = None
        self.profile_names = []

    # Whether a CONFIG_/HAVE_ symbol holds for this build. Unknown -> True.
    def enabled(self, sym, depth=0):
        if not self.known:
            return True
        if sym in self.memo:
            return self.memo[sym]
        self.memo[sym] = True
        value = self._enabled(sym, depth)
        self.memo[sym] = value
        return value

    def component(self, sym):
        m = re.match(r"CONFIG_(\w+?)_(DECODER|ENCODER|DEMUXER|MUXER|BSF|FILTER|PROTOCOL|PARSER|INDEV|OUTDEV|HWACCEL)$", sym)
        return (m.group(2), m.group(1)) if m else None

    def registered(self, kind, base):
        names = self.idx["names"]
        if kind == "INDEV":
            return names.get(f"DEMUXER {base}")
        if kind == "OUTDEV":
            return names.get(f"MUXER {base}")
        return names.get(f"{kind} {base}")

    def _enabled(self, sym, depth):
        if sym.startswith("HAVE_"):
            return True
        comp = self.component(sym)
        if comp:
            kind, base = comp
            if kind == "HWACCEL":
                api = base.rsplit("_", 1)[-1]
                return HW_API[api] in self.names["hwdevices"] if api in HW_API else True
            if kind == "PARSER":
                codecs = self.idx["parsers"].get(base)
                if not codecs:
                    return True
                if any(c in self.names["parsers"] for c in codecs):
                    return True
                return not all(c in self.names["descriptors"] for c in codecs)
            name = self.registered(kind, base)
            if name is None:
                return True
            return name in self.names[KIND_KEYS[kind]]
        low = sym[len("CONFIG_"):].lower()
        if low in HW_SYMBOLS:
            return low in self.names["hwdevices"]
        flag = low.replace("_", "-")
        if f"enable-{flag}" in self.flags:
            return True
        if f"disable-{flag}" in self.flags:
            return False
        if low in ("ffmpeg", "ffprobe", "ffplay"):
            return self.has_cli
        selectors = self.idx["selects"].get(sym[len("CONFIG_"):])
        if selectors and depth < 8:
            return any(self.enabled("CONFIG_" + s, depth + 1) for s in selectors)
        return True

    def conditions(self, rel, seen=()):
        """Condition sets under which a source file is compiled; None if unknown."""
        parts = rel.split("/")
        if len(parts) > 2 and parts[1] in ARCH_DIRS and self.arch_dir is not None:
            return [] if parts[1] != self.arch_dir else self.idx["objects"].get(re.sub(r"\.\w+$", ".o", rel))
        if parts[0] == "fftools":
            prog = "FFPROBE" if "ffprobe" in rel else "FFPLAY" if "ffplay" in rel else "FFMPEG"
            return [[f"CONFIG_{prog}"]]
        obj = re.sub(r"\.(c|S|asm|cpp|m)$", ".o", rel)
        if obj in self.idx["objects"]:
            return self.idx["objects"][obj]
        if rel in self.idx["includes"] and rel not in seen:
            out = []
            for includer in self.idx["includes"][rel]:
                c = self.conditions(includer, seen + (rel,))
                if c is None:
                    return None
                out.extend(c)
            return out
        return None

    def present(self, conds):
        return any(all(self.enabled(s) for s in c) for c in conds)

    # ------------------------------------------------------ usage profiles

    def callable_component(self, key, name):
        if self.profile is None:
            return True
        allowed = self.profile.get(key)
        return allowed == "*" or (isinstance(allowed, list) and name in allowed)

    def callable_symbol(self, sym, rel, depth=0):
        comp = self.component(sym)
        if comp:
            kind, base = comp
            if kind == "HWACCEL":
                return bool(self.profile.get("hwdecode"))
            if kind == "PARSER":
                codecs = self.idx["parsers"].get(base) or []
                allowed = self.profile.get("parsers")
                return allowed == "*" or (isinstance(allowed, list) and any(c in allowed for c in codecs))
            name = self.registered(kind, base)
            if name is None:
                # The profile allows none of this kind, whatever its name.
                return self.profile.get(KIND_KEYS[kind]) is not None
            return self.callable_component(KIND_KEYS[kind], name)
        low = sym[len("CONFIG_"):].lower()
        if low in HW_SYMBOLS or low in ("nvdec", "nvenc", "cuvid", "v4l2_m2m"):
            side = "hwencode" if re.search(r"enc", rel.rsplit("/", 1)[-1]) else "hwdecode"
            return bool(self.profile.get(side))
        if low in ("ffmpeg", "ffprobe", "ffplay"):
            return False
        selectors = self.idx["selects"].get(sym[len("CONFIG_"):])
        if selectors and depth < 8:
            return any(self.enabled("CONFIG_" + s) and self.callable_symbol("CONFIG_" + s, rel, depth + 1) for s in selectors)
        return True

    def callable_file(self, rel, conds):
        if self.profile is None:
            return True
        if rel.split("/")[0] not in self.profile.get("libraries", []):
            return False
        for c in conds:
            if not all(self.enabled(s) for s in c):
                continue
            if all(s.startswith("HAVE_") or self.callable_symbol(s, rel) for s in c):
                return True
        return False

    # ------------------------------------------------------------ judging

    def resolve_phrase(self, phrase, kind):
        """Registered names that "the <phrase> <kind>" can mean, split into
        those this build has and those that exist in the source only."""
        cached = self.phrase_cache.get((phrase, kind))
        if cached is None:
            cached = self.phrase_cache[(phrase, kind)] = self._resolve_phrase(phrase, kind)
        return cached

    def _resolve_phrase(self, phrase, kind):
        key, kind_tag = PHRASE_KEYS[kind], PHRASE_KINDS[kind]
        words = [w for w in re.split(r"[\s()/]+", phrase) if w and w.lower() not in STOPWORDS]
        forms = set()
        for i in range(len(words)):
            for joined in ("".join(words[i:]), "_".join(words[i:])):
                joined = joined.lower()
                forms.update({joined, joined.replace("-", "").replace(".", "")})
        text = " ".join(words).lower()
        known = set()
        if kind_tag == "PARSER":
            for base, codecs in self.idx["parsers"].items():
                if base.lower() in forms:
                    known.update(codecs)
        else:
            for k, registered in self.idx["names"].items():
                tag, _, base = k.partition(" ")
                if tag != kind_tag:
                    continue
                long_name = (self.idx.get("longnames", {}).get(k) or "").lower()
                if registered.lower() in forms or base.lower() in forms or (long_name and text and (text in long_name or long_name in text)):
                    known.add(registered)
        pool = self.names.get(key, set())
        for form in forms:
            if form in pool:
                known.add(form)
        for name, long_name in self.long.get(key, {}).items():
            ln = (long_name or "").lower()
            if ln and text and (text in ln or ln in text):
                known.add(name)
        return key, {n for n in known if n in pool}, {n for n in known if n not in pool}

    def judge(self, desc):
        locations = [("file", p) for p in PATHS.findall(desc)]
        for bare in BARE.findall(desc):
            if not any(loc[1].endswith("/" + bare) for loc in locations):
                locations += [("file", p) for p in self.idx["files"].get(bare, [])]
        phrases = []
        for phrase, kind in PHRASE.findall(desc):
            key, built, source_only = self.resolve_phrase(phrase.strip(), kind)
            if built or source_only:
                phrases.append((kind, key, built, source_only))
        # Function names are a last resort: helpers such as decode_init() or
        # av_strireplace() exist in many files, so they only stand in for a
        # location when the text names no file and no known component.
        if not locations and not phrases:
            for fn in FUNCTION.findall(desc):
                locations += [("file", p) for p in self.idx["functions"].get(fn, [])]
        if not locations and not phrases:
            return "counted", "names no known file or component"

        outcomes = []
        for _, val in locations:
            conds = self.conditions(val)
            if conds is None:
                return "counted", f"no build rule for {val}"
            if not self.present(conds):
                outcomes.append(("not-built", val))
            elif self.callable_file(val, conds):
                return "counted", f"{val} is compiled"
            else:
                outcomes.append(("not-called", val))
        for kind, key, built, source_only in phrases:
            if any(self.callable_component(key, c) for c in built):
                return "counted", f"{kind} {sorted(c for c in built if self.callable_component(key, c))[0]} is compiled"
            if built:
                outcomes.append(("not-called", f"{kind} {sorted(built)[0]}"))
            else:
                outcomes.append(("not-built", f"{kind} {sorted(source_only)[0]}"))
        if any(o == "not-called" for o, _ in outcomes):
            return "not-called", ", ".join(sorted({v for o, v in outcomes if o == "not-called"}))
        return "not-built", ", ".join(sorted({v for _, v in outcomes}))


# --------------------------------------------------------------- commands


def load_config(path):
    with open(path) as f:
        cfg = json.load(f)
    for fam in cfg.get("families", []):
        fam["regex"] = re.compile(fam["component"])
    return cfg


def cmd_prepare(args):
    cfg = load_config(args.config)
    with open(args.sbom) as f:
        sbom = json.load(f)
    added = 0
    by_name = cfg.get("cpeByName", {})
    for comp in sbom.get("components", []):
        if comp.get("cpe") or not comp.get("version"):
            continue
        template = by_name.get(comp.get("name", ""))
        if template is None:
            template = next((f["cpe"] for f in cfg["families"] if f.get("cpe") and f["regex"].match(comp.get("name", ""))), None)
        if template:
            comp["cpe"] = template.replace("{version}", comp["version"])
            added += 1
    with open(args.out, "w") as f:
        json.dump(sbom, f)
    print(json.dumps({"cpeFromName": added}))


def description(match):
    v = match.get("vulnerability", {})
    if v.get("description"):
        return v["description"]
    for r in match.get("relatedVulnerabilities") or []:
        if r.get("description"):
            return r["description"]
    return ""


def cmd_judge(args):
    cfg = load_config(args.config)
    with open(args.grype) as f:
        grype = json.load(f)
    with open(args.closure) as f:
        closure = [line.strip() for line in f if line.strip()]
    closure_set = set(closure)
    names = {p: store_name(p) for p in closure}

    def outputs(artifact):
        drv = artifact.get("id") or ""
        if drv.endswith(".drv") and os.path.exists(drv):
            r = subprocess.run(["nix-store", "--query", "--outputs", drv], capture_output=True, text=True)
            outs = [p for p in r.stdout.split() if p in closure_set]
            if outs:
                return outs, "derivation"
        stem = f"{artifact['name']}-{artifact['version']}"
        return [p for p, n in names.items() if n == stem or (n.startswith(stem + "-") and n[len(stem) + 1:] in OUTPUT_NAMES)], "name"

    def referrers(path):
        r = subprocess.run(["nix-store", "--query", "--referrers", path], capture_output=True, text=True)
        return [p for p in r.stdout.split() if p in closure_set]

    inventories, indexes, artifacts = {}, {}, {}
    result = {"judgments": {}, "artifacts": []}

    def index_for(fam, version):
        path = fam.get("maps", {}).get(version)
        if not path:
            return None
        if path not in indexes:
            with open(path) as f:
                indexes[path] = json.load(f)
        return indexes[path]

    def family_of(artifact):
        return next((f for f in cfg["families"] if f["regex"].match(artifact.get("name", ""))), None)

    def artifact_key(artifact):
        return artifact.get("id") or f"{artifact['name']}@{artifact['version']}"

    # Read every build first, so that a build whose libraries cannot be
    # loaded here (32-bit) can reuse the component list of a build with the
    # same configure line, whatever order grype reports them in.
    layouts = {}
    for match in grype.get("matches", []):
        artifact = match.get("artifact", {})
        key = artifact_key(artifact)
        if key in layouts or not family_of(artifact):
            continue
        outs, via = outputs(artifact)
        layouts[key] = (outs, via)
        for lib in outs:
            if lib not in inventories and glob.glob(f"{lib}/lib/libavcodec.so.*"):
                try:
                    inventories[lib] = inventory(lib)
                except Exception as e:  # unreadable build: everything counts
                    inventories[lib] = {"source": "error", "error": str(e)}

    def builds_for(fam, artifact):
        key = artifact_key(artifact)
        if key in artifacts:
            return artifacts[key]
        outs, via = layouts[key]
        idx = index_for(fam, artifact["version"])
        lib_dirs = [p for p in outs if p in inventories]
        bin_dirs = [p for p in outs if glob.glob(f"{p}/bin/ffmpeg") or glob.glob(f"{p}/bin/ffprobe")]
        builds, info = [], {"artifact": key, "name": artifact["name"], "version": artifact["version"],
                            "outputsFrom": via, "index": idx is not None, "builds": []}
        for lib in lib_dirs:
            inv = inventories[lib]
            if inv.get("source") == "configure":
                twin = next((i for i in inventories.values() if i.get("source") == "libraries"
                             and covers(i.get("configuration", ""), inv.get("configuration", ""))), None)
                if twin:
                    inv = dict(twin, configuration=inv.get("configuration", ""), source="libraries",
                               reusedFrom="a build whose configure line enables at least the same features")
            b = Build(lib, inv, idx, bool(bin_dirs)) if idx else None
            consumers = sorted({names[r] for p in [lib] + bin_dirs for r in referrers(p)
                                if r not in outs and not NON_RUNTIME.search(names[r])})
            profile, matched = None, []
            if not bin_dirs and consumers:
                for c in consumers:
                    hits = [p for p in fam.get("profiles", []) if re.search(p["consumer"], c)]
                    if not hits:
                        matched = []
                        break
                    matched.extend(hits)
                if matched:
                    profile = {}
                    # A CVE reviewed as not called is skipped only when every
                    # matched profile says so.
                    reviewed = [p.get("notCalled", {}) for p in matched]
                    profile["notCalled"] = {cve: why for cve, why in reviewed[0].items()
                                            if all(cve in r for r in reviewed[1:])}
                    for p in matched:
                        for k, v in p.items():
                            if k in ("consumer", "reason", "notCalled"):
                                continue
                            if v == "*" or profile.get(k) == "*":
                                profile[k] = "*"
                            elif isinstance(v, list):
                                profile[k] = sorted(set(profile.get(k, [])) | set(v))
                            else:
                                profile[k] = bool(profile.get(k)) or v
            if b:
                b.profile = profile
                b.profile_names = sorted({p["consumer"] for p in matched})
                builds.append(b)
            info["builds"].append({"lib": lib, "inventory": inv.get("source"), "reusedFrom": inv.get("reusedFrom"),
                                   "cli": bool(bin_dirs), "consumers": consumers,
                                   "profiles": sorted({p["consumer"] for p in matched}) if profile else []})
        artifacts[key] = (builds, idx is not None and bool(lib_dirs))
        result["artifacts"].append(info)
        return artifacts[key]

    for match in grype.get("matches", []):
        artifact = match.get("artifact", {})
        fam = family_of(artifact)
        if not fam:
            continue
        key = f"{match['vulnerability']['id']}|{artifact.get('id', '')}"
        try:
            builds, judged = builds_for(fam, artifact)
            if not judged or not builds:
                verdict, detail = "counted", "no readable build or source index"
            else:
                desc = description(match)
                vid = match["vulnerability"]["id"]
                results = [("not-called", f"reviewed: {b.profile['notCalled'][vid]}")
                           if b.profile and vid in b.profile.get("notCalled", {}) else b.judge(desc)
                           for b in builds]
                if any(v == "counted" for v, _ in results):
                    verdict, detail = next(r for r in results if r[0] == "counted")
                elif any(v == "not-called" for v, _ in results):
                    verdict, detail = next(r for r in results if r[0] == "not-called")
                else:
                    verdict, detail = results[0]
        except Exception as e:
            verdict, detail = "counted", f"judge error: {e}"
        result["judgments"][key] = {"verdict": verdict, "detail": detail}

    with open(args.out, "w") as f:
        json.dump(result, f, indent=1)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--config", required=True)
    p.add_argument("--sbom", required=True)
    p.add_argument("--out", required=True)
    j = sub.add_parser("judge")
    j.add_argument("--config", required=True)
    j.add_argument("--grype", required=True)
    j.add_argument("--closure", required=True)
    j.add_argument("--out", required=True)
    args = ap.parse_args()
    {"prepare": cmd_prepare, "judge": cmd_judge}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
