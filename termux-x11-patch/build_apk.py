#!/usr/bin/env python3
"""Rebuild a Termux:X11 APK with a patched classes.dex and sign it (JAR / v1 signature).

Android 7 accepts v1 signatures. Native libs (.so) stay STORED and 4096-aligned,
because the termux-x11 server System.load()s libXlorie.so straight out of the APK.

usage: build_apk.py ORIGINAL.apk PATCHED_DEX_DIR OUT.apk KEY.pem CERT.pem
"""
import base64, hashlib, io, os, subprocess, sys, tempfile, zipfile

orig, dexdir, out, key, cert = sys.argv[1:6]
src = zipfile.ZipFile(orig)

entries = []  # (name, data, compress_type)
for zi in src.infolist():
    n = zi.filename
    if n.startswith('META-INF/') and n.rsplit('.', 1)[-1] in ('SF', 'RSA', 'DSA', 'EC', 'MF'):
        continue  # drop any old signature
    data = src.read(n)
    if n.endswith('.dex') and '/' not in n and os.path.exists(os.path.join(dexdir, n)):
        data = open(os.path.join(dexdir, n), 'rb').read()
        print('patched', n)
    entries.append((n, data, zi.compress_type))

# --- v1 signature files
def b64(d): return base64.b64encode(hashlib.sha256(d).digest()).decode()
mf = ['Manifest-Version: 1.0', 'Created-By: zenpad-patch', '']
sections = {}
for n, d, _ in entries:
    sec = f'Name: {n}\r\nSHA-256-Digest: {b64(d)}\r\n\r\n'
    sections[n] = sec
manifest = ('\r\n'.join(mf)).encode() + ''.join(sections.values()).encode()
sf = (f'Signature-Version: 1.0\r\nCreated-By: zenpad-patch\r\n'
      f'SHA-256-Digest-Manifest: {b64(manifest)}\r\n\r\n')
sf += ''.join(f'Name: {n}\r\nSHA-256-Digest: {b64(s.encode())}\r\n\r\n' for n, s in sections.items())
sf = sf.encode()
with tempfile.TemporaryDirectory() as t:
    open(f'{t}/CERT.SF', 'wb').write(sf)
    subprocess.run(['openssl', 'smime', '-sign', '-binary', '-noattr', '-md', 'sha256',
                    '-in', f'{t}/CERT.SF', '-signer', cert, '-inkey', key,
                    '-outform', 'DER', '-out', f'{t}/CERT.RSA'], check=True)
    rsa = open(f'{t}/CERT.RSA', 'rb').read()

# --- write zip with alignment
sig = [('META-INF/MANIFEST.MF', manifest, zipfile.ZIP_DEFLATED),
       ('META-INF/CERT.SF', sf, zipfile.ZIP_DEFLATED),
       ('META-INF/CERT.RSA', rsa, zipfile.ZIP_DEFLATED)]
with zipfile.ZipFile(out, 'w') as z:
    for n, d, ct in sig + entries:
        zi = zipfile.ZipInfo(n, date_time=(1981, 1, 1, 1, 1, 0))
        zi.compress_type = ct
        zi.create_system = 0
        zi.external_attr = 0
        if ct == zipfile.ZIP_STORED:
            align = 4096 if n.endswith('.so') else 4
            off = z.fp.tell() + 30 + len(n.encode())
            pad = (-off) % align
            if pad and pad < 6:
                pad += align
            if pad:
                # extra block id 0xd935 (Android zipalign), payload = alignment + zeros
                zi.extra = (0xd935).to_bytes(2, 'little') + (pad - 4).to_bytes(2, 'little') + \
                    align.to_bytes(2, 'little') + b'\0' * (pad - 6)
        z.writestr(zi, d)

# verify alignment
with zipfile.ZipFile(out) as z:
    with open(out, 'rb') as f:
        for zi in z.infolist():
            if zi.compress_type == zipfile.ZIP_STORED and zi.filename.endswith('.so'):
                f.seek(zi.header_offset + 26)
                nl = int.from_bytes(f.read(2), 'little'); el = int.from_bytes(f.read(2), 'little')
                off = zi.header_offset + 30 + nl + el
                assert off % 4096 == 0, (zi.filename, off)
print('wrote', out)
