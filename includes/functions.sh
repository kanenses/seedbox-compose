#!/bin/bash
function intro() {
	echo ""
	echo "########################################################"
	echo "###                                                  ###"
	echo "###                  SEEDBOX-COMPOSE                 ###"
	echo "###   Deploy a complete Seedbox with Docker easily   ###"
	echo "###               Author : bilyboy785                ###"
	echo "###                Version : 1.0                     ###"
	echo "###       Publication date : 2017-03-26              ###"
	echo "###            Update date : 2017-03-27              ###"
	echo "###                                                  ###"
	echo "########################################################"
	echo ""
}

function upgrade_system() {
	echo -e "${BLUE}## UPGRADING ##${NC}"
	apt-get install -y gawk apt-transport-https
	SYSTEM=$(gawk -F= '/^NAME/{print $2}' /etc/os-release)
	rm /etc/apt/sources.list
	if [[ $SYSTEM == "Debian GNU/Linux" ]]; then
		cat includes/sources.list.debian >> /etc/apt/sources.list
		wget -O- https://www.dotdeb.org/dotdeb.gpg | apt-key add -
		wget -O- http://nginx.org/keys/nginx_signing.key | apt-key add -
	elif [[ $SYSTEM == "Ubuntu" ]]; then
		cp includes/sources.list.ubuntu /etc/apt/sources.list
	fi
	apt-get update && apt-get upgrade -y
}

function install_docker() {
	echo -e "${BLUE}## DOCKER ##${NC}"
	dpkg-query -l docker >> /dev/null
  	if [ $? != 0 ]; then
		echo "Docker is not installed, it will be installed !"
		echo "deb https://apt.dockerproject.org/repo debian-jessie main" > $DOCKERLIST
		apt update
		apt install docker docker-engine docker-compose
		echo ""
	else
		echo "Docker is already installed !"
		echo ""
	fi
}

function install_letsencrypt() {
	echo -e "${BLUE}## LETS ENCRYPT ##${NC}"
	if [ ! -d "/etc/letsencrypt" ]; then
		read -p "Lets'Encrypt is not installed. Do you plan to generate certificates ? (y/n) : " installLetsencrypt
		apt install git-core
		git clone https://github.com/letsencrypt/letsencrypt /opt/letsencrypt
		echo ""
	else
		echo "Let's Encrypt is already installed !"
		echo ""
	fi
}

function choose_services() {
	echo -e "${BLUE}## SERVICES ##${NC}"
	echo -e "${BWHITE}Nginx, MariaDB, Nextcloud, RuTorrent/rTorrent, Sonarr, Radarr, Jackett and Docker WebUI will be installed by default !${NC}"
	echo "--> Choose wich services you want to add (default set to no) : "
	read -p "	* Plex and PlexPy ? (y/n) : " PLEXINSTALL
	read -p "	* ZeroBin ? (y/n) : " ZEROBININSTALL
	read -p "	* Lufi & Lutim ? (y/n) : " LUFILUTIMINSTALL
	if [ $PLEXINSTALL = "y" ]; then
		cat includes/plex-docker.yml >> docker-compose-base.yml
		cat includes/plexpy-docker.yml >> docker-compose-base.yml
	fi
	if [ $ZEROBININSTALL = "y" ]; then
		cat includes/zerobin-docker.yml >> docker-compose-base.yml
	fi
	if [ $LUFILUTIMINSTALL = "y" ]; then
		cat includes/lufi-docker.yml >> docker-compose-base.yml
		cat includes/lutim-docker.yml >> docker-compose-base.yml
	fi
	echo ""
}

