# 🚀 Deployment Guide - JCRP FiveM Server

Complete step-by-step deployment guide for production environments.

## 📋 Prerequisites Checklist

- [ ] Dedicated Linux server (Ubuntu 20.04+ recommended) or Windows Server
- [ ] 4GB+ RAM minimum, 8GB+ recommended
- [ ] MySQL 8.0+ or MariaDB 10.5+
- [ ] Valid FiveM license key (from https://keymaster.fivem.net)
- [ ] SSH access and sudo privileges

## 🔧 Server Setup

### 1. Install Dependencies

#### Ubuntu/Debian
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install MySQL
sudo apt install mysql-server -y

# Secure MySQL
sudo mysql_secure_installation

# Install git
sudo apt install git -y

# Install screen (for keeping server running)
sudo apt install screen -y
```

#### CentOS/RHEL
```bash
# Update system
sudo yum update -y

# Install MySQL
sudo yum install mysql-server -y
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Install git
sudo yum install git -y

# Install screen
sudo yum install screen -y
```

### 2. Create Database

```bash
# Login to MySQL
sudo mysql -u root -p

# Create database
CREATE DATABASE jcrp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# Create user
CREATE USER 'jcrp_user'@'localhost' IDENTIFIED BY 'STRONG_PASSWORD_HERE';

# Grant permissions
GRANT ALL PRIVILEGES ON jcrp.* TO 'jcrp_user'@'localhost';
FLUSH PRIVILEGES;

# Exit
EXIT;
```

### 3. Install FiveM Server

```bash
# Create directory
mkdir -p /home/fivem
cd /home/fivem

# Download latest FiveM server (Linux)
wget https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/XXXX-XXXXX/fx.tar.xz

# Extract
tar xf fx.tar.xz

# Create server data directory
mkdir -p server-data
cd server-data
```

### 4. Clone Repository

```bash
cd /home/fivem/server-data

# Clone the JCRP repository
git clone https://github.com/PRNative/FiveM-JCRP.git .

# Or download and extract if not using git
```

### 5. Install Required Resources

```bash
cd resources

# Install oxmysql
git clone https://github.com/overextended/oxmysql.git [standalone]/oxmysql

# Install ox_lib
git clone https://github.com/overextended/ox_lib.git [standalone]/ox_lib
```

## ⚙️ Configuration

### 1. Configure Database Connection

Edit `server.cfg`:

```cfg
set mysql_connection_string "mysql://jcrp_user:STRONG_PASSWORD_HERE@localhost/jcrp?charset=utf8mb4"
```

### 2. Set License Key

In `server.cfg`:

```cfg
sv_licenseKey "YOUR_CFXRE_LICENSE_KEY_HERE"
```

### 3. Configure Server Identity

In `server.cfg`:

```cfg
sv_hostname "^3Your Server Name^7 | Roleplay"
sv_projectName "Your Server"
sv_projectDesc "Your server description"
```

### 4. Customize Server Config

Edit `config/server_config.json`:

```json
{
  "server": {
    "name": "Your Server",
    "brand": "Your Brand",
    "logo_url": "https://your-domain.com/logo.png",
    "discord_url": "https://discord.gg/your-invite",
    "website_url": "https://your-domain.com"
  },
  "characters": {
    "max_slots": 3,
    "default_money": {
      "cash": 5000,
      "bank": 25000,
      "dirty": 0
    }
  }
}
```

### 5. Configure Spawn Locations

In `config/server_config.json`, customize spawn points:

```json
{
  "spawn": {
    "new_character_spawn": {
      "x": -1035.71,
      "y": -2731.87,
      "z": 13.76,
      "heading": 150.0,
      "label": "Airport"
    },
    "predefined_spawns": [
      {
        "id": "custom_spawn",
        "label": "Your Custom Location",
        "x": 0.0,
        "y": 0.0,
        "z": 0.0,
        "heading": 0.0
      }
    ]
  }
}
```

## 🎮 Starting the Server

### Method 1: Direct Start

```bash
cd /home/fivem
bash run.sh +exec server-data/server.cfg
```

### Method 2: Using Screen (Recommended)

```bash
# Create screen session
screen -S fivem

# Start server
cd /home/fivem
bash run.sh +exec server-data/server.cfg

# Detach from screen: Ctrl+A, then D
# Reattach: screen -r fivem
```

### Method 3: Systemd Service (Production)

Create `/etc/systemd/system/fivem.service`:

```ini
[Unit]
Description=FiveM Server
After=network.target

[Service]
Type=simple
User=fivem
WorkingDirectory=/home/fivem
ExecStart=/bin/bash /home/fivem/run.sh +exec /home/fivem/server-data/server.cfg
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then:

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable fivem

# Start service
sudo systemctl start fivem

# Check status
sudo systemctl status fivem

# View logs
sudo journalctl -u fivem -f
```

## 🔍 Verification

### 1. Check Database Migrations

After first start, verify migrations applied:

```bash
mysql -u jcrp_user -p jcrp

# Check migrations table
SELECT * FROM schema_migrations ORDER BY version;

# Should show versions 1-19 (or current count)
```

### 2. Check Server Console

Look for these success messages:

```
[CORE_BOOT] ✓ JCRP Core Boot Complete
[CORE_IDENTITY] Initialized
[CORE_CHARACTERS] Initialized
[CORE_STATE] Initialized
[CORE_SESSION] Initialized
[SYSTEM_MONEY] Initialized
[SYSTEM_INVENTORY] Initialized
[SYSTEM_JOBS] Initialized
```

### 3. Test Connection

1. Open FiveM client
2. Press F8 and type: `connect localhost:30120` (or your IP)
3. Should see loading screen
4. Should be able to create character

## 🔐 Security Hardening

### 1. Firewall Configuration

```bash
# Allow FiveM port
sudo ufw allow 30120/tcp
sudo ufw allow 30120/udp

# Enable firewall
sudo ufw enable
```

### 2. Database Security

```bash
# Edit MySQL config
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf

# Change bind-address to localhost only (if DB is on same server)
bind-address = 127.0.0.1

# Restart MySQL
sudo systemctl restart mysql
```

### 3. Server ACL

In `server.cfg`, configure ACL:

```cfg
# Add admins by license
add_principal identifier.license:YOUR_LICENSE group.admin

# Grant permissions
add_ace group.admin command allow
add_ace group.admin system.admin allow
```

### 4. Rate Limiting

In `server.cfg`:

```cfg
# Connection rate limit
sv_endpointprivacy true
sv_scriptHookAllowed 0
```

## 📊 Monitoring

### 1. Server Resources

```bash
# Monitor CPU/RAM usage
htop

# Monitor specific process
top -p $(pgrep -f FXServer)
```

### 2. Database Performance

```bash
# Login to MySQL
mysql -u jcrp_user -p jcrp

# Check table sizes
SELECT 
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.TABLES
WHERE table_schema = 'jcrp'
ORDER BY (data_length + index_length) DESC;

# Monitor slow queries
SHOW PROCESSLIST;
```

### 3. Log Files

```bash
# FiveM server logs
tail -f /home/fivem/server-data/logs/server.log

# System logs
sudo tail -f /var/log/syslog | grep fivem
```

## 🔄 Maintenance

### Daily Tasks

```bash
# Backup database
mysqldump -u jcrp_user -p jcrp > backup_$(date +%Y%m%d).sql

# Rotate logs
find /home/fivem/server-data/logs -name "*.log" -mtime +7 -delete
```

### Weekly Tasks

```bash
# Update server
cd /home/fivem
wget https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/LATEST/fx.tar.xz
tar xf fx.tar.xz

# Update resources
cd /home/fivem/server-data
git pull
```

### Database Maintenance

```sql
-- Optimize tables monthly
OPTIMIZE TABLE accounts, characters, character_inventory, owned_vehicles;

-- Clean old audit logs (keep 90 days)
DELETE FROM account_audit WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
DELETE FROM admin_audit WHERE created_at < DATE_SUB(NOW(), INTERVAL 90 DAY);
DELETE FROM money_ledger WHERE created_at < DATE_SUB(NOW(), INTERVAL 180 DAY);
```

## 🔧 Troubleshooting

### Server Won't Start

1. **Check MySQL is running**:
   ```bash
   sudo systemctl status mysql
   ```

2. **Test database connection**:
   ```bash
   mysql -u jcrp_user -p jcrp -e "SELECT 1;"
   ```

3. **Check console for errors**:
   - Look for red error messages
   - Common issues: wrong DB credentials, missing resources

### Players Can't Connect

1. **Check firewall**:
   ```bash
   sudo ufw status
   ```

2. **Verify port is listening**:
   ```bash
   netstat -tulpn | grep 30120
   ```

3. **Check server.cfg**:
   - Ensure endpoint is correct
   - Verify license key is valid

### Database Errors

1. **Check migrations**:
   ```sql
   SELECT * FROM schema_migrations ORDER BY version;
   ```

2. **Manually run failed migration**:
   - Find SQL in `resources/*/server/migrations.lua`
   - Run manually in MySQL

3. **Reset if needed** (CAUTION - DELETES ALL DATA):
   ```sql
   DROP DATABASE jcrp;
   CREATE DATABASE jcrp CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

### Performance Issues

1. **Check resource usage**:
   ```bash
   htop
   ```

2. **Optimize database**:
   ```sql
   OPTIMIZE TABLE accounts, characters, character_inventory;
   ```

3. **Add database indexes** (if needed):
   ```sql
   -- Already included in migrations, but verify with:
   SHOW INDEX FROM table_name;
   ```

## 📈 Scaling

### Vertical Scaling (Single Server)

- Upgrade to 16GB+ RAM
- Use SSD storage
- Increase MySQL memory buffers:

```ini
# In /etc/mysql/mysql.conf.d/mysqld.cnf
[mysqld]
innodb_buffer_pool_size = 4G
innodb_log_file_size = 512M
max_connections = 500
```

### Horizontal Scaling (Future)

For 100+ concurrent players:

1. **Separate Database Server**
   - Dedicated MySQL server
   - Update connection string

2. **Load Balancing**
   - Multiple FiveM servers
   - Shared database
   - Nginx/HAProxy for load balancing

3. **CDN for Assets**
   - Host large files on CDN
   - Reduce server bandwidth

## 🆘 Support

### Getting Help

1. **Check console logs** for specific errors
2. **Review database migrations** status
3. **Test individual resources** by disabling others
4. **Check GitHub issues** for known problems

### Reporting Issues

When reporting issues, include:

- Server version (FiveM artifact)
- Database version (MySQL/MariaDB)
- Console error messages
- Resource versions
- Steps to reproduce

## ✅ Production Checklist

Before going live:

- [ ] Database backups configured
- [ ] Firewall configured
- [ ] ACL permissions set
- [ ] Admin roles assigned
- [ ] Server name/branding updated
- [ ] Spawn locations tested
- [ ] All migrations applied
- [ ] Character creation tested
- [ ] Money system tested
- [ ] Inventory system tested
- [ ] Job system tested
- [ ] Vehicle system tested
- [ ] Apartment system tested
- [ ] Restart safety verified
- [ ] Performance monitored
- [ ] Documentation reviewed

---

**Deployment Status**: Ready for Production

**Support**: Community-driven

**Updates**: Check GitHub regularly
