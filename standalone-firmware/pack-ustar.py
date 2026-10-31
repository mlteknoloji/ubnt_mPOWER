#!/usr/bin/env python3
"""Build BusyBox-compatible USTAR tar. Strip Windows CRLF from text files."""
import gzip
import io
import os
import re
import sys
import tarfile
from pathlib import Path

TEXT_EXT = {
    '.sh', '.html', '.htm', '.js', '.css', '.json', '.conf', '.txt',
    '.md', '.awk', '.cgi', '.csv',
}
TEXT_NAMES = {'VERSION', 'install.sh', 'rc.poststart', 'rc.prestart'}
# reset-block.sh: unused since 1.3.30 (no mount over wevent any more).
# favicon.ico: pages link favicon.svg/png only.
SKIP = {'.DS_Store', 'Thumbs.db', '__pycache__', 'reset-block.sh', 'favicon.ico'}
BIN_NAMES = {'udp-beacon'}
EXEC_NAMES = {'install.sh', 'rc.poststart', 'rc.prestart', 'udp-beacon'}

# Everything under payload/ ends up in /etc/persistent, which cfgmtd stores
# gzip-compressed in one half of the 256KB "cfg" MTD (~128KB per copy). Stock
# mFi data shares that space (~13KB seen on 2026-10-30). Over the limit cfgmtd
# dies with "Segmentation fault" / "Bus error" and nothing is persisted.
OVERLAY_GZ_BUDGET = 112 * 1024


def shrink_sh(text: str) -> str:
    """Drop comment-only/blank lines and indentation. Safe for this payload:
    no heredocs; the only multi-line quoted strings are awk programs, where
    indentation and '#' comment lines carry no meaning."""
    out = []
    for i, line in enumerate(text.split('\n')):
        s = line.lstrip(' \t')
        if i == 0 and s.startswith('#!'):
            out.append(s)
        elif s and not s.startswith('#'):
            out.append(s)
    return '\n'.join(out) + '\n'


def shrink_web(text: str) -> str:
    """Strip indentation and blank lines; <pre> blocks are kept verbatim."""
    out = []
    pre = False
    tpl = False  # inside a multi-line JS template literal (`...`)
    for line in text.split('\n'):
        low = line.lower()
        # Unescaped backticks toggle template-literal state. Text inside a
        # template (e.g. the API doc shown in <pre>) keeps its indentation and
        # blank lines.
        ticks = len(re.findall(r'(?<!\\)`', line))
        if tpl:
            out.append(line)
            if ticks % 2:
                tpl = False
            continue
        if pre:
            out.append(line)
            if '</pre' in low:
                pre = False
            continue
        if '<pre' in low and '</pre' not in low:
            pre = True
            out.append(line)
            continue
        if ticks % 2:
            tpl = True
        s = line.strip(' \t')
        # Whole-line comments cost cfg flash (~1 KB gzip in total). Only lines
        # that are nothing but a comment are dropped, never trailing ones.
        if s.startswith('//') or (s.startswith('/*') and s.endswith('*/')):
            continue
        if s:
            out.append(s)
    return '\n'.join(out) + '\n'


# BusyBox httpd sends no Cache-Control and never answers 304, so browsers cache
# static files on heuristics and may keep an old i18n.js after an update.
# A ?v=<version> suffix gives every release its own URL (query strings are
# served normally by httpd).
ASSET_REF = re.compile(r'''((?:href|src)=["']?)(style\.css|i18n\.js|favicon\.svg|favicon\.png)(?=["'\s>])''')


def version_assets(text: str, version: str) -> str:
    def repl(m):
        attr, name = m.group(1), m.group(2)
        if attr.endswith('='):  # unquoted: '=' in the value needs quotes
            return attr + '"' + name + '?v=' + version + '"'
        return attr + name + '?v=' + version
    return ASSET_REF.sub(repl, text)


def shrink(rel: str, data: bytes, version: str = '') -> bytes:
    if not rel.startswith('payload/'):
        return data
    name = rel.rsplit('/', 1)[-1]
    if name.endswith('.sh') or name in ('rc.prestart', 'rc.poststart'):
        return shrink_sh(data.decode('utf-8')).encode('utf-8')
    if name.endswith(('.html', '.css', '.js')):
        text = shrink_web(data.decode('utf-8'))
        if name.endswith('.html') and version:
            text = version_assets(text, version)
        return text.encode('utf-8')
    return data


def is_text(path: Path) -> bool:
    if path.name in BIN_NAMES:
        return False
    if path.name in TEXT_NAMES:
        return True
    return path.suffix.lower() in TEXT_EXT


def iter_sources(root: Path):
    for name in ('install.sh', 'VERSION', 'payload'):
        p = root / name
        if p.is_file():
            yield p
        elif p.is_dir():
            for child in sorted(p.rglob('*')):
                if child.is_file():
                    yield child


def main():
    if len(sys.argv) < 3:
        raise SystemExit('usage: pack-ustar.py ROOT OUT.tar')
    root = Path(sys.argv[1]).resolve()
    out = Path(sys.argv[2]).resolve()
    os.chdir(root)
    persist_files = []
    version = (root / 'VERSION').read_text(encoding='utf-8').strip()
    version = re.sub(r'[^A-Za-z0-9._-]', '', version)
    with tarfile.open(out, 'w', format=tarfile.USTAR_FORMAT, encoding='utf-8', errors='surrogateescape') as tar:
        for src in iter_sources(root):
            rel = src.relative_to(root).as_posix()
            if src.name in SKIP or src.suffix in ('.pyc', '.backup', '.bak', '.orig'):
                continue
            if len(rel) > 100:
                raise SystemExit('path too long for USTAR: ' + rel)
            data = src.read_bytes()
            if is_text(src):
                data = data.replace(b'\r\n', b'\n').replace(b'\r', b'\n')
                data = shrink(rel, data, version)
            if rel.startswith('payload/'):
                persist_files.append((rel, data))
            ti = tarfile.TarInfo(name=rel)
            ti.size = len(data)
            ti.mtime = int(src.stat().st_mtime)
            ti.uname = 'root'
            ti.gname = 'root'
            ti.uid = 0
            ti.gid = 0
            mode = src.stat().st_mode & 0o777
            if src.suffix == '.sh' or src.name in EXEC_NAMES:
                mode |= 0o755
            ti.mode = mode
            tar.addfile(ti, io.BytesIO(data))
        names = set(tar.getnames())
        for required in ('install.sh', 'VERSION', 'payload/mpower/www/settings.html'):
            if required not in names:
                raise SystemExit('missing from package: ' + required)
    gz = persist_gz_size(persist_files)
    print('built', out, 'bytes', out.stat().st_size,
          'persist_gz', gz, 'budget', OVERLAY_GZ_BUDGET)
    if gz > OVERLAY_GZ_BUDGET:
        out.unlink()
        raise SystemExit('overlay too big for the cfg flash: %d > %d bytes gzip '
                         '(cfgmtd would crash on the device)' % (gz, OVERLAY_GZ_BUDGET))


def persist_gz_size(files) -> int:
    """Approximate what cfgmtd stores: gzip of a tar of /etc/persistent."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w', format=tarfile.USTAR_FORMAT) as t:
        for rel, data in files:
            ti = tarfile.TarInfo(rel[len('payload/'):])
            ti.size = len(data)
            t.addfile(ti, io.BytesIO(data))
    return len(gzip.compress(buf.getvalue(), 6))


if __name__ == '__main__':
    main()
