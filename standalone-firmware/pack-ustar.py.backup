#!/usr/bin/env python3
"""Build BusyBox-compatible USTAR tar. Strip Windows CRLF from text files."""
import io
import os
import sys
import tarfile
from pathlib import Path

TEXT_EXT = {
    '.sh', '.html', '.htm', '.js', '.css', '.json', '.conf', '.txt',
    '.md', '.awk', '.cgi', '.csv',
}
TEXT_NAMES = {'VERSION', 'install.sh', 'rc.poststart', 'rc.prestart'}
SKIP = {'.DS_Store', 'Thumbs.db', '__pycache__'}
BIN_NAMES = {'udp-beacon'}
EXEC_NAMES = {'install.sh', 'rc.poststart', 'rc.prestart', 'udp-beacon'}


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
    with tarfile.open(out, 'w', format=tarfile.USTAR_FORMAT, encoding='utf-8', errors='surrogateescape') as tar:
        for src in iter_sources(root):
            rel = src.relative_to(root).as_posix()
            if src.name in SKIP or src.suffix == '.pyc':
                continue
            if len(rel) > 100:
                raise SystemExit('path too long for USTAR: ' + rel)
            data = src.read_bytes()
            if is_text(src):
                data = data.replace(b'\r\n', b'\n').replace(b'\r', b'\n')
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
    print('built', out, 'bytes', out.stat().st_size)


if __name__ == '__main__':
    main()
