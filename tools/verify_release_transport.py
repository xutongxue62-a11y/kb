"""Verify real signed HTTPS downloads and next-launch pack mounting in an isolated profile."""
from pathlib import Path
from datetime import datetime
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import ssl
import subprocess
import threading

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT.parent / '原始人大作战_发行准备/v0.23.0'
TEST = WORK / ('transport_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
ENGINE = ROOT / 'tools/godot/Godot_v4.7.2-stable_win64_console.exe'
EXE = ROOT.parent / '原始人大作战_发行版/v0.23.0/Windows/PrimitiveWildfrontier.exe'
KEY = WORK.parent / 'private_keys/update_private.pem'
TEST.mkdir()
env = os.environ.copy()
env['APPDATA'] = str(TEST / 'appdata')
env['LOCALAPPDATA'] = str(TEST / 'appdata/local')
env['RELEASE_TRANSPORT_FIXTURES'] = str(TEST)

def run(args, log_name, cwd=ROOT):
    result = subprocess.run(args, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    (TEST / log_name).write_bytes(result.stdout)
    output = result.stdout.decode('utf-8', errors='replace')
    if result.returncode:
        raise RuntimeError(f'{log_name}: exit={result.returncode}\n' + output[-3500:])
    return output

requests_seen = []
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        requests_seen.append(args[0] if args else format)

server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Handler, directory=str(TEST)))
port = server.server_port
run([str(ENGINE), '--headless', '--path', str(ROOT), '--script',
     'res://tools/release_transport_fixtures.gd', '--', str(TEST), str(port), str(KEY)], 'fixtures.log')
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain(str(TEST / 'tls.crt'), str(TEST / 'tls.key'))
server.socket = context.wrap_socket(server.socket, server_side=True)
thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
try:
    output = run([str(ENGINE), '--headless', '--path', str(ROOT), '--script',
                  'res://tests/test_release_transport.gd'], 'transport.log')
    assert '0 failures' in output and 'FAIL:' not in output and 'ERROR:' not in output, output[-3500:]
    mounted = run([str(EXE), '--headless', '--',
                   '--verify-release=' + str(TEST / 'next_start')], 'next_start.log', EXE.parent)
    assert 'CONTENT_PATCH_EXECUTED' in mounted, mounted[-3500:]
    smoke = json.loads((TEST / 'next_start/smoke.json').read_text('utf-8'))
    assert smoke['cached'] and smoke['build'] == 2026111602 and smoke['game_ready']
    assert smoke['updater_requests'] == 0 and not smoke['real_player_storage_used']
    assert not any(text in mounted for text in ['ERROR:', 'SCRIPT ERROR', 'Parse Error']), mounted[-3500:]
    report = {'fixture_root': str(TEST), 'https_download_test': 'passed',
              'next_start_loaded_verified_patch': True, 'smoke': smoke,
              'requests': requests_seen, 'real_player_storage_used': False}
    (WORK / 'transport_verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(output.strip().splitlines()[-1])
    print('Verified real HTTPS download, signature/hash checks, and patched game execution on next launch.')
finally:
    (TEST / 'requests.json').write_text(json.dumps(requests_seen), encoding='utf-8')
    server.shutdown(); server.server_close(); thread.join(timeout=3)
