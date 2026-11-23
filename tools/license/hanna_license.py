#!/usr/bin/env python3
"""Hanna Bakery POS — license key generator (Python version; Node wala hanna_license.js bhi same key banata hai).

    pip install cryptography
    python hanna_license.py issue --device HB7K-2M9Q-X4TZ --shop "Ali Bakers" --days 365
    python hanna_license.py issue --device HB7K-2M9Q-X4TZ --shop "Ali Bakers" --lifetime
    python hanna_license.py genkey            # sirf pehli dafa (naya key pair)

Private key file kabhi customer / GitHub par na jaye.
"""
import argparse, base64, csv, datetime, json, os, re, sys

PREFIX = 'HBK1'


def b64url(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode().rstrip('=')


def main():
    try:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        from cryptography.hazmat.primitives import serialization
    except ImportError:
        sys.exit('pip install cryptography')
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest='cmd', required=True)
    g = sub.add_parser('genkey'); g.add_argument('--out', default='hanna_bakery_license_private.key')
    i = sub.add_parser('issue')
    i.add_argument('--device', required=True); i.add_argument('--shop', default='')
    i.add_argument('--plan', default='pro'); i.add_argument('--key', default='hanna_bakery_license_private.key')
    m = i.add_mutually_exclusive_group()
    m.add_argument('--days', type=int); m.add_argument('--until'); m.add_argument('--lifetime', action='store_true')
    a = ap.parse_args()

    if a.cmd == 'genkey':
        if os.path.exists(a.out):
            sys.exit(f'{a.out} pehle se maujood hai — purani key mat mitayein.')
        k = Ed25519PrivateKey.generate()
        raw = k.private_bytes(serialization.Encoding.Raw, serialization.PrivateFormat.Raw, serialization.NoEncryption())
        pub = k.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)
        with open(a.out, 'w') as f:
            f.write(base64.b64encode(raw).decode() + '\n')
        print('Private key:', a.out, '(MEHFOOZ rakhein)')
        print('Public key (license_keys.dart):', base64.b64encode(pub).decode())
        return

    dev = re.sub(r'[^A-Z0-9]', '', a.device.upper())
    if len(dev) != 12:
        sys.exit('Device ID 12 harf ka hota hai (jaise HB7K-2M9Q-X4TZ)')
    today = datetime.date.today()
    if a.lifetime:
        expiry = ''
    elif a.until:
        datetime.date.fromisoformat(a.until); expiry = a.until
    else:
        expiry = (today + datetime.timedelta(days=a.days or 365)).isoformat()
    payload = {'v': 1, 'd': f'{dev[:4]}-{dev[4:8]}-{dev[8:]}', 's': a.shop, 'p': a.plan, 'i': today.isoformat(), 'e': expiry}
    body = PREFIX + '.' + b64url(json.dumps(payload, separators=(',', ':'), ensure_ascii=False).encode('utf-8'))
    raw = base64.b64decode(open(a.key).read().strip())
    sig = Ed25519PrivateKey.from_private_bytes(raw).sign(body.encode('ascii'))
    lic = body + '.' + b64url(sig)
    log = os.path.join(os.path.dirname(os.path.abspath(a.key)), 'licenses_issued.csv')
    new = not os.path.exists(log)
    with open(log, 'a', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        if new: w.writerow(['issued', 'device', 'shop', 'plan', 'expiry', 'license'])
        w.writerow([payload['i'], payload['d'], payload['s'], payload['p'], expiry or 'lifetime', lic])
    print('Device :', payload['d']); print('Shop   :', payload['s']); print('Expiry :', expiry or 'LIFETIME')
    print('\nLICENSE KEY (customer ko bhejein):\n' + lic)


if __name__ == '__main__':
    main()
