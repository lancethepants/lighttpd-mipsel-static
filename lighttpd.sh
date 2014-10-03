#!/bin/bash

set -e
set -x

mkdir ~/lighttpd && cd ~/lighttpd

BASE=`pwd`
SRC=$BASE/src
WGET="wget --prefer-family=IPv4"
export PREFIX=/opt
export DESTARCH=mipsel
DEST=$BASE$PREFIX
LDFLAGS="-L$DEST/lib -Wl,--gc-sections"
CPPFLAGS="-I$DEST/include"
CFLAGS="-mtune=mips32 -mips32 -ffunction-sections -fdata-sections"
export EXTRACFLAGS=$CFLAGS
CXXFLAGS=$CFLAGS
PATCHES=$(readlink -f $(dirname ${BASH_SOURCE[0]}))/patches
CONFIGURE="./configure --prefix=$PREFIX --host=mipsel-linux"
MAKE="make -j`nproc`"

mkdir -p $SRC

######## ####################################################################
# ZLIB # ####################################################################
######## ####################################################################

mkdir $SRC/zlib && cd $SRC/zlib
$WGET http://zlib.net/zlib-1.2.8.tar.gz
tar zxvf zlib-1.2.8.tar.gz
cd zlib-1.2.8

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
CROSS_PREFIX=mipsel-linux- \
./configure \
--prefix=$PREFIX

$MAKE
make install DESTDIR=$BASE

######### ###################################################################
# BZIP2 # ###################################################################
######### ###################################################################

mkdir $SRC/bzip2 && cd $SRC/bzip2
$WGET http://www.bzip.org/1.0.6/bzip2-1.0.6.tar.gz
tar zxvf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6

$WGET https://raw.githubusercontent.com/lancethepants/tomatoware/master/patches/bzip2.patch
$WGET https://raw.githubusercontent.com/lancethepants/tomatoware/master/patches/bzip2_so.patch

patch < bzip2.patch
patch < bzip2_so.patch

$MAKE
$MAKE -f Makefile-libbz2_so

make install PREFIX=$DEST

########### #################################################################
# NCURSES # #################################################################
########### #################################################################

mkdir $SRC/curses && cd $SRC/curses
$WGET http://ftp.gnu.org/pub/gnu/ncurses/ncurses-5.9.tar.gz
tar zxvf ncurses-5.9.tar.gz
cd ncurses-5.9

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-widec \
--disable-database \
--with-fallbacks=xterm

$MAKE
make install DESTDIR=$BASE
ln -s libncursesw.a $DEST/lib/libcurses.a
ln -s libncursesw.a $DEST/lib/libncurses.a

############### #############################################################
# LIBREADLINE # #############################################################
############### #############################################################

mkdir $SRC/libreadline && cd $SRC/libreadline
$WGET ftp://ftp.cwru.edu/pub/bash/readline-6.2.tar.gz
tar zxvf readline-6.2.tar.gz
cd readline-6.2

$WGET https://raw.github.com/lancethepants/tomatoware/master/patches/readline.patch
patch < readline.patch

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--disable-shared

$MAKE
make install DESTDIR=$BASE

######## ####################################################################
# PCRE # ####################################################################
######## ####################################################################

mkdir $SRC/pcre && cd $SRC/pcre
$WGET ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.36.tar.gz
tar zxvf pcre-8.36.tar.gz
cd pcre-8.36

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-pcregrep-libz \
--enable-pcregrep-libbz2 \
--enable-pcretest-libreadline \
--enable-unicode-properties

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

mkdir -p $SRC/openssl && cd $SRC/openssl
$WGET http://www.openssl.org/source/openssl-1.0.1i.tar.gz
tar zxvf openssl-1.0.1i.tar.gz
cd openssl-1.0.1i

