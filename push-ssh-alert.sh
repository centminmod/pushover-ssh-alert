#!/bin/bash
#####################################################################
# https://pushover.net/api
# /usr/local/bin/push-ssh-alert.sh
#####################################################################
# add to /etc/pam.d/sshd the line
# session optional pam_exec.so /usr/local/bin/push-ssh-alert.sh
#
# cp /etc/pam.d/sshd /etc/pam.d/sshd.bak
# sed -i '/session[ \t]*include[ \t]*password-auth/a session    optional     pam_exec.so /usr/local/bin/push-ssh-alert.sh' /etc/pam.d/sshd
#####################################################################

# Configuration Variables
PUSH_USER_KEY="your_pushover_user_key_here"
PUSH_API_TOKEN="your_pushover_app_token_here"
LOG_FILE="/var/log/ssh_login_notify.log"
PUSH_VERBOSE=1 # Set to 1 for verbose logging, 0 to disable

if [ -f "/etc/centminmod/pushover.ini" ]; then
  if [ -f /usr/bin/dos2unix ]; then
    dos2unix -q "/etc/centminmod/pushover.ini"
  fi
  source "/etc/centminmod/pushover.ini"
fi

# Function to handle logging
log_message() {
    if [[ "${PUSH_VERBOSE}" -eq 1 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG_FILE}"
    fi
}

# Gather additional info
MYTIMES=$(mytimes)
SSH_ALERTIP=$(echo $SSH_CLIENT | awk '{print $1}')
if [ -z "$SSH_ALERTIP" ]; then
  SSH_ALERTIP=$(grep 'sshd.*Accepted' /var/log/secure | tail -1 | awk '{print $11}')
fi
SSH_ALERTGEO=$(curl -4sL https://ipinfo.io/$SSH_ALERTIP/geo | sed -e 's|[{}]||' -e 's/\(^"\|"\)//g' -e 's|,||' -e 's| readme: https://ipinfo.io/missingauth||')

# Prepare the message
LOGIN_USER="$(whoami)"
HOSTNAME="$(hostname)"
DATE_TIME="$(date '+%d-%m-%Y %H:%M:%S')"
MESSAGE="SSH Login: ${LOGIN_USER} on ${HOSTNAME} at ${DATE_TIME} Location: ${SSH_ALERTGEO} Times: ${MYTIMES}"
TITLE="SSH Login Alert: ${LOGIN_USER} on ${HOSTNAME} at ${DATE_TIME}"

# Log the attempt with additional info
GET_PPID_INFO=$(ps -f -p $PPID)
log_message "SSH login attempt by ${LOGIN_USER} from ${SSH_ALERTIP}. Location: ${SSH_ALERTGEO}. Times: ${MYTIMES}"
log_message "SSH_CLIENT: $SSH_CLIENT"
log_message "SSH_CONNECTION: $SSH_CONNECTION"
log_message "Triggered by PID: $$, PPID: $PPID"
log_message "$GET_PPID_INFO"

# Send Notification
RESPONSE=$(curl -s \
  --form-string "token=${PUSH_API_TOKEN}" \
  --form-string "user=${PUSH_USER_KEY}" \
  --form-string "message=${MESSAGE}" \
  --form-string "title=${TITLE}" \
  https://api.pushover.net/1/messages.json)

# Log the response from Pushover
log_message "Notification sent. Response: ${RESPONSE}"

