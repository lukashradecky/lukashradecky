##############################################
# Log
log_cesta=nextcloud_instalace.log

# Parametry php
memory_limit=666M
post_max_size=4G
upload_max_filesize=4G
max_input_time=3600
max_execution_time=3600

# NextCloud Path
cesta=/var/www/html		 # DEFAULT PRO APACHE! 
cesta_data=/var/nextcloud/data

# Timezone
nastavitpasmo=1               # ON/OFF
casovepasmo=Europe/Prague

# Network interface
zarizeni=eth0

#Vlastníka adresářů lze nastavit na řádku 38
#Cestu k php.ini lze nastavit na řádku 259
###############################################
# 

nextcloud_url=http://81.2.233.169/nextcloud-16.0.3.zip
#nextcloud_url=https://download.nextcloud.com/server/releases/nextcloud-16.0.3.zip
nextcloud_soubor=nextcloud-16.0.3.zip

ip4=$(/sbin/ip -o -4 addr list $zarizeni | awk '{print $4}' | cut -d/ -f 1) #ip adresa - bude přidána do trusted domains
dbheslo=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1) #heslo uživatele databáze
adminheslo=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1) #heslo uživatele admin - nextcloud

distro=$(cat /etc/os-release)
cat /etc/os-release >> $log_cesta

#### Uživatel a skupina
case "$distro" in
	*"Debian GNU/Linux 9"*)
	distro="Debian 9"
	uzivatel=www-data
	skupina=www-data
	;;

	*"Debian GNU/Linux 10"*)
	distro="Debian 10"
	uzivatel=www-data
	skupina=www-data
	;;

	*"CentOS Linux 7"*)
	distro="CentOS 7"
        uzivatel=apache
        skupina=apache
	;;

        *"Ubuntu 18.04"*)
        distro="Ubuntu 18.04"
        uzivatel=www-data
        skupina=www-data
        ;;

	*)
	distro="nevim"
	;;
esac

GREEN="\033[1;32m"
RED="\033[1;31m"
NOCOLOR="\033[0m"

if [ "$distro" = "nevim" ]; then
	echo Only Debian 9/10, CentOS 7 and Ubuntu 18.04 is supported.
	echo -e ${RED}Bye.${NOCOLOR}
	exit 1
fi

################################################

check()
{
if [ $? != 0 ]; then
	echo -e "${RED}[ERR]${NOCOLOR} ${LINENO}"
	echo "- Chyba! ${LINENO}" >> $log_cesta
	exit 1
else
	echo -e "${GREEN}[OK]${NOCOLOR}"
fi
}

#clear
echo -e ${GREEN}--------------------------------------------------------------------------------
echo -e ${RED}NextCloud storage will be installed on your machine.
echo 
echo It includes installing Apache2, MySQL, PHP with extensions, certbot and Nextcloud.
echo If Apache2 was installed before and is running some sites, you should consider editing install path and Apache vhosts.
echo -e ${GREEN}--------------------------------------------------------------------------------
echo
echo -e ${NOCOLOR}IP address: $ip4 \($zarizeni\)
echo -e Installation folder: $cesta ${RED}\< current folder content will be deleted!${NOCOLOR}
echo Data path: $cesta_data
echo
echo Files owner: $uzivatel:$skupina
echo PHP config: memory_limit=$memory_limit, post_max_size=$post_max_size, upload_max_filesize=$upload_max_filesize, max_input_time=$max_input_time, max_execution_time=$max_execution_time
echo Timezone: $casovepasmo
echo
echo Values may be changed by editing prompts in the script if needed.


echo -e ${GREEN}
echo Distro detected:
echo $distro

echo -e ${RED}Do you wish to continue?
echo -e !Content of $cesta will be deleted!${NOCOLOR}
read -p "Continue (y/n)? " CONT

if [ "$CONT" != "y" ]; then
	echo Bye.
	exit 1;
fi

if [ $nastavitpasmo = 1 ]; then timedatectl set-timezone $casovepasmo; fi


