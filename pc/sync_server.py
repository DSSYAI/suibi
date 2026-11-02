# -*- coding: utf-8 -*-
"""
随笔 · 电脑端同步接收器

双击「随笔同步.cmd」运行。手机上填窗口里显示的地址和口令，点"立即同步"，
这个窗口里就会提示收到了几条，并把它们写成 md 文件。

- 同步是单向的：手机 → 电脑。电脑上改的东西不会回传。
- 闲着一段时间（默认 3 分钟）会自己关掉，不用记得来关。
- 只用标准库，不需要装任何东西。
"""

import argparse
import json
import os
import re
import socket
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

APP = "suibi"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_OUT = os.path.join(os.path.expanduser("~"), "随笔")
LAST_SEEN = time.time()


def resolve_out_dir(cli_dir=None):
    """输出目录：命令行 > pc/config.txt > 家目录下的「随笔」。"""
    if cli_dir:
        return cli_dir
    cfg = os.path.join(BASE_DIR, "config.txt")
    if os.path.exists(cfg):
        try:
            with open(cfg, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#"):
                        return line
        except OSError:
            pass
    return DEFAULT_OUT


def load_token():
    path = os.path.join(BASE_DIR, "token.txt")
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                t = f.read().strip()
            if t:
                return t
        except OSError:
            pass
    t = "".join(__import__("random").choice("0123456789") for _ in range(6))
    with open(path, "w", encoding="utf-8") as f:
        f.write(t)
    return t


def title_of(body: str) -> str:
    for line in body.split("\n"):
        t = line.strip()
        if not t:
            continue
        t = re.sub(r"^#{1,6}\s*", "", t)
        t = re.sub(r"^(\s*([-*+>]|\d+[.)])\s+)+", "", t)
        t = re.sub(r"(\*\*|__|`|~~)", "", t).strip()
        if t:
            return t
    return "无题"


def safe_name(s: str, limit: int = 40) -> str:
    s = re.sub(r'[\\/:*?"<>|\r\n\t]', "_", s).strip().strip(".")
    s = re.sub(r"\s+", " ", s)
    s = s.rstrip("。．.,，、;；:：!！?？·…~～-—_ ")
    if len(s) > limit:
        s = s[:limit]
    return s or "无题"


def local_ipv4():
    """只报真正的局域网地址，跳过代理的 TUN 地址（198.18.x.x）和自动私有地址。"""
    skip_prefix = ("198.18.", "198.19.", "127.", "169.254.", "0.")
    ips = []

    def ok(ip):
        if any(ip.startswith(p) for p in skip_prefix):
            return False
        return (
            ip.startswith("192.168.")
            or ip.startswith("10.")
            or any(ip.startswith(f"172.{n}.") for n in range(16, 32))
        )

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("223.5.5.5", 80))
            ip = s.getsockname()[0]
            if ok(ip):
                ips.append(ip)
    except OSError:
        pass
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ip = info[4][0]
            if ok(ip) and ip not in ips:
                ips.append(ip)
    except OSError:
        pass
    return ips


