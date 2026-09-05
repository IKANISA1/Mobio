#!/usr/bin/env python3
"""Build a local review gallery from synthetic Flutter baselines and web captures."""
import argparse
import html
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=ROOT / 'output/revolut-followup-20260905/gallery')
parser.add_argument('--website-mobile', type=Path)
parser.add_argument('--website-desktop', type=Path)
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
source = ROOT / 'test/features/preview/goldens/revolut'
priority = ['splash_390x844', 'light/splash_390x844', 'login_390x844', 'whatsapp_number_ready_390x844', 'whatsapp_sending_390x844', 'whatsapp_otp_390x844', 'whatsapp_otp_invalid_390x844', 'whatsapp_otp_expired_390x844', 'whatsapp_verifying_390x844', 'whatsapp_rate_limited_390x844', 'whatsapp_resend_ready_390x844', 'whatsapp_send_error_390x844', 'home_shell_390x844', 'biopay_home_shell_390x844', 'bookings_shell_390x844', 'profile_shell_390x844', 'wallet_390x844', 'mobio_plus_390x844']

def order(path):
    name = str(path.relative_to(source).with_suffix(''))
    return (priority.index(name) if name in priority else len(priority), name)

def title_for(path):
    name = path.stem.replace('_390x844', '').replace('_430x932', '')
    name = name.replace('whatsapp_', 'WhatsApp · ').replace('login', 'WhatsApp login')
    name = name.replace('biopay', 'BioPay').replace('otp', 'OTP').replace('_', ' ')
    return name[:1].upper() + name[1:]

cards = []
for path in sorted(source.rglob('*.png'), key=order):
    relative = path.relative_to(source)
    target = args.output / 'screens' / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)
    onboarding = path.stem.startswith(('splash', 'login', 'whatsapp'))
    group = 'Onboarding' if onboarding else 'Admin' if path.stem.startswith('admin') else 'App'
    if 'light' in relative.parts:
        group = 'Light'
    label = title_for(path)
    state = f'{group} · {path.stem.rsplit("_", 1)[-1]}'
    href = html.escape('screens/' + relative.as_posix())
    cards.append(f'<a class="card" data-group="{group}" data-name="{html.escape(label)}" href="{href}" target="_blank"><img loading="lazy" src="{href}" alt="{html.escape(label)}"><h2>{html.escape(label)}</h2><p>{state}</p></a>')
native_count = len(cards)
for label, path in [('Website mobile', args.website_mobile), ('Website desktop', args.website_desktop)]:
    if path:
        target = args.output / (label.replace(' ', '-').lower() + path.suffix)
        shutil.copyfile(path, target)
        cards.append(f'<a class="card" data-group="Website" data-name="{label}" href="{target.name}" target="_blank"><img loading="lazy" src="{target.name}" alt="{label}"><h2>{label}</h2><p>Browser capture</p></a>')
page = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Mobio — Splash, login and colour review</title><style>
*{box-sizing:border-box}body{margin:0;background:#080809;color:#f4f4f4;font:16px/1.5 system-ui,sans-serif;padding:clamp(16px,3vw,48px)}header{max-width:1100px;margin:auto}h1{font-size:clamp(32px,5vw,64px);line-height:1.05;letter-spacing:-.04em;margin:16px 0}p{color:#b9b9bf}a{color:#9bbcff}.palettes,.links{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}.palettes span{padding:10px 18px;border-radius:99px;color:white}label{display:inline-flex;gap:8px;align-items:center;flex-wrap:wrap;margin:8px 12px 8px 0}input,select{font:inherit;padding:12px;border:1px solid #717173;border-radius:12px;background:#161618;color:white;max-width:100%}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr));gap:24px;margin-top:24px}.card{display:block;padding:12px;background:#161618;border-radius:20px;text-decoration:none;color:white;min-width:0}.card img{width:100%;height:560px;object-fit:contain;object-position:top;display:block}.card h2{font-size:17px;margin:12px 0 4px}.card p{font-size:13px;margin:0}.card[hidden]{display:none}:focus-visible{outline:3px solid #6fa0ff;outline-offset:4px}.links a{padding:8px 0}small{display:block;color:#b9b9bf}
</style></head><body><header><small>MOBIO · DESIGN REVIEW · 5 SEPTEMBER 2026</small><h1>Splash. Sign in.<br>Six colour families.</h1><p>The missing first steps are now included: light and dark launch, WhatsApp number entry, code verification, loading, errors and retry. Browse the app, website and admin below.</p><div class="palettes"><span style="background:#182be2">Home · blue</span><span style="background:#125063">BioPay · teal</span><span style="background:#673cdc">Trips · purple</span><span style="background:#405093">Wallet · slate</span><span style="background:#7351f3">Profile · violet</span><span style="background:#374c8d">Login · indigo</span></div><div class="links"><a href="http://127.0.0.1:62044/?screen=login" target="_blank">Try code entry (simulation)</a><a href="http://127.0.0.1:62221/" target="_blank">Local website</a><a href="http://127.0.0.1:62221/admin-auth" target="_blank">Local admin sign-in</a></div><small>__NATIVE_COUNT__ synthetic Flutter renders and current website captures. The simulation sends no messages and creates no session. Light washes are target adaptations. These views do not certify source pixel parity or provider completion.</small><label>Find a screen <input id="search" type="search" placeholder="Splash, WhatsApp, QR…"></label><label>Surface <select id="group"><option>All</option><option>Onboarding</option><option>App</option><option>Admin</option><option>Light</option><option>Website</option></select></label><p id="count" role="status"></p></header><main>'''
page = page.replace('__NATIVE_COUNT__', str(native_count))
page += ''.join(cards)
page += '''</main><script>const q=document.querySelector('#search'),g=document.querySelector('#group');function filter(){let n=0;document.querySelectorAll('.card').forEach(c=>{c.hidden=!(c.dataset.name.toLowerCase().includes(q.value.toLowerCase())&&(g.value==='All'||c.dataset.group===g.value));if(!c.hidden)n++});document.querySelector('#count').textContent=n+' screens shown'}q.addEventListener('input',filter);g.addEventListener('change',filter);filter()</script></body></html>'''
(args.output / 'index.html').write_text(page)
print(f'Wrote {len(cards)} screens to {args.output / "index.html"}')
