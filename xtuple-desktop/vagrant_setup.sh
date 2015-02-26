#!/bin/sh

# fix for error message from Vagrant, but it may still show up
if `tty -s`; then
 mesg n
fi

# set xtuple source directory
XTUPLE_DIR=/home/vagrant/dev/xtuple/

# handy little function from install_script
cdir() {
  echo "Changing directory to $1"
  cd $1
}

exitEarly() {
  local RESULT=63
  if [ "$*" -gt 0 ] ; then
    RESULT=$1
    shift
  fi
  echo $*
  exit $RESULT
}

usage() {
  cat << EOUSAGE
$0 -h
$0 [ -p postgresversion ]
EOUSAGE
}

PGVER=9.3

while getopts "hp:" opt ; do
  case $opt in
    h) usage
       exit 0
       ;;
    p) PGVER=$OPTARG
       ;;
  esac
done

# install git
echo "Installing Git"
sudo apt-get install git -y

# this is temporary fix for the problem where Windows
# cannot translate the symlinks in the repository
echo "Creating symlink to lib folder"
cdir /home/vagrant/dev/xtuple/lib/
rm module
ln -s ../node_modules/ module
git update-index --assume-unchanged module

echo "Creating symlink to application folder"
cdir /home/vagrant/dev/xtuple/enyo-client/application/
rm lib
ln -s ../../lib/ lib
git update-index --assume-unchanged lib

cdir $XTUPLE_DIR
echo "Beginning install script"
bash scripts/install_xtuple.sh -d $PGVER

echo "Adding Vagrant PostgreSQL Access Rule"
echo "host all all  0.0.0.0/0 trust" | sudo tee -a /etc/postgresql/$PGVER/main/pg_hba.conf

echo "Restarting Postgres Database"
sudo service postgresql restart

##begin qtdev wizardry
cdir /home/vagrant/dev
sudo apt-get install -q -y libfontconfig1-dev libkrb5-dev libfreetype6-dev    \
               libx11-dev libxcursor-dev libxext-dev libxfixes-dev libxft-dev \
               libxi-dev libxrandr-dev libxrender-dev gcc make
sudo apt-get install -q -y --no-install-recommends \
               ubuntu-desktop unity-lens-applications unity-lens-files \
               gnome-panel firefox firefox-gnome-support \
               qt4-qmake libqt4-dev libqtwebkit-dev libqt4-sql-psql qtcreator
sudo chmod a+w /usr/lib/x86_64-linux-gnu/qt4/plugins/designer

echo "/home/vagrant/dev/qt-client/openrpt/lib
/home/vagrant/dev/qt-client/lib" | sudo tee /etc/ld.so.conf.d/xtuple.conf
sudo ldconfig

echo "Compiling OPENRPT dependency"
cdir /home/vagrant/dev/qt-client/openrpt
qmake                                   || exitEarly 1 "openrpt didn't qmake"
make -j4                                || exitEarly 1 "openrpt didn't build"
echo "Compiling CSVIMP dependency"
cdir ../csvimp
qmake                                   || exitEarly 1 "csvmip didn't qmake"
make -j4                                || exitEarly 1 "csvmip didn't build"
cdir ..
qmake                                   || exitEarly 1 "qt-client didn't qmake"
touch widgets/addressCluster.cpp   # force build/install of libxtuplewidgets.so
make -j4                                || exitEarly 1 "qt-client didn't build"

echo "Qt development environment finished!"
echo "To work in the Linux desktop immediately:"
echo "  host$ vagrant reload"
##end qtdev wizardry
