# RAGF Demo - Deployment Guide

## ✅ Features Implemented

1. **Bilingual Interface** (EN/ES)
   - Language toggle in header
   - All content translated

2. **Educational Content**
   - "How It Works" tab explaining RAGF
   - Flow diagrams
   - Key features
   - Validator descriptions

3. **Basic Security** (Optional)
   - HTTP Basic Auth
   - Security headers
   - Can be enabled/disabled

---

## 🚀 Current Status

### Running Locally
```bash
# Demo accessible at:
http://localhost

# Features:
✅ 6 interactive scenarios
✅ Real-time validation
✅ Bilingual (EN/ES)
✅ "How It Works" educational tab
✅ API docs link
✅ Security headers enabled
```

---

## 🔐 Enable Basic Auth (Optional)

### Step 1: Create password file

```bash
cd ~/Dev/ragf/infra/docker

# Install htpasswd if needed (macOS)
brew install httpd

# Create password file
htpasswd -c .htpasswd ragf_demo
# Enter password when prompted (e.g., "demo2026")
```

### Step 2: Update nginx.conf

Uncomment these lines in `nginx.conf`:
```nginx
# auth_basic "RAGF Demo - Restricted Access";
# auth_basic_user_file /etc/nginx/.htpasswd;
```

To:
```nginx
auth_basic "RAGF Demo - Restricted Access";
auth_basic_user_file /etc/nginx/.htpasswd;
```

### Step 3: Update docker-compose to mount .htpasswd

Add to nginx volumes in `docker-compose.demo.yml`:
```yaml
volumes:
  - ./nginx.conf:/etc/nginx/nginx.conf:ro
  - ./html:/usr/share/nginx/html:ro
  - ./.htpasswd:/etc/nginx/.htpasswd:ro  # ADD THIS LINE
```

### Step 4: Restart

```bash
docker-compose -f docker-compose.demo.yml restart nginx
```

Now accessing `http://localhost` will require:
- **Username**: `ragf_demo`
- **Password**: `demo2026` (or whatever you set)

---

## 🌐 Deploy to VPS (Next Step)

### Prerequisites
- VPS with Docker installed
- Domain name (e.g., demo.agentsave.one)
- SSL certificate (Let's Encrypt)

### Quick Deploy
```bash
# On VPS
git clone <your-repo>
cd ragf/infra/docker

# Start services
docker-compose -f docker-compose.demo.yml up -d

# Setup SSL (if using domain)
certbot --nginx -d demo.agentsave.one
```

---

## 📊 What Users See

### Tab 1: Interactive Demo
- 6 clickable scenarios
- Real-time validation results
- Explanations + regulatory refs
- Performance metrics

### Tab 2: How It Works
- Problem statement
- RAGF solution architecture
- Validation flow diagram
- Key features
- Validator list
- Links to docs

### Language Toggle
- English (default)
- Spanish
- Instant switching

---

## 🎯 Recommended Settings for Production

1. **Enable Basic Auth** ✅
2. **Use HTTPS** (Let's Encrypt)
3. **Set strong password** (not "demo2026")
4. **Update GitHub link** in "How It Works" to your repo
5. **Add rate limiting** (optional - nginx limit_req)

---

## 💡 Next Steps

Choose one:

**Option A: Add More Security**
- Rate limiting
- IP whitelist
- OAuth/Auth0

**Option B: Deploy to VPS**
- Get domain
- Setup SSL
- Configure DNS

**Option C: Improve Demo**
- More scenarios
- Charts/graphs
- Export audit logs

**Let me know which you prefer!** 🚀
