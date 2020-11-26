#!/bin/bash

# Initiate log file.
echo '' > log.txt

echo "-----------------"
echo "| Welcome to CiviCRM installation script for Drupal 8."
echo "-----------------"
echo "| Author Jorge Alves - jorge@waat.eu."
echo "-----------------"
echo "| Let me know if it works for you!"

# Check if Core requirements are installed.
echo "-----------------"
echo "| Checking core requirements."
echo "-----------------"
echo "| PHP"
sleep 2
PHPVER=$(php -v | head -n 1 | cut -d " " -f 2)
PHPVERMAJOR=$(echo $PHPVER |  cut -d "." -f 1)
PHPVERMINOR=$(echo $PHPVER |  cut -d "." -f 2)
echo "PHP version: "$PHPVER
sleep 1
if [[ $PHPVERMAJOR == 5 || $PHPVERMINOR < 1 ]]
then
  echo "Your PHP version might be incompatible. Please check the requirements."
else
  echo "Your PHP version is compatible to run civicrm [OK]"
fi
sleep 1
# PHP Extensions
echo "| PHP Extensions"
echo "-----------------"
AVAILABLE_EXTENSIONS=$(dpkg -l | grep php$PHPVERMAJOR)
REQUIRED_EXT=(bcmath curl xml mbstring zip intl)
for i in "${REQUIRED_EXT[@]}"
do
  sleep 1
  echo "Checking for "$i
if grep -q "$i" <<< "$AVAILABLE_EXTENSIONS"; then
  echo "[OK]"
else
  echo "Extension is not available and its required! PHP"$PHPVERMAJOR"."$PHPVERMINOR-$i
  echo "Please refer to the documentation for more information."
  exit 1
fi
done

#Database.
MYSQL_LOCAL=$(mysql -V | cut -d " " -f 6 | cut -d "," -f 1)
MYSQLVERMAJ=$(echo $MYSQL_LOCAL | cut -d "." -f 1)
MYSQLVERMIN=$(echo $MYSQL_LOCAL | cut -d "." -f 2)
if [[ $MYSQLVERMIN < 6 ]]
then
  echo "Mysql is not compatible, please upgrade. Mysql ver "$MYSQL_LOCAL
  echo "Please refer to the documentation for more information."
  exit 1
  fi

# Create CiviCRM database.
echo "-----------------"
read -p $'Would you like to create an empty civicrm database? ([Y]es, [N]o)' -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
    read -p $'\x0aName of database to create:' CIVICRM_DATABASE
    read -p $'\x0aDatabase user:' CIVICRM_DATABASE_USER
    read -p $'\x0aDatabase user password:' CIVICRM_DATABASE_PASS
    mysql -u$CIVICRM_DATABASE_USER -p$CIVICRM_DATABASE_PASS -e "create database $CIVICRM_DATABASE" &>> log.txt
    grep -i '^Query\|^Warning\|^ERROR' log.txt
      if [ $? == 0 ]; then
        echo "Error in MySql."
        exit 1
      fi
    echo "Database created [OK]"
else
    read -p $'\x0aName of database:' CIVICRM_DATABASE
    read -p $'\x0aDatabase user:' CIVICRM_DATABASE_USER
    read -p $'\x0aDatabase user password:' CIVICRM_DATABASE_PASS
fi

echo '-----------------'
# Installing civicrm config installation.
echo 'CMS base url ex: http://mydrupal.site/'
read -p $'\x0aEnter CMS base url:' CMS_BASE_URL
read -p $'\x0aEnter prefered language (defaults to en_GB):' LANG_CIVICRM
if [[ -z ${LANG_CIVICRM} ]]
  then
    LANG_CIVICRM='en_GB'
fi

#Dummy data.
DUMMY_DATA=0
read -p $'\x0aPopulate Civicrm with dummy content: ([Y]es, [N]o)' -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
DUMMY_DATA=1
fi

sleep 1
echo ''
echo '-----------------'
echo '| Composer'
# Check if composer is installed.
composer -v &>/dev/null | grep 'Composer version'
     if [ !$? == 0 ]; then
       echo "Exiting: composer not install"
       exit 1
       fi
# Composer config and civicrm code.
echo 'Composer patching'
composer config extra.enable-patching true
sleep 1
echo 'Civicrm asset'
composer require civicrm/civicrm-asset-plugin:'~1.1'
sleep 1
echo 'Civicrm core packages'
composer require civicrm/civicrm-{core,packages,drupal-8}:'~5.29'
sleep 1
# Install cv cli.
echo '-----------------'
echo 'Installing cv cli'
sudo curl -LsS https://download.civicrm.org/cv/cv.phar -o /usr/local/bin/cv
sudo chmod +x /usr/local/bin/cv
sleep 1
echo '-----------------'
echo 'Installing translations'
# Install l10n and sql dependencies.
echo "-----------------"
CIVICRM_VERSION="5.31.1"
read -p $"Would you like to install the version $CIVICRM_VERSION ([Y]es, [N]o)" -n 1 -r
sleep 1
if [[ $REPLY =~ ^[Yy]$ ]]
then
  echo ''
  wget https://download.civicrm.org/civicrm-5.31.1-l10n.tar.gz
  tar -zxvf civicrm-5.31.1-l10n.tar.gz
  rm civicrm-5.31.1-l10n.tar.gz
else
  read -p $'Which version would you like to install (provide the full http path to the download tar.gz file)?' -n 1 -r
  NEW_FILE_URL=$REPLY
  wget $NEW_FILE_URL
  FILE_CIVICRM=$(echo $NEW_FILE_URL | rev | cut -d "/" -f 1 | rev)
  tar -zxvf $FILE_CIVICRM
  rm $FILE_CIVICRM
fi

# Moving files.
cd civicrm/
cp -R l10n/ ../vendor/civicrm/civicrm-core/
cp -R sql/ ../vendor/civicrm/civicrm-core/
cd ..
rm -rf civicrm/


echo '-----------------'
echo 'Installing'
cv core:install --cms-base-url="$CMS_BASE_URL" --lang="$LANG_CIVICRM" --db="mysql://$CIVICRM_DATABASE_USER:$CIVICRM_DATABASE_PASS@localhost:/$CIVICRM_DATABASE"  -m loadGenerated=$DUMMY_DATA -v

# Cleaning up.
rm log.txt

echo "We're done, you can now access your CiviCRM."
sleep 1
echo 'Bye!'
