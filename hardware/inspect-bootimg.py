#!/usr/bin/env python3
"""Inspect an Android v0 boot image against what the ZenPad 3S 10 (P027) LK expects.

Usage:  python3 -I inspect-bootimg.py BOOT.img [DTB_OUT_DIR]

Checks (see ZENPAD-DEBIAN-NATIVE-SPEC.md, section 2.3):
  - header v0, page 2048, same load addresses as the stock boot image
  - cmdline contains bootopt=64S3,... (LK uses it to boot a 64-bit kernel)
  - kernel = gzip'd arm64 Image with exactly one DTB appended, no MediaTek header
  - decompressed kernel (image_size) ends before the ramdisk address
  - total size fits the 16 MiB boot/recovery partitions
If DTB_OUT_DIR is given, appended DTBs are written there as dtb1.dtb, dtb2.dtb, ...
"""
import os
import struct
import sys
import zlib

STOCK = {"kernel_addr": 0x40080000, "ramdisk_addr": 0x44000000,
         "second_addr": 0x40F00000, "tags_addr": 0x4E000000, "page_size": 2048}
PARTITION_SIZE = 16 * 1024 * 1024


def split_dtbs(blob):
    """Split concatenated FDT blobs; returns list of bytes. Stops at first non-FDT data."""
    out, pos = [], 0
    while pos + 8 <= len(blob) and blob[pos:pos + 4] == b"\xd0\x0d\xfe\xed":
        total = struct.unpack_from(">I", blob, pos + 4)[0]
        if total < 40 or pos + total > len(blob):
            break
        out.append(blob[pos:pos + total])
        pos += total
    return out, len(blob) - pos


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else None
    data = open(path, "rb").read()
    if data[:8] != b"ANDROID!":
        sys.exit("FAIL: not an Android boot image (missing ANDROID! magic)")

    (ksz, kaddr, rsz, raddr, ssz, saddr, tags, page, hver, osver) = struct.unpack_from("<10I", data, 8)
    cmdline = data[64:64 + 512].split(b"\0", 1)[0].decode(errors="replace")
    extra = data[608:608 + 1024].split(b"\0", 1)[0].decode(errors="replace")
    problems, warnings = [], []

    print(f"file            {path} ({len(data)} bytes)")
    print(f"header_version  {hver}    page_size {page}")
    print(f"kernel          {ksz} bytes @ {kaddr:#x}")
    print(f"ramdisk         {rsz} bytes @ {raddr:#x}")
    print(f"second          {ssz} bytes @ {saddr:#x}    tags/dtb @ {tags:#x}")
    print(f"cmdline         {cmdline!r}")
    if extra:
        print(f"extra_cmdline   {extra!r}")

    for key, val in (("kernel_addr", kaddr), ("ramdisk_addr", raddr), ("second_addr", saddr),
                     ("tags_addr", tags), ("page_size", page)):
        if val != STOCK[key]:
            warnings.append(f"{key} = {val:#x}, stock is {STOCK[key]:#x}")
    if hver != 0:
        warnings.append(f"header_version {hver}; stock LK image is v0")
    if "bootopt=64S3" not in cmdline:
        problems.append("cmdline lacks 'bootopt=64S3,32N2,64N2' -> LK would boot the kernel as 32-bit")

    kernel = data[page:page + ksz]
    if len(kernel) >= 4 and struct.unpack_from("<I", kernel, 0)[0] == 0x58881688:
        problems.append("kernel has a 512-byte MediaTek header; the stock P027 kernel has none")
        kernel = kernel[512:]

    if kernel[:2] == b"\x1f\x8b":
        dec = zlib.decompressobj(16 + zlib.MAX_WBITS)
        try:
            image = dec.decompress(kernel)
        except zlib.error as exc:
            sys.exit(f"FAIL: gzip kernel does not decompress: {exc}")
        tail = dec.unused_data
        print(f"kernel format   gzip -> {len(image)} bytes Image, {len(tail)} bytes after the gzip stream")
    else:
        problems.append("kernel is not gzip; stock format is Image.gz with a DTB appended")
        image, tail = kernel, b""

    if image[0x38:0x3C] == b"ARM\x64":
        text_offset, image_size, flags = struct.unpack_from("<QQQ", image, 8)
        end = kaddr + image_size
        print(f"arm64 Image     text_offset={text_offset:#x} image_size={image_size:#x} flags={flags:#x} "
              f"-> occupies {kaddr:#x}..{end:#x}")
        if end > raddr:
            problems.append(f"kernel image_size ends at {end:#x}, past the ramdisk at {raddr:#x}")
    else:
        problems.append("payload is not an arm64 Image (no ARM\\x64 magic at 0x38)")
    ver = image.find(b"Linux version ")
    if ver >= 0:
        print("version         " + image[ver:ver + 160].split(b"\n")[0].decode(errors="replace"))

    dtbs, leftover = split_dtbs(tail)
    print(f"appended DTBs   {len(dtbs)} ({', '.join(str(len(b)) + ' B' for b in dtbs) or 'none'})")
    if len(dtbs) != 1:
        problems.append(f"expected exactly 1 appended DTB, found {len(dtbs)}")
    if leftover:
        warnings.append(f"{leftover} unexplained bytes after the appended DTB(s)")
    if outdir and dtbs:
        os.makedirs(outdir, exist_ok=True)
        for n, blob in enumerate(dtbs, 1):
            with open(os.path.join(outdir, f"dtb{n}.dtb"), "wb") as fh:
                fh.write(blob)
        print(f"wrote DTBs to   {outdir}")

    rd = data[page + ((ksz + page - 1) // page) * page:][:rsz]
    kind = {b"\x1f\x8b": "gzip", b"07": "cpio", b"\x02\x21": "lz4-legacy"}.get(rd[:2], rd[:4].hex())
    print(f"ramdisk format  {kind}")

    if len(data) > PARTITION_SIZE:
        warnings.append(f"image is {len(data)} bytes > 16 MiB: fine for 'fastboot boot', too big for boot/recovery")

    for w in warnings:
        print("WARN  " + w)
    for p in problems:
        print("FAIL  " + p)
    print("RESULT  " + ("OK for P027 LK" if not problems else f"{len(problems)} problem(s)"))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