function define_parameters() {
	echo -e "${BLUE}## USER INFORMATIONS ##${NC}"
	read -p "	* Choose user wich run dockers (default $USER). If user doesn't exist, it will be added : " CURRUSER
	if [[ $CURRUSER == "" ]]; then
		USERID=$(id -u $USER)
		GRPID=$(id -g $USER)
	else
		egrep "^$CURRUSER" /etc/passwd >/dev/null
		if [ $? -eq 0 ]; then
			USERID=$(id -u $CURRUSER)
			GRPID=$(id -g $CURRUSER)
		else
			read -s -p "	Enter password : " PASSWORD
			PASS=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
			useradd -m -p $PASS $CURRUSER > /dev/null 2>&1
			[ $? -eq 0 ] && echo "User has been added to system !" || echo "Failed to add a user !"
			USERID=$(id -u $CURRUSER)
			GRPID=$(id -g $CURRUSER)
		fi
	fi
	CURRTIMEZONE=$(cat /etc/timezone)
	read -p "	* Please specify your Timezone (default $CURRTIMEZONE) : " TIMEZONEDEF
	if [[ $TIMEZONEDEF == "" ]]; then
		TIMEZONE=$CURRTIMEZONE
	else
		TIMEZONE=$TIMEZONEDEF
	fi
	echo -e "${BLUE}## GENERAL INFORMATIONS ##${NC}"
	read -p "	Please enter an email address : " CONTACTEMAIL
	read -p "	Enter your domain name : " DOMAIN
	# echo -e "${BLUE}## MARIADB INFORMATIONS ##${NC}"
	# read -p "	Choose a password for MySQL root user : " MARIADBROOTPASSWD
	# read -p "	Choose a password for Nextcloud Database (dbnextcloud) : " MARIADBNEXTCLOUDPASSWD 
	# echo -e "${BLUE}## NEXTCLOUD INFORMATIONS ##${NC}"
	# read -p "	Choose an admin username for Nextcloud : " NEXTCLOUDADMIN
	# read -p "	Choose an admin password for Nextcloud : " NEXTCLOUDADMINPASSWD
	# read -p "	Choose a max upload size for Nextcloud (Ex: 10G or 128M) : " MAXUPLOADSIZENEXTCLOUD
	
	## Function to replace parameters in docker-compose file
	replace_parameters $TIMEZONE $USERID $GRPID $CONTACTEMAIL $DOMAIN # $MARIADBROOTPASSWD $MARIADBNEXTCLOUDPASSWD $NEXTCLOUDADMIN $NEXTCLOUDADMINPASSWD $MAXUPLOADSIZENEXTCLOUD
}

function replace_parameters() {
	DOCKERCOMPOSE='docker-compose-base.yml'
	CLOUDDOMAIN="cloud.$5"
	SECRET=$(date +%s | md5sum | head -c 32)
	sed -i "s|%TIMEZONE%|$1|g" $DOCKERCOMPOSE
	sed -i "s|%UID%|$2|g" $DOCKERCOMPOSE
	sed -i "s|%GID%|$3|g" $DOCKERCOMPOSE
	# sed -i "s|%LUFI_LUTIM_CONTACT%|$4|g" $DOCKERCOMPOSE
	# sed -i "s|%CLOUD_DOMAIN%|$CLOUDDOMAIN|g" $DOCKERCOMPOSE
	# sed -i "s|%MYSQL_ROOT_PASSWD%|$6|g" $DOCKERCOMPOSE
	# sed -i "s|%MYSQL_NEXTCLOUD_PASSWD%|$7|g" $DOCKERCOMPOSE
	# sed -i "s|%NEXTCLOUD_ADMIN_USER%|$8|g" $DOCKERCOMPOSE
	# sed -i "s|%NEXTCLOUD_ADMIN_PASSWD%|$9|g" $DOCKERCOMPOSE
	# sed -i "s|%SECRET%|$SECRET|g" $DOCKERCOMPOSE
	cp $DOCKERCOMPOSE docker-compose.yml
	echo ""
}

function docker_compose() {
	echo -e "${BLUE}## DOCKERCOMPOSE ##${NC}"
	echo "	* Starting docker..."
	service docker restart
	echo "	* Docker-composing"
	docker-compose up -d
}

function add_user() {
	# Script to add a user to Linux system
	if [ $(id -u) -eq 0 ]; then
		read -p "Enter username : " USERNAME
		read -s -p "Enter password : " PASSWORD
		egrep "^$USERNAME" /etc/passwd >/dev/null
		if [ $? -eq 0 ]; then
			echo "$USERNAME exists!"
			exit 1
		else
			PASS=$(perl -e 'print crypt($ARGV[0], "password")' $PASSWORD)
			useradd -m -p $PASS $USERNAME
			[ $? -eq 0 ] && echo "User has been added to system !" || echo "Failed to add a user !"
		fi
	else
		echo "Only root may add a user to the system"
		exit 2
	fi
}
