RELEASE_DATE := $(shell date +%Y%m%d-%H%M%S)
PORTFOLIO_RELEASE_DIR := /home/portfolio/releases
PORTFOLIO_TARGET_DIR := $(PORTFOLIO_RELEASE_DIR)/$(RELEASE_DATE)
PORTFOLIO_LIVE_DIR := $(PORTFOLIO_RELEASE_DIR)/live
PORTFOLIO_SERVER_USER := portfolio
PORTFOLIO_SERVER_IP ?= 
LOCAL_DIRECTORY_PORTFOLIO := portfolio
SSH_KEY_PATH := ~/.ssh/id_rsa
SSH := ssh -i $(SSH_KEY_PATH)
SSH_TO_PORTFOLIO_ROOT := $(SSH) root@$(PORTFOLIO_SERVER_IP)
DOMAIN := mikewebster.io

.PHONY: setup_server
setup_server:
	echo "|| creating user...\n\n"
	$(SSH_TO_PORTFOLIO_ROOT) "sudo adduser $(PORTFOLIO_SERVER_USER); mkdir /home/$(PORTFOLIO_SERVER_USER); mkdir /home/$(PORTFOLIO_SERVER_USER)/.ssh"

	echo "|| copying ssh key...\n\n"
	cat $(SSH_KEY_PATH).pub | $(SSH_TO_PORTFOLIO_ROOT) "touch /home/$(PORTFOLIO_SERVER_USER)/.ssh/authorized_keys && chmod -R go= /home/$(PORTFOLIO_SERVER_USER)/.ssh && cat >> /home/$(PORTFOLIO_SERVER_USER)/.ssh/authorized_keys"

	echo "|| allow user to ssh...\n\n"
	$(SSH_TO_PORTFOLIO_ROOT) "rsync --archive --chown=$(PORTFOLIO_SERVER_USER) ~/.ssh /home/$(PORTFOLIO_SERVER_USER)"

	echo "|| creating directories...\n\n"
	$(SSH_TO_PORTFOLIO_ROOT) "mkdir /home/$(PORTFOLIO_SERVER_USER)/releases; mkdir /home/$(PORTFOLIO_SERVER_USER)/releases/live"

	echo "|| setting up firewall...\n\n"
	$(SSH_TO_PORTFOLIO_ROOT) "sudo ufw enable; sudo ufw allow ssh"

	echo "|| installing nginx...\n\n"
	$(SSH_TO_PORTFOLIO_ROOT) "sudo apt update; sudo apt install nginx; sudo ufw allow 'Nginx Full'"

	echo "|| creating nginx site...\n\n"
	$(SSH_TO_PORTFOLIO_ROOT) "cp /etc/nginx/sites-available/default /etc/nginx/sites-available/$(DOMAIN); sudo ln -s /etc/nginx/sites-available/$(DOMAIN) /etc/nginx/sites-enabled/"

	echo "|| installing ssl certs...\n\n"
	$(SSH_TO_PORTFOLIO_ROOT) "sudo snap install core; sudo snap refresh core; sudo snap install --classic certbot; sudo ln -s /snap/bin/certbot /usr/bin/certbot; sudo certbot --nginx -d $(DOMAIN) -d www.$(DOMAIN)"

	echo "\\ successful configuration!"

.PHONY: release_portfolio
release_portfolio:
	echo "|| creating release directory..."
	ssh -i ~/.ssh/id_rsa $(PORTFOLIO_SERVER_USER)@$(PORTFOLIO_SERVER_IP) "mkdir $(PORTFOLIO_TARGET_DIR)"

	echo "|| copying release to server..."
	scp -r -i ~/.ssh/id_rsa ./$(LOCAL_DIRECTORY_PORTFOLIO)/* $(PORTFOLIO_SERVER_USER)@$(PORTFOLIO_SERVER_IP):$(PORTFOLIO_TARGET_DIR)

	echo "|| updating live release..."
	ssh -i ~/.ssh/id_rsa $(PORTFOLIO_SERVER_USER)@$(PORTFOLIO_SERVER_IP) "cp -rf $(PORTFOLIO_TARGET_DIR)/* $(PORTFOLIO_LIVE_DIR)"

	echo  "|| updating nginx config"
	ssh -i ~/.ssh/id_rsa root@$(PORTFOLIO_SERVER_IP) "cp /home/$(PORTFOLIO_SERVER_USER)/releases/live/$(DOMAIN).conf /etc/nginx/sites-available/$(DOMAIN)"

	echo "|| restarting nginx"
	ssh -i ~/.ssh/id_rsa root@$(PORTFOLIO_SERVER_IP) "sudo systemctl restart nginx"

	echo "|| successful release!"