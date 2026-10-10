"""Checks that every 64-bit native library in an .aab or .apk supports
16 KB memory pages, which Google Play requires for apps targeting Android 15
and later. Exits with 1 and names the libraries that don't.

    python3 tool/check_16kb.py build/app/outputs/bundle/release/app-release.aab
"""
import io
import struct
import sys
import zipfile

PAGE = 0x4000  # 16 KB
ABIS = ('arm64-v8a', 'x86_64')  # 32-bit ABIs don't use 16 KB pages


def min_load_alignment(elf: bytes) -> int:
    """Smallest alignment of the LOAD segments of a 64-bit ELF file."""
    if elf[:4] != b'\x7fELF' or elf[4] != 2:
        raise ValueError('not a 64-bit ELF file')
    phoff = struct.unpack_from('<Q', elf, 0x20)[0]
    phentsize, phnum = struct.unpack_from('<HH', elf, 0x36)
    aligns = []
    for i in range(phnum):
        off = phoff + i * phentsize
        if struct.unpack_from('<I', elf, off)[0] == 1:  # PT_LOAD
            aligns.append(struct.unpack_from('<Q', elf, off + 48)[0])
    return min(aligns)


def check(path: str) -> list[str]:
    bad = []
    with zipfile.ZipFile(path) as z:
        libs = [n for n in z.namelist()
                if n.endswith('.so') and any(f'lib/{a}/' in n for a in ABIS)]
        for name in sorted(libs):
            align = min_load_alignment(z.read(name))
            ok = align >= PAGE
            print(f"{'ok ' if ok else 'BAD'} {hex(align):>8}  {name}")
            if not ok:
                bad.append(name)
        if not libs:
            print('no 64-bit native libraries found')
    return bad


if __name__ == '__main__':
    failed = [lib for p in sys.argv[1:] for lib in check(p)]
    if failed:
        print(f'\n{len(failed)} native librar{"y is" if len(failed) == 1 else "ies are"} '
              'not 16 KB aligned. Google Play will reject this build.')
        sys.exit(1)
    print('\nAll 64-bit native libraries support 16 KB pages.')