case $distro in
	"Debian 9") #####################
        echo - Adding stretch-backports main to /etc/apt/sources.list.d/stretch-backports.list...
        echo "deb http://deb.debian.org/debian stretch-backports main" | tee /etc/apt/sources.list.d/stretch-backports.list >> $log_cesta
        check

        echo - Adding GPG key https://packages.sury.org/php/apt.gpg...
        wget -q https://packages.sury.org/php/apt.gpg -O- | apt-key add - >> $log_cesta
        check

        echo - Adding https://packages.sury.org/php/ stretch main to /etc/apt/sources.list.d/ondrej.list...
        echo "deb https://packages.sury.org/php/ stretch main" | tee /etc/apt/sources.list.d/ondrej.list >> $log_cesta
        check

        echo - Installing apt-transport-https and ca-certificates...
        apt-get install apt-transport-https ca-certificates -y >> $log_cesta
        check

	echo - Updating package db...
	apt-get update -y >> $log_cesta
	check

	echo - Upgrading packages...
	apt-get upgrade -y >> $log_cesta
	check
	;;

	"Debian 10") #####################
	echo - Updating package db...
	apt-get update -y >> $log_cesta
	check

	echo - Upgrading packages...
	apt-get upgrade -y >> $log_cesta
	check
	;;

	"CentOS 7") #######################
	echo - Adding repo remi7...
	yum localinstall http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y >> $log_cesta
	check

	echo - Installing yum-utils...
	yum install epel-release yum-utils -y >> $log_cesta
	check

	echo - Disabling repo remi-php54...
	yum-config-manager --disable remi-php54 -y >> $log_cesta

	echo - Enabling repo remi-php73...
	yum-config-manager --enable remi-php73 -y >> $log_cesta
	check

	echo - Upgrading packages...
	yum update -y >> $log_cesta
	check
	;;

        "Ubuntu 18.04") #####################
	echo - Installing software-properties-common...
	apt-get install software-properties-common -y >> $log_cesta
	check

        echo - Adding repo ppa:ondrej\/php...
        add-apt-repository ppa:ondrej/php -y >> $log_cesta
        check

        echo - Adding repo universe...
        add-apt-repository universe -y >> $log_cesta
        check

	echo - Adding repo ppa:certbot\/certbot...
	add-apt-repository ppa:certbot/certbot -y >> $log_cesta
	check

        echo - Updating package db...
        apt-get update -y >> $log_cesta
        check

        echo - Upgrading packages...
        apt-get upgrade -y >> $log_cesta
        check
        ;;

esac

#

echo - Installing apache2, php, mariadb-server, certbot a and dependencies...
case $distro in
	"Debian 10")
	apt-get install apache2 mariadb-server apt-transport-https libapache2-mod-php php php-xml php-curl php-gd php-cgi php-cli php-zip php-mysql php-mbstring php-intl php-imagick wget unzip sudo certbot python-certbot-apache -t buster-backports -y >> $log_cesta
	;;
	"Debian 9")
	apt-get install apache2 mariadb-server apt-transport-https libapache2-mod-php php php-xml php-curl php-gd php-cgi php-cli php-zip php-mysql php-mbstring php-intl php-imagick wget unzip sudo certbot python-certbot-apache -t stretch-backports -y >> $log_cesta
	;;
	"CentOS 7")
	yum install httpd mariadb-server php php-xml php-curl php-gd php-cgi php-cli php-zip php-mysql php-mbstring php-intl php-imagick wget unzip sudo certbot python2-certbot-apache -y >> $log_cesta
	;;
        "Ubuntu 18.04")
        apt-get install apache2 mariadb-server apt-transport-https libapache2-mod-php php php-xml php-curl php-gd php-cgi php-cli php-zip php-mysql php-mbstring php-intl php-imagick wget unzip sudo certbot python-certbot-apache -y >> $log_cesta
        ;;

esac

check
########################################################
if [ "$distro" = "CentOS 7" ]; then
	echo - Starting apache2...
	systemctl start httpd -q >> $log_cesta
	check

	echo - Enabling apache2...
	systemctl enable httpd -q >> $log_cesta
	check
else
	echo - Starting apache2...
	systemctl start apache2 -q >> $log_cesta
	check

	echo - Enabling apache2...
	systemctl enable apache2 -q >> $log_cesta
	check
fi

echo - Starting mariadb...
systemctl start mariadb -q >> $log_cesta
check

echo - Enabling mariadb...
systemctl enable mariadb -q >> $log_cesta
check
#clear