cat << "EOF" > openssl.patch
--- Configure_orig      2013-11-19 11:32:38.755265691 -0700
+++ Configure   2013-11-19 11:31:49.749650839 -0700
@@ -402,6 +402,7 @@ my %table=(
 "linux-alpha+bwx-gcc","gcc:-O3 -DL_ENDIAN -DTERMIO::-D_REENTRANT::-ldl:SIXTY_FOUR_BIT_LONG RC4_CHAR RC4_CHUNK DES_RISC1 DES_UNROLL:${alpha_asm}:dlfcn:linux-shared:-fPIC::.so.\$(SHLIB_MAJOR).\$(SHLIB_MINOR)",
 "linux-alpha-ccc","ccc:-fast -readonly_strings -DL_ENDIAN -DTERMIO::-D_REENTRANT:::SIXTY_FOUR_BIT_LONG RC4_CHUNK DES_INT DES_PTR DES_RISC1 DES_UNROLL:${alpha_asm}",
 "linux-alpha+bwx-ccc","ccc:-fast -readonly_strings -DL_ENDIAN -DTERMIO::-D_REENTRANT:::SIXTY_FOUR_BIT_LONG RC4_CHAR RC4_CHUNK DES_INT DES_PTR DES_RISC1 DES_UNROLL:${alpha_asm}",
+"linux-mipsel", "gcc:-DL_ENDIAN -DTERMIO -O3 -mtune=mips32 -mips32 -fomit-frame-pointer -Wall::-D_REENTRANT::-ldl:BN_LLONG RC4_CHAR RC4_CHUNK DES_INT DES_UNROLL BF_PTR:${mips32_asm}:o32:dlfcn:linux-shared:-fPIC::.so.\$(SHLIB_MAJOR).\$(SHLIB_MINOR)",

 # Android: linux-* but without -DTERMIO and pointers to headers and libs.
 "android","gcc:-mandroid -I\$(ANDROID_DEV)/include -B\$(ANDROID_DEV)/lib -O3 -fomit-frame-pointer -Wall::-D_REENTRANT::-ldl:BN_LLONG RC4_CHAR RC4_CHUNK DES_INT DES_UNROLL BF_PTR:${no_asm}:dlfcn:linux-shared:-fPIC::.so.\$(SHLIB_MAJOR).\$(SHLIB_MINOR)",
EOF

patch < openssl.patch

./Configure linux-mipsel \
-ffunction-sections -fdata-sections -Wl,--gc-sections \
--prefix=$PREFIX shared zlib \
--with-zlib-lib=$DEST/lib \
--with-zlib-include=$DEST/include

make CC=mipsel-linux-gcc AR="mipsel-linux-ar r" RANLIB=mipsel-linux-ranlib
make install CC=mipsel-linux-gcc AR="mipsel-linux-ar r" RANLIB=mipsel-linux-ranlib INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl

####### #####################################################################
# LUA # #####################################################################
####### #####################################################################

mkdir $SRC/lua && cd $SRC/lua
$WGET http://www.lua.org/ftp/lua-5.1.5.tar.gz
tar zxvf lua-5.1.5.tar.gz
cd lua-5.1.5

CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
make linux \
CC="mipsel-linux-gcc" \
LD="mipsel-linux-ar r" \
MYLDFLAGS=$LDFLAGS \
INSTALL_TOP=$DEST

make install INSTALL_TOP=$DEST

########### #################################################################
# LIBXML2 # #################################################################
########### #################################################################

mkdir $SRC/libxml2 && cd $SRC/libxml2
$WGET ftp://xmlsoft.org/libxml2/libxml2-2.9.1.tar.gz
tar zxvf libxml2-2.9.1.tar.gz
cd libxml2-2.9.1

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--without-python

$MAKE
make install DESTDIR=$BASE

ln -s libxml2/libxml/ $DEST/include/libxml

########## ##################################################################
# SQLITE # ##################################################################
########## ##################################################################

mkdir $SRC/sqlite && cd $SRC/sqlite
$WGET http://sqlite.org/2014/sqlite-autoconf-3080600.tar.gz
tar zxvf sqlite-autoconf-3080600.tar.gz
cd sqlite-autoconf-3080600

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE

$MAKE
make install DESTDIR=$BASE

########### #################################################################
# LIBUUID # #################################################################
########### #################################################################

mkdir $SRC/libuuid && cd $SRC/libuuid
$WGET http://downloads.sourceforge.net/project/libuuid/libuuid-1.0.3.tar.gz
tar zxvf libuuid-1.0.3.tar.gz
cd libuuid-1.0.3

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE

$MAKE
make install DESTDIR=$BASE

######## ####################################################################
# GDBM # ####################################################################
######## ####################################################################

mkdir $SRC/gdbm && cd $SRC/gdbm
$WGET ftp://ftp.gnu.org/gnu/gdbm/gdbm-1.11.tar.gz
tar zxvf gdbm-1.11.tar.gz
cd gdbm-1.11

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS=$CFLAGS \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE

$MAKE
make install DESTDIR=$BASE

############ ################################################################
# LIGHTTPD # ################################################################
############ ################################################################

mkdir $SRC/lighttpd && cd $SRC/lighttpd
$WGET http://download.lighttpd.net/lighttpd/releases-1.4.x/lighttpd-1.4.35.tar.gz
tar zxvf lighttpd-1.4.35.tar.gz
cd lighttpd-1.4.35

sed -i 's,typedef int socklen_t,//typedef int socklen_t,g' ./src/base.h
patch ./src/Makefile.in < $PATCHES/Makefile.in.patch
cp $PATCHES/plugin-static.h ./src

LDFLAGS=$LDFLAGS \
CPPFLAGS=$CPPFLAGS \
CFLAGS="-DLIGHTTPD_STATIC -std=c99 $CFLAGS" \
CXXFLAGS=$CXXFLAGS \
$CONFIGURE \
--enable-static \
--enable-shared \
LUA_CFLAGS=$DEST/include \
LUA_LIBS="$DEST/lib" \
SQLITE_CFLAGS=$DEST/include \
SQLITE_LIBS="$DEST/lib" \
--with-openssl \
--with-openssl-includes="$DEST/include" \
--with-openssl-libs="$DEST/lib" \
--with-kerberos5 \
--with-pcre \
--with-zlib \
--with-bzip2 \
--with-lua \
--with-gdbm \
--with-webdav-props \
--with-webdav-locks \
ac_cv_lib_crypto_BIO_f_base64=yes \
ac_cv_lib_ssl_SSL_new=yes \
--enable-extra-warnings

$MAKE LIBS="-all-static -lcrypt -lm -lz -lbz2 -lsqlite3 -llua -lxml2 -luuid -lgdbm" PCRE_LIB=-lpcre
make install DESTDIR=$BASE/lighttpd
