#!/usr/bin/env python3

"""
Ingest Dashboard - Web interface with manual controls
"""

from flask import Flask, render_template, jsonify, request
from flask_httpauth import HTTPBasicAuth
import json
import os
import subprocess
from datetime import datetime

app = Flask(__name__)
auth = HTTPBasicAuth()

# Configuration
STATUS_FILE = "/var/run/ingest/current.json"
LOG_DIR = "/var/log/ingest"
INGEST_DIR = "/mnt/ingest"
HTPASSWD_FILE = "/etc/ingest/dashboard.htpasswd"
CONTROL_SCRIPT = "/usr/local/bin/ingest-control.sh"
AUTO_SCAN_FLAG = "/var/run/ingest/auto_scan_enabled"

# Load user credentials
users = {}
if os.path.exists(HTPASSWD_FILE):
    with open(HTPASSWD_FILE, 'r') as f:
        for line in f:
            if ':' in line:
                username, password_hash = line.strip().split(':', 1)
                users[username] = password_hash

@auth.verify_password
def verify_password(username, password):
    if username in users:
        result = subprocess.run(
            ['htpasswd', '-vb', HTPASSWD_FILE, username, password],
            capture_output=True,
            text=True
        )
        return result.returncode == 0
    return False

def get_current_status():
    if os.path.exists(STATUS_FILE):
        try:
            with open(STATUS_FILE, 'r') as f:
                return json.load(f)
        except:
            pass
    return {
        "status": "idle",
        "message": "Ready for drive",
        "progress": 0,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "device": "none",
        "drive_label": "none",
        "total_files": 0,
        "total_size": "0",
        "transferred_files": 0,
        "current_file": "",
        "dest_folder": ""
    }

def get_recent_ingests():
    ingests = []
    if not os.path.exists(INGEST_DIR):
        return ingests
    try:
        folders = []
        for item in os.listdir(INGEST_DIR):
            item_path = os.path.join(INGEST_DIR, item)
            if os.path.isdir(item_path):
                folders.append({
                    'name': item,
                    'path': item_path,
                    'mtime': os.path.getmtime(item_path)
                })
        folders.sort(key=lambda x: x['mtime'], reverse=True)
        for folder in folders[:20]:
            folder_path = folder['path']
            file_count = 0
            total_size = 0
            for root, dirs, files in os.walk(folder_path):
                file_count += len([f for f in files if not f.startswith('ingest_log') and not f.startswith('checksums')])
                for f in files:
                    try:
                        total_size += os.path.getsize(os.path.join(root, f))
                    except:
                        pass
            log_file = None
            for file in os.listdir(folder_path):
                if file.startswith('ingest_log'):
                    log_file = file
            status = "unknown"
            drive_label = "unknown"
            if log_file:
                try:
                    with open(os.path.join(folder_path, log_file), 'r') as f:
                        content = f.read()
                        if 'SUCCESS' in content:
                            status = 'success'
                        elif 'FAILED' in content or 'ERROR' in content:
                            status = 'error'
                        for line in content.split('\n'):
                            if 'Drive Label:' in line:
                                drive_label = line.split('Drive Label:')[1].strip()
                except:
                    pass
            ingests.append({
                'date': folder['name'],
                'timestamp': datetime.fromtimestamp(folder['mtime']).isoformat(),
                'file_count': file_count,
                'total_size': format_size(total_size),
                'total_size_bytes': total_size,
                'status': status,
                'drive_label': drive_label,
                'log_file': log_file
            })
    except Exception as e:
        print(f"Error reading ingest history: {e}")
    return ingests

def format_size(bytes):
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes < 1024.0:
            return f"{bytes:.2f} {unit}"
        bytes /= 1024.0
    return f"{bytes:.2f} PB"

