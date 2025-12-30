#!/usr/bin/env python3
"""
Travel Router Web UI

Provides GL.iNet-style management:
- WiFi client: scan/connect to upstream networks
- WiFi AP: configure hotspot SSID/password
- VPN client: WireGuard connection
- Clients: list connected devices
"""

import subprocess
import json
import os
import re
from flask import Flask, render_template_string, jsonify, request

app = Flask(__name__)

TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
  <title>Travel Router</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #1a1a2e; color: #eee; padding: 20px;
    }
    .container { max-width: 800px; margin: 0 auto; }
    h1 { color: #00d4ff; margin-bottom: 20px; }
    .card {
      background: #16213e; border-radius: 12px; padding: 20px;
      margin-bottom: 20px; border: 1px solid #0f3460;
    }
    .card h2 { color: #00d4ff; font-size: 1.1em; margin-bottom: 15px; }
    .status { display: flex; align-items: center; gap: 10px; margin: 10px 0; }
    .status-dot { width: 12px; height: 12px; border-radius: 50%; }
    .status-dot.connected { background: #00ff88; }
    .status-dot.disconnected { background: #ff4444; }
    .btn {
      background: #0f3460; border: none; color: #fff; padding: 10px 20px;
      border-radius: 8px; cursor: pointer; margin: 5px;
    }
    .btn:hover { background: #00d4ff; color: #000; }
    .btn-danger { background: #ff4444; }
    .network-list { max-height: 200px; overflow-y: auto; }
    .network-item {
      display: flex; justify-content: space-between; align-items: center;
      padding: 10px; border-bottom: 1px solid #0f3460;
    }
    .network-item:hover { background: #0f3460; }
    .signal { color: #00d4ff; }
    input, select {
      background: #0f3460; border: 1px solid #00d4ff; color: #fff;
      padding: 10px; border-radius: 8px; width: 100%; margin: 5px 0;
    }
    .client-list { font-family: monospace; font-size: 0.9em; }
    .client-item { padding: 8px 0; border-bottom: 1px solid #0f3460; }
    .tabs { display: flex; gap: 10px; margin-bottom: 20px; flex-wrap: wrap; }
    .tab {
      padding: 10px 20px; background: #0f3460; border-radius: 8px;
      cursor: pointer;
    }
    .tab.active { background: #00d4ff; color: #000; }
    .section { display: none; }
    .section.active { display: block; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Travel Router</h1>

    <div class="tabs">
      <div class="tab active" onclick="showSection('internet')">Internet</div>
      <div class="tab" onclick="showSection('hotspot')">Hotspot</div>
      <div class="tab" onclick="showSection('vpn')">VPN</div>
      <div class="tab" onclick="showSection('clients')">Clients</div>
      <div class="tab" onclick="showSection('system')">System</div>
    </div>

    <div id="internet" class="section active">
      <div class="card">
        <h2>Internet Connection</h2>
        <div class="status">
          <div class="status-dot" id="inet-status"></div>
          <span id="inet-text">Checking...</span>
        </div>
      </div>
      <div class="card">
        <h2>Available Networks</h2>
        <button class="btn" onclick="scanNetworks()">Scan</button>
        <div class="network-list" id="network-list">
          <p style="color:#888">Click scan to find networks</p>
        </div>
      </div>
    </div>

    <div id="hotspot" class="section">
      <div class="card">
        <h2>Hotspot Settings</h2>
        <div class="status">
          <div class="status-dot" id="ap-status"></div>
          <span id="ap-text">Checking...</span>
        </div>
        <input type="text" id="ap-ssid" placeholder="SSID" value="TravelRouter">
        <input type="password" id="ap-password" placeholder="Password (8+ chars)">
        <button class="btn" onclick="saveHotspot()">Save</button>
        <button class="btn" onclick="toggleHotspot()">Toggle</button>
      </div>
    </div>

    <div id="vpn" class="section">
      <div class="card">
        <h2>WireGuard VPN</h2>
        <div class="status">
          <div class="status-dot" id="vpn-status"></div>
          <span id="vpn-text">Checking...</span>
        </div>
        <textarea id="wg-config" rows="10"
          placeholder="Paste WireGuard config here..."
          style="width:100%; background:#0f3460; color:#fff; border:1px solid #00d4ff; border-radius:8px; padding:10px; font-family:monospace;"></textarea>
        <button class="btn" onclick="saveVPN()">Save Config</button>
        <button class="btn" onclick="toggleVPN()">Toggle</button>
      </div>
    </div>

    <div id="clients" class="section">
      <div class="card">
        <h2>Connected Clients</h2>
        <button class="btn" onclick="refreshClients()">Refresh</button>
        <div class="client-list" id="client-list">
          <p style="color:#888">Loading...</p>
        </div>
      </div>
    </div>

    <div id="system" class="section">
      <div class="card">
        <h2>System</h2>
        <p><strong>Uptime:</strong> <span id="uptime">Loading...</span></p>
        <br>
        <button class="btn btn-danger" onclick="reboot()">Reboot</button>
      </div>
    </div>
  </div>

  <script>
    function showSection(id) {
      document.querySelectorAll('.section').forEach(s => s.classList.remove('active'));
      document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
      document.getElementById(id).classList.add('active');
      event.target.classList.add('active');
    }

    async function api(endpoint, method='GET', data=null) {
      const opts = { method, headers: {'Content-Type': 'application/json'} };
      if (data) opts.body = JSON.stringify(data);
      const r = await fetch('/api/' + endpoint, opts);
      return r.json();
    }

    async function scanNetworks() {
      document.getElementById('network-list').innerHTML = '<p style="color:#888">Scanning...</p>';
      const data = await api('wifi/scan');
      let html = '';
      for (const net of data.networks || []) {
        html += '<div class="network-item">' +
          '<span>' + net.ssid + ' <span class="signal">(' + net.signal + '%)</span></span>' +
          '<button class="btn" onclick="connectWifi(\'' + net.ssid + '\')">Connect</button>' +
          '</div>';
      }
      document.getElementById('network-list').innerHTML = html || '<p>No networks found</p>';
    }

    async function connectWifi(ssid) {
      const pass = prompt('Password for ' + ssid + ':');
      if (pass !== null) {
        await api('wifi/connect', 'POST', {ssid, password: pass});
        alert('Connecting...');
        setTimeout(loadStatus, 3000);
      }
    }

    async function saveHotspot() {
      const ssid = document.getElementById('ap-ssid').value;
      const password = document.getElementById('ap-password').value;
      await api('hotspot/config', 'POST', {ssid, password});
      alert('Saved');
    }

    async function toggleHotspot() {
      await api('hotspot/toggle', 'POST');
      setTimeout(loadStatus, 2000);
    }

    async function saveVPN() {
      const config = document.getElementById('wg-config').value;
      await api('vpn/config', 'POST', {config});
      alert('VPN config saved');
    }

    async function toggleVPN() {
      await api('vpn/toggle', 'POST');
      setTimeout(loadStatus, 2000);
    }

    async function refreshClients() {
      const data = await api('clients');
      let html = '';
      for (const c of data.clients || []) {
        html += '<div class="client-item">' +
          c.ip + ' - ' + (c.hostname || 'Unknown') + ' (' + c.mac + ')' +
          '</div>';
      }
      document.getElementById('client-list').innerHTML = html || '<p>No clients</p>';
    }

    async function reboot() {
      if (confirm('Reboot?')) { await api('system/reboot', 'POST'); }
    }

    async function loadStatus() {
      try {
        const s = await api('status');
        const inetDot = document.getElementById('inet-status');
        const inetText = document.getElementById('inet-text');
        if (s.internet) {
          inetDot.className = 'status-dot connected';
          inetText.textContent = 'Connected via ' + (s.connection || 'Unknown');
        } else {
          inetDot.className = 'status-dot disconnected';
          inetText.textContent = 'Disconnected';
        }
        const apDot = document.getElementById('ap-status');
        const apText = document.getElementById('ap-text');
        if (s.hotspot_active) {
          apDot.className = 'status-dot connected';
          apText.textContent = 'Active';
        } else {
          apDot.className = 'status-dot disconnected';
          apText.textContent = 'Inactive';
        }
        const vpnDot = document.getElementById('vpn-status');
        const vpnText = document.getElementById('vpn-text');
        if (s.vpn_active) {
          vpnDot.className = 'status-dot connected';
          vpnText.textContent = 'Connected';
        } else {
          vpnDot.className = 'status-dot disconnected';
          vpnText.textContent = 'Disconnected';
        }
        document.getElementById('uptime').textContent = s.uptime || 'Unknown';
      } catch (e) { console.error(e); }
    }

    loadStatus();
    refreshClients();
    setInterval(loadStatus, 10000);
  </script>
</body>
</html>
"""


@app.route('/')
def index():
    return render_template_string(TEMPLATE)


@app.route('/api/status')
def status():
    result = {
        'internet': False, 'connection': None,
        'hotspot_active': False, 'vpn_active': False, 'uptime': 'unknown'
    }
    try:
        subprocess.run(['ping', '-c', '1', '-W', '2', '8.8.8.8'],
                      capture_output=True, check=True)
        result['internet'] = True
    except subprocess.CalledProcessError:
        pass  # Expected when offline
    except Exception as e:
        app.logger.warning(f"Internet check failed: {e}")
    try:
        r = subprocess.run(['nmcli', '-t', '-f', 'NAME,TYPE', 'con', 'show', '--active'],
                          capture_output=True, text=True)
        for line in r.stdout.strip().split('\n'):
            if line:
                parts = line.split(':')
                if len(parts) >= 2 and parts[1] in ['wifi', '802-11-wireless']:
                    result['connection'] = parts[0]
    except Exception as e:
        app.logger.warning(f"Connection check failed: {e}")
    try:
        r = subprocess.run(['nmcli', 'con', 'show', '--active'], capture_output=True, text=True)
        if 'hotspot' in r.stdout.lower() or '-ap' in r.stdout.lower():
            result['hotspot_active'] = True
    except Exception as e:
        app.logger.warning(f"Hotspot check failed: {e}")
    try:
        r = subprocess.run(['wg', 'show'], capture_output=True, text=True)
        if r.returncode == 0 and r.stdout.strip():
            result['vpn_active'] = True
    except Exception as e:
        app.logger.warning(f"VPN check failed: {e}")
    try:
        with open('/proc/uptime') as f:
            secs = int(float(f.read().split()[0]))
            result['uptime'] = f"{secs // 3600}h {(secs % 3600) // 60}m"
    except Exception as e:
        app.logger.warning(f"Uptime check failed: {e}")
    return jsonify(result)


@app.route('/api/wifi/scan')
def wifi_scan():
    networks = []
    try:
        subprocess.run(['nmcli', 'dev', 'wifi', 'rescan'], capture_output=True)
        r = subprocess.run(['nmcli', '-t', '-f', 'SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list'],
                          capture_output=True, text=True)
        seen = set()
        for line in r.stdout.strip().split('\n'):
            if line:
                parts = line.split(':')
                if len(parts) >= 2 and parts[0] and parts[0] not in seen:
                    seen.add(parts[0])
                    networks.append({
                        'ssid': parts[0],
                        'signal': parts[1] if len(parts) > 1 else '?',
                        'security': parts[2] if len(parts) > 2 else ''
                    })
    except Exception as e:
        app.logger.error(f"WiFi scan failed: {e}")
    return jsonify({'networks': sorted(networks, key=lambda x: -int(x['signal'] or 0))})


@app.route('/api/wifi/connect', methods=['POST'])
def wifi_connect():
    data = request.json
    ssid, password = data.get('ssid'), data.get('password', '')
    try:
        cmd = ['nmcli', 'dev', 'wifi', 'connect', ssid]
        if password:
            cmd += ['password', password]
        subprocess.run(cmd, capture_output=True, check=True)
        return jsonify({'success': True})
    except subprocess.CalledProcessError as e:
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/hotspot/toggle', methods=['POST'])
def hotspot_toggle():
    r = subprocess.run(['nmcli', 'con', 'show', '--active'], capture_output=True, text=True)
    ap_name = 'TravelRouter-AP'
    if ap_name.lower() in r.stdout.lower():
        subprocess.run(['nmcli', 'con', 'down', ap_name], capture_output=True)
        return jsonify({'active': False})
    else:
        # Get password from environment or password file
        password = os.environ.get('HOTSPOT_PASSWORD', '')
        password_file = os.environ.get('HOTSPOT_PASSWORD_FILE')
        if password_file and os.path.exists(password_file):
            try:
                with open(password_file) as f:
                    password = f.read().strip()
            except IOError as e:
                app.logger.error(f"Failed to read password file: {e}")
        if len(password) < 8:
            return jsonify({'active': False, 'error': 'Hotspot password not configured (min 8 chars). Use web UI to configure.'})
        ssid = os.environ.get('HOTSPOT_SSID', 'TravelRouter')
        subprocess.run(['nmcli', 'con', 'delete', ap_name], capture_output=True)
        subprocess.run([
            'nmcli', 'con', 'add', 'type', 'wifi', 'ifname', 'wlan0',
            'con-name', ap_name, 'autoconnect', 'no',
            'ssid', ssid, 'mode', 'ap',
            'ipv4.method', 'shared',
            'wifi-sec.key-mgmt', 'wpa-psk', 'wifi-sec.psk', password
        ], capture_output=True)
        subprocess.run(['nmcli', 'con', 'up', ap_name], capture_output=True)
        return jsonify({'active': True})


@app.route('/api/hotspot/config', methods=['POST'])
def hotspot_config():
    data = request.json
    ssid = data.get('ssid', 'TravelRouter')
    password = data.get('password', '')
    if len(password) < 8:
        return jsonify({'success': False, 'error': 'Password required (8+ chars)'})
    ap_name = 'TravelRouter-AP'
    subprocess.run(['nmcli', 'con', 'delete', ap_name], capture_output=True)
    r = subprocess.run([
        'nmcli', 'con', 'add', 'type', 'wifi', 'ifname', 'wlan0',
        'con-name', ap_name, 'autoconnect', 'no',
        'ssid', ssid, 'mode', 'ap', 'ipv4.method', 'shared',
        'wifi-sec.key-mgmt', 'wpa-psk', 'wifi-sec.psk', password
    ], capture_output=True)
    return jsonify({'success': r.returncode == 0})


@app.route('/api/vpn/toggle', methods=['POST'])
def vpn_toggle():
    r = subprocess.run(['wg', 'show'], capture_output=True, text=True)
    if r.returncode == 0 and r.stdout.strip():
        subprocess.run(['wg-quick', 'down', 'wg0'], capture_output=True)
        return jsonify({'active': False})
    else:
        subprocess.run(['wg-quick', 'up', 'wg0'], capture_output=True)
        return jsonify({'active': True})


@app.route('/api/vpn/config', methods=['POST'])
def vpn_config():
    data = request.json
    config = data.get('config', '').strip()
    # Validate WireGuard config structure
    if not config:
        return jsonify({'success': False, 'error': 'Empty configuration'})
    # Must have [Interface] section
    if not re.search(r'^\[Interface\]', config, re.MULTILINE):
        return jsonify({'success': False, 'error': 'Missing [Interface] section'})
    # Must have PrivateKey
    if not re.search(r'^PrivateKey\s*=', config, re.MULTILINE):
        return jsonify({'success': False, 'error': 'Missing PrivateKey'})
    # Must have at least one [Peer]
    if not re.search(r'^\[Peer\]', config, re.MULTILINE):
        return jsonify({'success': False, 'error': 'Missing [Peer] section'})
    # Block dangerous characters (path traversal, shell injection)
    if re.search(r'[;&|`$]', config):
        return jsonify({'success': False, 'error': 'Invalid characters in config'})
    try:
        with open('/etc/wireguard/wg0.conf', 'w') as f:
            f.write(config)
        os.chmod('/etc/wireguard/wg0.conf', 0o600)
        return jsonify({'success': True})
    except Exception as e:
        app.logger.error(f"Failed to write WireGuard config: {e}")
        return jsonify({'success': False, 'error': str(e)})


@app.route('/api/clients')
def clients():
    client_list = []
    try:
        r = subprocess.run(['ip', 'neigh', 'show'], capture_output=True, text=True)
        for line in r.stdout.strip().split('\n'):
            parts = line.split()
            if len(parts) >= 5 and parts[2] == 'lladdr':
                client_list.append({'ip': parts[0], 'mac': parts[4], 'hostname': None})
    except Exception as e:
        app.logger.warning(f"Failed to get network neighbors: {e}")
    try:
        if os.path.exists('/var/lib/dnsmasq/dnsmasq.leases'):
            with open('/var/lib/dnsmasq/dnsmasq.leases') as f:
                for line in f:
                    parts = line.split()
                    if len(parts) >= 4:
                        mac, ip = parts[1], parts[2]
                        hostname = parts[3] if parts[3] != '*' else None
                        for c in client_list:
                            if c['mac'].lower() == mac.lower():
                                c['hostname'] = hostname
                                break
                        else:
                            client_list.append({'ip': ip, 'mac': mac, 'hostname': hostname})
    except Exception as e:
        app.logger.warning(f"Failed to read DHCP leases: {e}")
    return jsonify({'clients': client_list})


@app.route('/api/system/reboot', methods=['POST'])
def system_reboot():
    subprocess.Popen(['systemctl', 'reboot'])
    return jsonify({'success': True})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=False)