phpmajor=`php -r 'echo PHP_MAJOR_VERSION;;'`
phpminor=`php -r 'echo PHP_MINOR_VERSION;;'`

if [ "$distro" = "CentOS 7" ]; then
	phpini=/etc/php.ini #cesta php.ini pro centos7
else
	phpini=/etc/php/$phpmajor.$phpminor/apache2/php.ini #cesta php.ini pro ostatní distra
fi



#echo "<?php phpinfo(); ?>" > $cesta/php_info.php
#curl -q http://localhost/test.php|grep php.ini|grep Loaded|sed 's/<tr><td class="e">Loaded Configuration File <\/td><td class="v">//'|sed 's/ <\/td><\/tr>//' <<<<<<<<<
#phpini=$(curl -q http://localhost/test.php|grep php.ini|grep Loaded|sed 's/<tr><td class="e">Loaded Configuration File <\/td><td class="v">//'|sed 's/ <\/td><\/tr>//')
#rm $cesta/php_info.php

#phpini=$(php -i | grep 'php.ini' | grep 'Loaded Configuration File'| sed 's/Loaded Configuration File => //') CLI :(



for key in memory_limit post_max_size upload_max_filesize max_input_time max_execution_time
do
 sed -i "s/^\($key\).*/\1 $(eval echo = \${$key})/" $phpini >> $log_cesta
done

##########################################################
if [ "$distro" = "CentOS 7" ]; then
	service httpd restart
else
	service apache2 restart
fi
##########################################################
echo -e ${RED}Enter name of db to create:${NOCOLOR} [nextcloud]
read nazevdb
if [ "$nazevdb" = "" ]; then
        nazevdb=nextcloud
fi

mysqlshow "$nazevdb" > /dev/null 2>&1 && exist=1 || exist=0
while [ "$exist" != "0" ]
do
        echo -e "${RED}Database $nazevdb already exist. Enter another name of DB:${NOCOLOR}"
        read nazevdb
        if [ "$nazevdb" = "" ]; then
		nazevdb=nextcloud
	fi
	mysqlshow "$nazevdb" > /dev/null 2>&1 && exist=1 || exist=0
done
echo -e ${GREEN}[OK]${NOCOLOR}

echo -e ${RED}Enter username for new DB user:${NOCOLOR} [nextcloud]
read uzivateldb
if [ "$uzivateldb" = "" ]; then
        uzivateldb=nextcloud
 fi

exist="$(mysql -u root -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$uzivateldb')")"
while [ "$exist" != "0" ]
do  
        echo -e "${RED}DB user $uzivateldb already exists. Enter another name for DB user:${NOCOLOR}"
        read uzivateldb
        if [ "$uzivateldb" = "" ]; then
                uzivateldb=nextcloud
        fi
	exist="$(mysql -u root -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$uzivateldb')")"
 
 ######################################
done 
echo -e ${GREEN}[OK]${NOCOLOR}


echo - Creating db $nazevdb...
echo "CREATE DATABASE $nazevdb;" | mysql -u root >> $log_cesta
check

echo - Creating db user $uzivateldb...
echo "CREATE USER '$uzivateldb'@'localhost' IDENTIFIED BY '$dbheslo';" | mysql -u root >> $log_cesta
check

echo - Grant privs to $uzivateldb for $nazevdb...
echo "GRANT ALL PRIVILEGES ON $nazevdb.* TO '$uzivateldb'@'localhost';" | mysql -u root >> $log_cesta
check

echo - Flushing...
echo "FLUSH PRIVILEGES;" | mysql -u root >> $log_cesta
check

