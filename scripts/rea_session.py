"""A local JSON-lines MCP client retaining complete REA replies on disk."""
import json
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "analysis/evidence"
NODE = "/Users/pengyuehui/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node"
environment = dict(os.environ)
environment.update({
    "REA_JADX_MCP_JAR": str(ROOT / "tools/android/jadx-headless-mcp-0.7.1-all.jar"),
    "JAVA_HOME": "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home",
    "REA_JADX_HEAP_MIB": "4096",
    "REA_JADX_OPERATION_TIMEOUT_MS": "180000",
})
log = (OUT / "rea-server.log").open("a")
process = subprocess.Popen([NODE, str(ROOT / "tools/rea/node_modules/rea-agents/scripts/rea.mjs"), "mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=log, text=True, env=environment)
messages = queue.Queue()

def read_messages():
    for line in process.stdout:
        try:
            messages.put(json.loads(line))
        except json.JSONDecodeError:
            log.write(line)
    messages.put({"closed": True})

threading.Thread(target=read_messages, daemon=True).start()
counter = 0

def rpc(method, params):
    global counter
    counter += 1
    request_id = counter
    process.stdin.write(json.dumps({"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}) + "\n")
    process.stdin.flush()
    while True:
        reply = messages.get(timeout=240)
        if reply.get("closed"):
            raise RuntimeError("REA server closed; inspect rea-server.log")
        if reply.get("id") == request_id:
            if "error" in reply:
                raise RuntimeError(reply["error"])
            return reply["result"]

def save(name, value):
    if not name.replace("-", "").replace("_", "").isalnum():
        raise ValueError("Invalid evidence filename")
    (OUT / f"{name}.json").write_text(json.dumps(value, ensure_ascii=False, indent=2))

try:
    init = rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "leanora-local-analysis", "version": "1.0"}})
    save("rea-initialize", init)
    process.stdin.write(json.dumps({"jsonrpc": "2.0", "method": "notifications/initialized"}) + "\n")
    process.stdin.flush()
    catalog = rpc("tools/list", {})
    save("rea-tool-catalog", catalog)
    print(json.dumps({"ready": init.get("serverInfo"), "tools": len(catalog.get("tools", []))}), flush=True)
    for line in sys.stdin:
        if line.strip() == "quit":
            break
        try:
            job = json.loads(line)
            result = rpc("tools/call", {"name": job["name"], "arguments": job.get("arguments", {})})
            save(job["save"], result)
            summary = result.get("structuredContent", result)
            print(json.dumps({"saved": job["save"], "isError": result.get("isError"), "preview": json.dumps(summary, ensure_ascii=False)[:4500]}, ensure_ascii=False), flush=True)
        except Exception as error:
            print(json.dumps({"error": str(error)}), flush=True)
finally:
    process.stdin.close()
    try:
        process.wait(timeout=20)
    except subprocess.TimeoutExpired:
        process.terminate()
        process.wait(timeout=10)
    log.close()