def get_system_info():
    info = {
        'hostname': os.uname().nodename,
        'uptime': 'unknown',
        'nas_mounted': os.path.ismount(INGEST_DIR),
        'nas_space': 'unknown',
        'auto_scan_enabled': os.path.exists(AUTO_SCAN_FLAG)
    }
    try:
        with open('/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
            uptime_hours = int(uptime_seconds // 3600)
            uptime_minutes = int((uptime_seconds % 3600) // 60)
            info['uptime'] = f"{uptime_hours}h {uptime_minutes}m"
    except:
        pass
    if info['nas_mounted']:
        try:
            stat = os.statvfs(INGEST_DIR)
            total = stat.f_blocks * stat.f_frsize
            free = stat.f_bavail * stat.f_frsize
            used = total - free
            info['nas_space'] = {
                'total': format_size(total),
                'used': format_size(used),
                'free': format_size(free),
                'percent': int((used / total) * 100)
            }
        except:
            pass
    return info

def get_available_devices():
    """Get list of connected USB storage devices"""
    try:
        result = subprocess.run(
            ['lsblk', '-J', '-o', 'NAME,SIZE,LABEL,FSTYPE,TYPE'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            devices = []
            for device in data.get('blockdevices', []):
                # Only include USB storage devices with partitions
                if device.get('type') == 'disk' and device.get('name', '').startswith('sd'):
                    for child in device.get('children', []):
                        if child.get('fstype'):  # Has a filesystem
                            devices.append({
                                'device': f"/dev/{child['name']}",
                                'name': child['name'],
                                'size': child.get('size', 'Unknown'),
                                'label': child.get('label', 'Unlabeled'),
                                'fstype': child.get('fstype', 'Unknown')
                            })
            return devices
    except:
        pass
    return []

@app.route('/')
@auth.login_required
def index():
    return render_template('index.html')

@app.route('/api/status')
@auth.login_required
def api_status():
    status = get_current_status()
    return jsonify(status)

@app.route('/api/history')
@auth.login_required
def api_history():
    history = get_recent_ingests()
    return jsonify(history)

@app.route('/api/system')
@auth.login_required
def api_system():
    info = get_system_info()
    return jsonify(info)

@app.route('/api/devices')
@auth.login_required
def api_devices():
    devices = get_available_devices()
    return jsonify(devices)

@app.route('/api/logs/<path:date>')
@auth.login_required
def api_logs(date):
    folder_path = os.path.join(INGEST_DIR, date)
    if not os.path.exists(folder_path):
        return jsonify({'error': 'Folder not found'}), 404
    log_file = None
    for file in os.listdir(folder_path):
        if file.startswith('ingest_log'):
            log_file = file
            break
    if not log_file:
        return jsonify({'error': 'Log file not found'}), 404
    try:
        with open(os.path.join(folder_path, log_file), 'r') as f:
            content = f.read()
        return jsonify({'log': content})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/control/auto-scan', methods=['POST'])
@auth.login_required
def control_auto_scan():
    data = request.get_json()
    action = data.get('action')
    
    if action == 'enable':
        result = subprocess.run([CONTROL_SCRIPT, 'enable-auto'], capture_output=True, text=True)
    elif action == 'disable':
        result = subprocess.run([CONTROL_SCRIPT, 'disable-auto'], capture_output=True, text=True)
    else:
        return jsonify({'error': 'Invalid action'}), 400
    
    return jsonify({
        'success': result.returncode == 0,
        'message': result.stdout.strip(),
        'enabled': os.path.exists(AUTO_SCAN_FLAG)
    })

@app.route('/api/control/manual-scan', methods=['POST'])
@auth.login_required
def control_manual_scan():
    data = request.get_json()
    device = data.get('device')
    
    if not device:
        return jsonify({'error': 'Device required'}), 400
    
    result = subprocess.run([CONTROL_SCRIPT, 'manual-scan', device], capture_output=True, text=True)
    
    return jsonify({
        'success': result.returncode == 0,
        'message': result.stdout.strip()
    })

@app.route('/api/control/stop', methods=['POST'])
@auth.login_required
def control_stop():
    result = subprocess.run([CONTROL_SCRIPT, 'stop'], capture_output=True, text=True)
    
    return jsonify({
        'success': result.returncode == 0,
        'message': result.stdout.strip()
    })

@app.route('/api/control/delete-folder', methods=['POST'])
@auth.login_required
def control_delete_folder():
    data = request.get_json()
    folder = data.get('folder')

    if not folder:
        return jsonify({'error': 'Folder name required'}), 400

    result = subprocess.run([CONTROL_SCRIPT, 'delete-folder', folder], capture_output=True, text=True)

    return jsonify({
        'success': result.returncode == 0,
        'message': result.stdout.strip()
    })

@app.route('/api/control/unmount-device', methods=['POST'])
@auth.login_required
def control_unmount_device():
    data = request.get_json()
    device = data.get('device')

    if not device:
        return jsonify({'error': 'Device required'}), 400

    result = subprocess.run([CONTROL_SCRIPT, 'unmount-device', device], capture_output=True, text=True)

    return jsonify({
        'success': result.returncode == 0,
        'message': result.stdout.strip()
    })

if __name__ == '__main__':
    os.makedirs('templates', exist_ok=True)
    
    print("=" * 50)
    print("Ingest Dashboard Starting")
    print("=" * 50)
    print(f"Users loaded: {len(users)}")
    print(f"Auto-scan: {'Enabled' if os.path.exists(AUTO_SCAN_FLAG) else 'Disabled'}")
    print(f"Listening on: http://0.0.0.0:4666")
    print("=" * 50)
    
    app.run(host='0.0.0.0', port=4666, debug=False)