echo - Deleting content of $cesta...
rm -r $cesta/*

echo - Downloading Nextcloud archive...
wget -P $cesta $nextcloud_url
check

echo - Extracting NextCloud archive...
unzip -q $cesta/$nextcloud_soubor -d $cesta >> $log_cesta
check

echo - Moving NextCloud to $cesta...
shopt -s dotglob
mv $cesta/nextcloud/* $cesta >> $log_cesta
check

echo - Deleting archive Nextcloud...
rm $cesta/nextcloud -r >> $log_cesta
rm $cesta/$nextcloud_soubor >> $log_cesta
check

##čertbot
clear
echo -e ${GREEN}
echo --------------------------------------------------------------------------------
echo In this point you can generate your own SSL certificate Let\'s Encrypt.
echo DNS entry A - domain.cz a www.domain.cz must points to public IP adress of this machine $ip4.
echo
echo -e ${RED}You can skip this step by hitting Enter. You can still visit your server entering IP as URL.${NOCOLOR}
echo -e ${GREEN}--------------------------------------------------------------------------------
echo
echo -e ${RED}Enter FQDN domain name - ex:domain.cz:${NOCOLOR}
read domena

clear
if [ "$domena" != "" ]; then
echo
echo -e ${GREEN}---------------------------------------------------------------------------------------------
echo CA will verify if domain entry A $domena and www.$domena points to $ip4.
echo
echo -e Then certbot will ask following questions - answer the second if you do not understand:${NOCOLOR}
echo Which virtual host would you like to choose?
echo -e ${GREEN}2: 000-default-le-ssl.conf${NOCOLOR}
echo
echo Please choose whether or not to redirect HTTP traffic to HTTPS, removing HTTP access.
echo -e ${GREEN}2: Redirect${RED}
echo -e ${GREEN}---------------------------------------------------------------------------------------------
echo -e ${RED}
echo -e Continue by hitting Enter${NOCOLOR}
read
certbot --apache -d $domena -d www.$domena
if [ $? != 0 ]; then
        echo -e "${RED}Certificate could not be issued... Check your domain DNS settings:${NOCOLOR}"
        echo "$domena typ:A hodnota:$ip4 "
        echo "www.$domena typ:A hodnota:$ip4"
        echo
        echo -e "${GREEN}You can try to issue certificate later by typing:${NOCOLOR}"
        echo certbot --apache -d $domena www.$domena
        echo "- Chyba certbot! ${LINENO}" >> $log_cesta
else
        echo "[OK]"
fi
echo
echo -e ${RED}Continue by hitting Enter${NOCOLOR}
read
fi

clear


echo - Creating NextCloud config...
echo "<?php
\$AUTOCONFIG = array(
\"directory\"     => \"$cesta_data\",
\"dbtype\"        => \"mysql\",
\"dbname\"        => \"$nazevdb\",
\"dbuser\"        => \"$uzivateldb\",
\"dbpass\"        => \"$dbheslo\",
\"dbhost\"        => \"localhost\",
\"dbtableprefix\" => \"\",
\"adminlogin\"    => \"admin\",
\"adminpass\"     => \"$adminheslo\",
\"trusted_domains\" =>
  array (
    0 => \"localhost\",
    1 => \"$ip4\",
    2 => \"$domena\",
    3 => \"www.$domena\",
  ),

);" > $cesta/config/autoconfig.php;
check

echo - Changing owner for Nextcloud install path...
chown $uzivatel:$skupina $cesta -R >> $log_cesta
check

echo - Setting CHMOD 750 for Nextcloud install path...
chmod 750 $cesta >> $log_cesta
check

echo - Creating data directory $cesta_data...
mkdir -p $cesta_data >> $log_cesta
check

echo - Changing owner for NextCloud data dir...
chown $uzivatel:$skupina $cesta_data >> $log_cesta
check

echo - Setting CHMOD 750 for Nextcloud data dir...
chmod 750 $cesta_data >> $log_cesta
check

echo - Installing NextCloud...
sudo -u $uzivatel php $cesta/index.php >> $log_cesta
check

clear
echo
echo -e ${GREEN}------------------- Installation was done -------------------
echo -e Open ${RED}http://$ip4/${GREEN} in your browser.
if [ "$domena" != "" ]; then
echo -e Nextcloud is also configured for access from ${RED}http://$domena${GREEN}.
fi
echo
echo Admin login details:
echo -e Uživatel: ${RED}admin${GREEN}
echo -e Heslo: ${RED}$adminheslo${GREEN}
echo
echo -e Best practise is to restart the machine now.${NOCOLOR}

echo Uživatel databáze: $uzivateldb >> $log_cesta
echo Heslo databáze: $dbheslo >> $log_cesta
echo Název databáze: $nazevdb >> $log_cesta
echo Server: localhost >> $log_cesta
echo Heslo do Nextcloud uživatele admin: $adminheslo >> $log_cesta
