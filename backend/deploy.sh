#!/bin/bash
set -e

echo "=== FoodCheckIn Backend Deploy ==="

# 1. Install system dependencies (run once)
# sudo apt update && sudo apt install -y python3.11 python3.11-venv postgresql nginx certbot python3-certbot-nginx

# 2. Create project directory
sudo mkdir -p /opt/foodcheckin
sudo chown $USER:$USER /opt/foodcheckin

# 3. Copy code
rsync -av --exclude='__pycache__' --exclude='.env' --exclude='venv' . /opt/foodcheckin/backend/

# 4. Setup Python venv
cd /opt/foodcheckin
python3.11 -m venv venv
source venv/bin/activate
pip install -r backend/requirements.txt

# 5. Setup database (run once)
# sudo -u postgres createdb foodcheckin
# sudo -u postgres createdb foodcheckin_test

# 6. Run migrations
cd backend
alembic upgrade head

# 7. Install systemd service
sudo cp foodcheckin.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable foodcheckin
sudo systemctl restart foodcheckin

# 8. Setup nginx (run once, replace your-domain.com)
# sudo cp nginx.conf /etc/nginx/sites-available/foodcheckin
# sudo ln -sf /etc/nginx/sites-available/foodcheckin /etc/nginx/sites-enabled/
# sudo certbot --nginx -d your-domain.com
# sudo systemctl restart nginx

echo "=== Deploy complete ==="
echo "Check status: sudo systemctl status foodcheckin"
echo "Check logs: sudo journalctl -u foodcheckin -f"
