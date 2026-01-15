# Setup Configuration Guide

Use `setup.conf` to store your configuration and avoid entering credentials every time you install or upgrade.

## Quick Setup

### 1. Create Your Configuration File

```bash
cd ~/ingest-system
cp setup.conf.example setup.conf
```

### 2. Edit With Your Details

```bash
nano setup.conf
```

Fill in these required fields:

```bash
# NAS Configuration
NAS_HOST="192.168.1.100"        # Your NAS IP or hostname
NAS_SHARE="ingest"              # Your NAS share name
NAS_USER="your_username"        # NAS username
NAS_PASS="your_password"        # NAS password

# Dashboard Configuration
DASH_USER="admin"               # Dashboard login username
DASH_PASS="secure_password"     # Dashboard login password
```

Optional settings:

```bash
# Dashboard port (default: 4666)
DASH_PORT="4666"

# Wipe mode (0=full wipe, 1=skip, 2=fast erase)
WIPE_MODE="2"
```

### 3. Secure The File

```bash
chmod 600 setup.conf
```

This ensures only root can read your passwords.

### 4. Run Installation

```bash
sudo ./install.sh
```

The installer will automatically detect `setup.conf` and use your saved settings!

## Benefits

### ✓ No Repeated Prompts
Fill in details once, use forever

### ✓ Easy Reinstalls
Reinstall or upgrade without re-entering credentials

### ✓ Script-Friendly
Perfect for automated deployments

### ✓ Version Control Safe
`setup.conf` is in `.gitignore` - won't be committed

### ✓ Quick Recovery
Keep a backup copy for disaster recovery

## Usage Modes

### With setup.conf (Recommended)

```bash
# Create and edit setup.conf
cp setup.conf.example setup.conf
nano setup.conf

# Install automatically
sudo ./install.sh
```

Output:
```
Found setup.conf - loading configuration...
✓ NAS: myuser@192.168.1.100/ingest
✓ Dashboard: admin
✓ Wipe mode set to: 2
```

### Without setup.conf (Interactive)

```bash
# Just run install
sudo ./install.sh
```

Output:
```
No setup.conf found - using interactive mode
Tip: Create setup.conf to skip prompts in future

NAS Configuration
Please provide your NAS details:
NAS IP address or hostname: _
```

## Configuration Fields

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `NAS_HOST` | NAS IP or hostname | `192.168.1.100` or `nas.local` |
| `NAS_SHARE` | SMB share name | `ingest`, `media`, `backup` |
| `NAS_USER` | NAS username | `admin`, `pi`, `your_username` |
| `NAS_PASS` | NAS password | `your_secure_password` |
| `DASH_USER` | Dashboard username | `admin`, `operator` |
| `DASH_PASS` | Dashboard password | `dashboard_password` |

### Optional Fields

| Field | Description | Default | Options |
|-------|-------------|---------|---------|
| `DASH_PORT` | Dashboard web port | `4666` | Any available port |
| `WIPE_MODE` | Drive wipe behavior | `2` | `0`=full, `1`=skip, `2`=fast |

## Security Best Practices

### 1. File Permissions

Always restrict access to setup.conf:
```bash
chmod 600 setup.conf
chown root:root setup.conf
```

### 2. Strong Passwords

Use strong passwords for both NAS and dashboard:
```bash
# Good
DASH_PASS="K9m#Lp2$Wx7@Qn5"

# Bad
DASH_PASS="password123"
```

### 3. Don't Commit

Never commit `setup.conf` to version control:
- Already in `.gitignore`
- Keep sensitive copy separate
- Don't share screenshots containing credentials

### 4. Backup Securely

If backing up `setup.conf`:
```bash
# Encrypt it
gpg -c setup.conf

# Or store in password manager
# Or keep on encrypted USB drive
```

### 5. Delete After Install (Optional)

For maximum security, delete after installation:
```bash
sudo ./install.sh
shred -u setup.conf  # Securely delete
```

You can always recreate it for future reinstalls.

## Example Configuration

Here's a complete example:

```bash
# Ingest System Setup Configuration
# Fill out this file before running install.sh

# ===========================================
# NAS Configuration
# ===========================================

NAS_HOST="192.168.1.100"
NAS_SHARE="ingest"
NAS_USER="mediauser"
NAS_PASS="SecureNasPass123!"

# ===========================================
# Dashboard Configuration
# ===========================================

DASH_USER="admin"
DASH_PASS="Dashboard$ecure456"

# ===========================================
# Optional Settings
# ===========================================

DASH_PORT="4666"
WIPE_MODE="2"
```

## Troubleshooting

### "setup.conf is incomplete!"

Make sure all required fields have values:
```bash
# Check your file
cat setup.conf | grep "^NAS_"
cat setup.conf | grep "^DASH_"
```

All fields must have values (not empty quotes).

### Can't Find setup.conf

Installer looks in the same directory as install.sh:
```bash
# Check location
ls -la setup.conf

# Ensure it's in the right place
cd ~/ingest-system
ls setup.conf
```

### Passwords With Special Characters

Quote passwords with special characters:
```bash
# Good
NAS_PASS="Pass@word#123"

# Also works
NAS_PASS='Pass@word#123'
```

Avoid these characters that may cause issues:
- Single quotes in double-quoted strings
- Double quotes in single-quoted strings
- Backticks (`)
- Dollar signs followed by letters (`$VAR`)

If you must use them, escape them:
```bash
NAS_PASS="Pass\$word\"with'quotes"
```

### Still Being Prompted

If you have `setup.conf` but still see prompts:
```bash
# Check file is readable
sudo cat setup.conf

# Check file location
pwd  # Should be in ingest-system directory
ls -la setup.conf

# Check fields are filled
grep -v "^#" setup.conf | grep "="
```

## Upgrading Existing Installation

If you already installed without `setup.conf`:

### Create Config for Future

```bash
cd ~/ingest-system
cp setup.conf.example setup.conf
nano setup.conf
# Fill in your details
chmod 600 setup.conf
```

### Reinstall Using Config

```bash
sudo ./install.sh
```

The installer preserves existing `/etc/ingest/ingest.conf`, so your settings are safe.

## Multiple Environments

You can maintain different configs for different setups:

```bash
# Production
setup.conf.production

# Testing
setup.conf.testing

# Development
setup.conf.dev
```

Then use them:
```bash
# Copy the one you want
cp setup.conf.production setup.conf
sudo ./install.sh
```

## Template for Teams

Share `setup.conf.example` with your team:

```bash
# Team member downloads repo
git clone https://github.com/yourusername/ingest-system.git
cd ingest-system

# Copies example
cp setup.conf.example setup.conf

# Edits with their details
nano setup.conf

# Installs
sudo ./install.sh
```

Everyone uses the same template, fills their own details.

## Migration from Interactive Install

If you installed interactively before, create setup.conf for next time:

```bash
cd ~/ingest-system
cat > setup.conf << 'EOF'
NAS_HOST="your_nas_ip"
NAS_SHARE="your_share"
NAS_USER="your_user"
NAS_PASS="your_pass"
DASH_USER="your_dash_user"
DASH_PASS="your_dash_pass"
WIPE_MODE="2"
EOF

chmod 600 setup.conf
```

Next upgrade or reinstall will be automatic!

---

**Pro Tip:** Keep a backup of `setup.conf` in a secure location (encrypted USB drive, password manager) for easy disaster recovery! 🔐
