#!/bin/bash
#
# ZNC Installer
#
# Originally written for QuickBox.io by liara
#
# QuickBox Copyright (C) 2017 QuickBox.io
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.

DISTRO=$(lsb_release -is)
CODENAME=$(lsb_release -cs)
if [[ -f /tmp/.install.lock ]]; then
  OUTTO="/root/logs/install.log"
else
  OUTTO="/root/logs/swizzin.log"
fi

echo "Installing ZNC. Please wait ... " >> ${OUTTO} 2>&1
echo "" >> ${OUTTO} 2>&1
echo "" >> ${OUTTO} 2>&1
useradd znc -m -s /bin/bash
passwd znc -l >> ${OUTTO} 2>&1

if [[ $DISTRO == Debian ]]; then
  . /etc/swizzin/sources/functions/backports
  check_debian_backports
  cat > /etc/apt/preferences.d/znc <<ZNCP
Package: *znc*
Pin: release a=${CODENAME}-backports
Pin-Priority: 500
ZNCP
elif [[ $DISTRO == Ubuntu ]]; then
  add-apt-repository --yes ppa:teward/znc >> ${OUTTO} 2>&1
fi
  apt-get update -q -y >> ${OUTTO} 2>&1
  apt-get install znc -q -y >> ${OUTTO} 2>&1
  #sudo -u znc crontab -l | echo -e "*/10 * * * * /usr/bin/znc >/dev/null 2>&1\n@reboot /usr/bin/znc >/dev/null 2>&1" | crontab -u znc - > /dev/null 2>&1
  cat > /etc/systemd/system/znc.service <<ZNC
[Unit]
Description=ZNC, an advanced IRC bouncer
After=network-online.target
     
[Service]
ExecStart=/usr/bin/znc -f
User=znc
Restart=always
     
[Install]
WantedBy=multi-user.target
ZNC
systemctl enable znc
  echo "#### ZNC configuration will now run. Please answer the following prompts ####"
  sleep 5
  sudo -H -u znc znc --makeconf
  killall -u znc znc > /dev/null 2>&1
  sleep 1
  if [[ -f /install/.panel.lock ]]; then
    echo "$(grep Port /home/znc/.znc/configs/znc.conf | sed -e 's/^[ \t]*//')" > /srv/panel/db/znc.txt
    echo "$(grep SSL /home/znc/.znc/configs/znc.conf | sed -e 's/^[ \t]*//')" >> /srv/panel/db/znc.txt
  fi
  # Check for LE cert, and copy it if available.
  chkhost="$(find /etc/nginx/ssl/* -maxdepth 1 -type d | cut -f 5 -d '/')"
  if [[ -n $chkhost ]]; then
    defaulthost=$(grep -m1 "server_name" /etc/nginx/sites-enabled/default | awk '{print $2}' | sed 's/;//g')
    cat /etc/nginx/ssl/"$defaulthost"/{key,fullchain}.pem > /home/znc/.znc/znc.pem
    crontab -l > newcron.txt | sed -i  "s#cron#cron --post-hook \"cat /etc/nginx/ssl/"$defaulthost"/{key,fullchain}.pem > /home/znc/.znc/znc.pem\"#g" newcron.txt | crontab newcron.txt | rm newcron.txt
  fi
  systemctl start znc
  touch /install/.znc.lock
echo "#### ZNC now installed! ####"