class Handler(BaseHTTPRequestHandler):
    out_dir = DEFAULT_OUT
    token = ""
    idle_seconds = 180

    def log_message(self, fmt, *args):
        pass

    def _send(self, code, obj):
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        global LAST_SEEN
        LAST_SEEN = time.time()
        path = self.path.split("?")[0]
        if path == "/ping":
            self._send(200, {"app": APP, "ok": True, "version": 1})
        elif path == "/":
            self._send_html(200, self._home_page())
        else:
            self._send(404, {"error": "not found"})

    def _home_page(self):
        ips = "".join(f"<p class='addr'>http://{ip}:{self.server.server_address[1]}</p>" for ip in local_ipv4())
        return f"""<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>随笔 · 同步</title>
<style>
 body{{margin:0;background:#FAF7F2;color:#17140F;
      font-family:"Noto Serif SC","Songti SC",serif;line-height:1.9}}
 .wrap{{max-width:520px;margin:12vh auto;padding:0 26px}}
 h1{{font-size:22px;font-weight:700;letter-spacing:4px;margin:0 0 6px}}
 .sub{{color:#5C544A;font-size:13px;margin:0 0 26px}}
 .box{{border:1px solid #E7E0D5;border-radius:10px;padding:18px 20px}}
 .k{{color:#A1978A;font-size:12px;letter-spacing:2px;margin:14px 0 2px}}
 .addr{{margin:0;font-size:16px}}
 .token{{font-size:24px;letter-spacing:6px;margin:0}}
 .ok{{color:#8C6E4A;font-size:13px;margin-top:22px}}
 .foot{{color:#A1978A;font-size:12px;margin-top:28px}}
</style></head><body><div class="wrap">
<h1>随笔 · 同步</h1>
<p class="sub">这个窗口开着的时候，手机才能连上来。</p>
<div class="box">
 <p class="k">地址</p>{ips}
 <p class="k">口令</p><p class="token">{self.token}</p>
 <p class="k">存到</p><p class="addr">{self.out_dir}</p>
</div>
<p class="ok">在手机 App 里：右上角云朵 → 填上面的地址和口令 → 立即同步。</p>
<p class="foot">空闲 {self.idle_seconds} 秒没人来，这个程序会自己关。</p>
</div></body></html>"""

    def _send_html(self, code, html):
        data = html.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        global LAST_SEEN
        LAST_SEEN = time.time()
        if self.path.split("?")[0] != "/sync":
            self._send(404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length)
            payload = json.loads(raw.decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            self._send(400, {"ok": False, "error": f"请求读不懂：{e}"})
            return

        if str(payload.get("token", "")) != self.token:
            self._send(401, {"ok": False, "error": "口令不对"})
            return

        notes = payload.get("notes")
        if not isinstance(notes, list):
            self._send(400, {"ok": False, "error": "notes 不是列表"})
            return

        os.makedirs(self.out_dir, exist_ok=True)
        state_path = os.path.join(BASE_DIR, ".state.json")
        state = {}
        if os.path.exists(state_path):
            try:
                with open(state_path, encoding="utf-8") as f:
                    state = json.load(f)
            except Exception:  # noqa: BLE001
                state = {}

        new_state = {}
        written = 0
        renamed = 0
        used_names = set()

        for note in notes:
            if not isinstance(note, dict):
                continue
            nid = str(note.get("id") or "")
            body = str(note.get("body") or "")
            if not nid:
                continue
            try:
                ms = int(note.get("updated") or 0)
            except (TypeError, ValueError):
                ms = 0
            day = time.strftime("%Y-%m-%d", time.localtime(ms / 1000)) if ms else time.strftime("%Y-%m-%d")
            name = f"{day} {safe_name(title_of(body))}.md"
            if name in used_names:
                name = f"{day} {safe_name(title_of(body))}-{nid[:6]}.md"
            used_names.add(name)
            new_state[nid] = name

            old_name = state.get(nid)
            if old_name and old_name != name:
                old_path = os.path.join(self.out_dir, old_name)
                if os.path.exists(old_path):
                    try:
                        os.remove(old_path)
                        renamed += 1
                    except OSError:
                        pass

            path = os.path.join(self.out_dir, name)
            text = body.replace("\r\n", "\n")
            if not text.endswith("\n"):
                text += "\n"
            with open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
            written += 1

        # 手机上删掉的笔记，电脑上不删 —— 电脑这份当存档。
        removed = 0

        with open(state_path, "w", encoding="utf-8") as f:
            json.dump(new_state, f, ensure_ascii=False, indent=1)

        print(f"  → 收到 {written} 条" + (f"，改名 {renamed} 个文件" if renamed else ""))
        self._send(200, {"ok": True, "written": written, "removed": removed})


def watch_addresses(server):
    """网络变了（换 WiFi、开 USB 共享）就把新地址打出来。"""
    last = tuple(local_ipv4())
    while True:
        time.sleep(5)
        cur = tuple(local_ipv4())
        if cur != last:
            last = cur
            print()
            for ip in cur:
                print(f"  地址变了：http://{ip}:{server.server_address[1]}")
            print()


def watch_idle(server, seconds):
    while seconds > 0:
        time.sleep(5)
        if time.time() - LAST_SEEN > seconds:
            print(f"\n  静了 {seconds} 秒，自己关了。下次再双击就行。")
            try:
                server.shutdown()
            except Exception:  # noqa: BLE001
                pass
            return


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8730)
    ap.add_argument("--dir", default=None)
    ap.add_argument("--idle", type=int, default=900)
    args = ap.parse_args()

    if sys.platform == "win32":
        try:
            sys.stdout.reconfigure(encoding="utf-8")
        except Exception:  # noqa: BLE001
            pass

    token = load_token()
    out_dir = resolve_out_dir(args.dir)
    Handler.out_dir = out_dir
    Handler.token = token
    Handler.idle_seconds = args.idle

    server = None
    port = args.port
    for p in range(args.port, args.port + 11):
        try:
            server = ThreadingHTTPServer(("0.0.0.0", p), Handler)
            port = p
            break
        except OSError:
            continue
    if server is None:
        print("端口都被占了，开不起来。看看是不是已经有一个在跑。")
        input("按回车关掉…")
        return

    global LAST_SEEN
    LAST_SEEN = time.time()

    print()
    print("  随笔 · 同步接收器")
    print("  " + "-" * 36)
    for ip in local_ipv4():
        print(f"  地址：http://{ip}:{port}")
    print(f"  口令：{token}")
    print(f"  存到：{out_dir}")
    print("  " + "-" * 36)
    print("  手机：点右上角云朵 → 填地址和口令 → 立即同步")
    print("  窗口要一直开着，关掉就断了。")
    print(f"  没人来 {max(1, args.idle // 60)} 分钟会自己关。")
    print()

    if args.idle > 0:
        threading.Thread(target=watch_idle, args=(server, args.idle), daemon=True).start()
    threading.Thread(target=watch_addresses, args=(server,), daemon=True).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
