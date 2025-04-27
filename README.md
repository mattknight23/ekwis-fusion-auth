# Ekwis FusionAuth Setup

## Overview
This project provides a Dockerized setup for running [FusionAuth](https://fusionauth.io/) with a Postgres database and SMTP support, suitable for local development and production deployment on AWS. It now uses NGINX with Certbot (Let's Encrypt) for free SSL certificates, replacing Caddy.

---

## Prerequisites
- [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) installed and running
- (For production) AWS account with access to ECS, EC2, or similar, and AWS Secrets Manager
- A domain name pointed to your server (e.g., `auth.ekwis.com`)

---

## Environment Variables
Create a `.env` file in the project root with the following variables (see `.env.template` for examples):

```
# ----------- Postgres -----------
POSTGRES_PASSWORD=ChangeMe123

# ----------- SMTP (Outlook / M365) -----------
SMTP_HOST=smtp.office365.com
SMTP_PORT=587
SMTP_USERNAME=youruser@example.co.uk
SMTP_PASSWORD=your-app-password

# ----------- FusionAuth admin -----------
FA_ADMIN_EMAIL=matt@ekwis.com
FA_ADMIN_PASSWORD=SuperSecret123
```

- **Edit all values as appropriate for your environment.**
- `POSTGRES_PASSWORD` is required for the database.
- SMTP settings are required for email functionality (password resets, etc.).
- `FA_ADMIN_EMAIL` and `FA_ADMIN_PASSWORD` are used for the initial FusionAuth admin user.

---

## Local Testing: Using localhost and /etc/hosts

By default, the NGINX and Certbot setup expects to serve FusionAuth at `https://auth.ekwis.com`.

### To test locally before deploying to AWS:

1. **Map `auth.ekwis.com` to your local machine:**
   - Open Terminal and run:
     ```sh
     sudo nano /etc/hosts
     ```
   - Add this line to the bottom of the file:
     ```
     127.0.0.1 auth.ekwis.com
     ```
   - Save and exit (Ctrl+O, Enter, Ctrl+X in nano).

2. **(Optional) Remove the line after local testing** to avoid conflicts when you point your domain to AWS in production.

3. **Access FusionAuth locally:**
   - Visit [https://auth.ekwis.com](https://auth.ekwis.com) in your browser.
   - You may get a browser warning if the certificate is not yet valid or if you haven't completed DNS validation for Let's Encrypt. For full SSL testing, you must ensure Let's Encrypt can reach your local machine (requires port 80 open to the internet and public DNS pointing to your IP). For most local testing, you can use self-signed certs or accept the warning.

4. **For true Let's Encrypt SSL testing locally:**
   - You must expose your local port 80 to the internet (e.g., using [ngrok](https://ngrok.com/) or similar) and point your domain's DNS A record to your public IP. This is rarely needed for local dev; most users test SSL after deploying to AWS.

5. **For production:**
   - Remove the `/etc/hosts` entry.
   - Point your domain's DNS A record to your AWS deployment's public IP or load balancer.

---

## Running Locally (MacOS)

1. **Clone the repository and navigate to the project directory:**
   ```sh
   git clone <your-repo-url>
   cd ekwis-fusion-auth
   ```

2. **Create your `.env` file:**
   ```sh
   cp .env.template .env
   # Edit .env to set your secrets and credentials
   open -e .env  # or use your preferred editor
   ```

3. **Build and start the services:**
   ```sh
   docker-compose up --build
   ```
   - This will start Postgres, FusionAuth, and NGINX with Certbot.
   - NGINX will automatically attempt to obtain a Let's Encrypt SSL certificate for `auth.ekwis.com`.
   - FusionAuth will be available at [https://auth.ekwis.com](https://auth.ekwis.com) (after DNS is set up and certs are issued).

4. **Access FusionAuth:**
   - Go to [https://auth.ekwis.com](https://auth.ekwis.com)
   - Log in with the admin credentials you set in `.env` (`FA_ADMIN_EMAIL` / `FA_ADMIN_PASSWORD`)

5. **Stopping and Cleaning Up:**
   - To stop the services: Press `Ctrl+C` in your terminal.
   - To remove containers, networks, and volumes:
     ```sh
     docker-compose down -v
     ```

---

## NGINX + Certbot (Let's Encrypt) Details

- The custom NGINX image is built from `Dockerfile.nginx-certbot`.
- SSL certificates are automatically obtained and renewed for `auth.ekwis.com` using Certbot.
- The `certbot-init.sh` script handles certificate issuance and renewal.
- Volumes `certbot-www` and `letsencrypt` are used to persist challenge files and certificates.
- HTTP traffic is redirected to HTTPS.

---

## Production Deployment Plan (AWS)

### 1. Overview
- Use AWS ECS (Fargate or EC2) or EC2 directly to run the containers.
- Use AWS Secrets Manager to store sensitive environment variables (database password, SMTP credentials, admin credentials).
- Use `.env` for local/test, and inject secrets from AWS Secrets Manager in production.
- NGINX handles SSL with Let's Encrypt (no Caddy or ALB/ACM required).

### 2. Steps

#### a. Prepare AWS Resources
- Create an ECS cluster (Fargate recommended).
- Set up a public subnet and security group allowing ports 80 and 443.
- Point your domain's A record to the ECS service's public IP or load balancer.

#### b. Store Secrets in AWS Secrets Manager
- Create a secret (e.g., `ekwis-fusionauth-secrets`) with the following keys:
  - `POSTGRES_PASSWORD`
  - `SMTP_HOST`
  - `SMTP_PORT`
  - `SMTP_USERNAME`
  - `SMTP_PASSWORD`
  - `FA_ADMIN_EMAIL`
  - `FA_ADMIN_PASSWORD`

#### c. ECS Task Definition
- Use the public images for Postgres and FusionAuth.
- Build and push your custom NGINX+Certbot image to ECR (or build on ECS).
- Mount volumes for `/var/www/certbot` and `/etc/letsencrypt` in the NGINX container.
- Set environment variables from Secrets Manager.

#### d. Certbot DNS & HTTP Challenge
- Ensure port 80 is open and your domain points to the ECS service.
- Certbot will automatically obtain and renew certificates for `auth.ekwis.com`.

#### e. Service
- Create a service from your Task Definition.
- Set desired count to 1 (or more for HA).

#### f. Monitoring & Maintenance
- Certbot will auto-renew certificates via cron.
- Monitor logs for renewal issues.

---

## Notes
- For production, always use strong, unique passwords and rotate them regularly.
- Never commit your `.env` file or secrets to version control.
- For more information, see the [FusionAuth documentation](https://fusionauth.io/docs/) and [Certbot documentation](https://certbot.eff.org/). 