# ImChat VPS Backend Deployment Guide (PostgreSQL + Node.js + Socket.io)

এই ফোল্ডারে আপনার অ্যাপের জন্য সম্পূর্ণ নিজস্ব VPS ব্যাকএন্ড রয়েছে, যা ফায়ারবেস ডাটাবেজের বিল ছাড়া হাই-স্পিড রিয়েল-টাইম সার্ভিস প্রদান করে।

---

## ১. VPS সার্ভারে যা যা লাগবে (Prerequisites)
- Ubuntu 20.04 / 22.04 LTS VPS
- Node.js v18 বা v20 (`curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs`)
- PostgreSQL 14 / 15 / 16 (`sudo apt install -y postgresql postgresql-contrib`)
- PM2 (`sudo npm install -g pm2`)

---

## ২. PostgreSQL ডাটাবেজ তৈরি ও স্কিমা লোড করা

```bash
# ১. Postgres প্রম্পটে যান
sudo -u postgres psql

# ২. ডাটাবেজ ও ইউজার তৈরি করুন
CREATE DATABASE imchat_db;
CREATE USER imchat_user WITH ENCRYPTED PASSWORD 'YourStrongPassword123!';
GRANT ALL PRIVILEGES ON DATABASE imchat_db TO imchat_user;
\q

# ৩. schema.sql ফাইলটি রান করুন
psql -U imchat_user -d imchat_db -h localhost -f schema.sql
```

---

## ৩. ব্যাকএন্ড কনফিগার ও রান করা

```bash
# ১. ডিপেনডেন্সি ইনস্টল করুন
cd backend
npm install

# ২. .env ফাইল তৈরি করুন
cp .env.example .env
nano .env
# (PG_HOST, PG_DATABASE, PG_USER, PG_PASSWORD ও FIREBASE_SERVICE_ACCOUNT_JSON দিন)

# ৩. PM2 দিয়ে ব্যাকগ্রাউন্ডে চালু করুন
pm2 start vps_server.js --name "imchat-backend"
pm2 save
pm2 startup
```

---

## ৪. Nginx রিভার্স প্রক্সি ও SSL সেটআপ (HTTPS & WSS)

`/etc/nginx/sites-available/imchat.conf` এ কনফিগ করুন:

```nginx
server {
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/imchat.conf /etc/nginx/sites-enabled/
sudo certbot --nginx -d api.yourdomain.com
sudo systemctl reload nginx
```

এখন আপনার VPS API `https://api.yourdomain.com` এবং WebSocket `wss://api.yourdomain.com` এ রেডি!
