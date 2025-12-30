#!/usr/bin/env python3
"""Deploy wintv-config to Windows via WinRM"""

import winrm
import base64
import os
import sys

HOST = "wintv.lorikeet-crested.ts.net"
USER = "user"
PASSWORD = "user"
RESULT_DIR = "/home/user/Documents/dotfiles/result"
REMOTE_DIR = "C:\\ProgramData\\wintv"

FILES = [
    ("deploy.ps1", "deploy.ps1"),
    ("docker-compose.yml", "docker-compose.yml"),
    ("configuration.dsc.yaml", "configuration.dsc.yaml"),
    ("kanidm-server.toml", "kanidm-server.toml"),
    ("README.txt", "README.txt"),
    ("lib/appliance.ps1", "lib\\appliance.ps1"),
    ("lib/kodi.ps1", "lib\\kodi.ps1"),
]

def copy_file_chunked(session, local_path, remote_path, chunk_size=4000):
    """Copy file in chunks to avoid command line length limits"""
    with open(local_path, "rb") as f:
        content = f.read()

    b64 = base64.b64encode(content).decode()
    temp_path = remote_path + ".b64"

    # Clear/create the temp file first
    session.run_ps(f'Set-Content -Path "{temp_path}" -Value "" -NoNewline')

    # Write in chunks
    total_chunks = (len(b64) + chunk_size - 1) // chunk_size
    for idx, i in enumerate(range(0, len(b64), chunk_size)):
        chunk = b64[i:i+chunk_size]
        ps_cmd = f'Add-Content -Path "{temp_path}" -Value "{chunk}" -NoNewline'
        result = session.run_ps(ps_cmd)
        if result.status_code != 0:
            print(f"  Chunk error: {result.std_err.decode()}")
            return False
        if total_chunks > 5:
            print(f"\r  [{idx+1}/{total_chunks}]", end="", flush=True)
    if total_chunks > 5:
        print(" ", end="")

    # Decode base64 on remote
    ps_decode = f'''
$b64 = Get-Content -Path "{temp_path}" -Raw
$bytes = [Convert]::FromBase64String($b64)
[IO.File]::WriteAllBytes("{remote_path}", $bytes)
Remove-Item -Path "{temp_path}" -Force
'''
    result = session.run_ps(ps_decode)
    return result.status_code == 0

def main():
    print(f"Connecting to {HOST}...")
    session = winrm.Session(HOST, auth=(USER, PASSWORD), transport="ntlm")

    # Test connection
    result = session.run_cmd("hostname")
    if result.status_code != 0:
        print(f"Connection failed: {result.std_err.decode()}")
        sys.exit(1)
    print(f"Connected to: {result.std_out.decode().strip()}")

    # Create target directories
    print("Creating directories...")
    session.run_ps(f'New-Item -ItemType Directory -Path "{REMOTE_DIR}\\lib" -Force | Out-Null')

    # Copy files
    for local_name, remote_name in FILES:
        local_path = os.path.join(RESULT_DIR, local_name)
        remote_path = f"{REMOTE_DIR}\\{remote_name}"
        print(f"Copying {local_name}...", end=" ", flush=True)
        if copy_file_chunked(session, local_path, remote_path):
            print("OK")
        else:
            print("FAILED")
            sys.exit(1)

    print("\nRunning deploy.ps1...")
    print("=" * 60)
    result = session.run_ps(f'Set-Location "{REMOTE_DIR}"; .\\deploy.ps1', codepage=65001)
    print(result.std_out.decode("utf-8", errors="replace"))
    if result.std_err:
        print("STDERR:", result.std_err.decode("utf-8", errors="replace"))
    print("=" * 60)
    print(f"Exit code: {result.status_code}")
    sys.exit(result.status_code)

if __name__ == "__main__":
    main()
