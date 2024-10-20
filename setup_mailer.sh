#!/bin/bash

# Make sure the script is being run with sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo privileges."
  exit 1
fi

# Prompt for user inputs
read -p "Enter the custom myhostname (or press Enter for localhost): " myhostname
myhostname=${myhostname:-localhost}

read -p "Enter the sender email address: " sender_email
read -p "Enter the sender name: " sender_name
read -p "Enter the email subject: " email_subject
read -p "Enter the path to your email list file (e.g., germany.txt): " email_list

# Update package list and install Postfix
echo "Updating package list and installing Postfix..."
sudo apt-get update -y
sudo apt-get install postfix -y

# Install tmux for session persistence
echo "Installing tmux for persistent sessions..."
sudo apt-get install tmux -y

# Backup the original Postfix config file
echo "Backing up the original Postfix main.cf..."
sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.backup

# Remove the current main.cf to replace with custom config
echo "Removing current main.cf..."
sudo rm /etc/postfix/main.cf

# Create a new Postfix main.cf file with the desired configuration
echo "Creating a new Postfix main.cf file..."
sudo tee /etc/postfix/main.cf > /dev/null <<EOL
# Postfix main configuration file

# Set the local machine to handle email delivery
myhostname = $myhostname

# Ensure Postfix listens only on localhost (no external network interfaces)
inet_interfaces = loopback-only

# Disable relay host to ensure no external SMTP server is used
relayhost = 

# Define destinations that Postfix will deliver to (localhost only)
mydestination = localhost

# Disable SMTP authentication, since we're only sending locally
smtp_sasl_auth_enable = no
smtpd_sasl_auth_enable = no
smtp_sasl_security_options = noanonymous

# Disable TLS, since we're not using external servers
smtp_tls_security_level = none

# Basic Postfix directories and settings
queue_directory = /var/spool/postfix
command_directory = /usr/sbin
daemon_directory = /usr/lib/postfix/sbin

# No size limits on mailboxes
mailbox_size_limit = 0
recipient_delimiter = +
EOL

# Restart Postfix to apply the changes
echo "Restarting Postfix service..."
sudo service postfix restart

# Install mailutils for sending emails via Postfix
echo "Installing mailutils..."
sudo apt-get install mailutils -y

# Create a sample HTML email content (email.html)
echo "Creating email.html with email content..."
cat > email.html <<EOL
<html>
<body>
  <h1>PrimeRewardSpot iPhone 16 Pro</h1>
  <p>Congratulations! You are eligible to win an iPhone 16 Pro.</p>
</body>
</html>
EOL

# Create the sending script (send.sh)
echo "Creating send.sh for bulk email sending..."
cat > send.sh <<EOL
#!/bin/bash

# Loop through each email in the provided email list
while IFS= read -r email; do
  echo "Sending email to: \$email"
  
  # Send the email using Postfix with HTML content
  cat <<EOF | /usr/sbin/sendmail -t
To: \$email
From: $sender_name <$sender_email>
Subject: $email_subject
MIME-Version: 1.0
Content-Type: text/html

\$(cat email.html)
EOF

done < $email_list
EOL

# Make the send.sh script executable
chmod +x send.sh

# Create a tmux session and run the send.sh script in it
echo "Starting tmux session and running send.sh..."
tmux new-session -d -s mail_session "./send.sh"

# Print instructions for reattaching to the tmux session
echo "Your email sending process is running in the background with tmux."
echo "To reattach to the session, use: tmux attach -t mail_session"
