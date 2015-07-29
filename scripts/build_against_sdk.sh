#!/usr/bin/env bash
set -u -e

: '
On linux depends on node and:

    sudo apt-get update
    sudo apt-get install pkg-config build-essential zlib1g-dev
'

ARGS=""
CURRENT_DIR="$( cd "$( dirname $BASH_SOURCE )" && pwd )"
mkdir -p $CURRENT_DIR/../sdk
cd $CURRENT_DIR/../
export PATH=$(pwd)/node_modules/.bin:${PATH}
cd sdk
BUILD_DIR="$(pwd)"
UNAME=$(uname -s);

if [[ ${1:-false} != false ]]; then
    ARGS=$1
fi

function upgrade_clang {
    echo "adding clang + gcc-4.8 ppa"
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    CLANG_VERSION="3.4"
    if [[ $(lsb_release --release) =~ "12.04" ]]; then
        sudo add-apt-repository "deb http://llvm.org/apt/precise/ llvm-toolchain-precise-${CLANG_VERSION} main"
    fi
    wget -O - http://llvm.org/apt/llvm-snapshot.gpg.key|sudo apt-key add -
    echo "updating apt"
    sudo apt-get update -y -qq
    echo "installing clang-${CLANG_VERSION}"
    apt-cache policy clang-${CLANG_VERSION}
    sudo apt-get install -y clang-${CLANG_VERSION}
    echo "installing C++11 compiler"
    if [[ $(lsb_release --release) =~ "12.04" ]]; then
        echo 'upgrading libstdc++'
        sudo apt-get install -y libstdc++6 libstdc++-4.8-dev
    fi
    if [[ ${LTO:-false} != false ]]; then
        echo "upgrading binutils-gold"
        sudo apt-get install -y -qq binutils-gold
        if [[ ! -h "/usr/lib/LLVMgold.so" ]] && [[ ! -f "/usr/lib/LLVMgold.so" ]]; then
            echo "symlinking /usr/lib/llvm-${CLANG_VERSION}/lib/LLVMgold.so"
            sudo ln -s /usr/lib/llvm-${CLANG_VERSION}/lib/LLVMgold.so /usr/lib/LLVMgold.so
        fi
        if [[ ! -h "/usr/lib/libLTO.so" ]] && [[ ! -f "/usr/lib/libLTO.so" ]]; then
            echo "symlinking /usr/lib/llvm-${CLANG_VERSION}/lib/libLTO.so"
            sudo ln -s /usr/lib/llvm-${CLANG_VERSION}/lib/libLTO.so /usr/lib/libLTO.so
        fi
        # TODO - needed on trusty for pkg-config
        # since 'binutils-gold' on trusty does not switch
        # /usr/bin/ld to point to /usr/bin/ld.gold like it does
        # in the precise package
        #sudo rm /usr/bin/ld
        #sudo ln -s /usr/bin/ld.gold /usr/bin/ld
    fi
    # for bjam since it can't find a custom named clang-3.4
    if [[ ! -h "/usr/bin/clang" ]] && [[ ! -f "/usr/bin/clang" ]]; then
        echo "symlinking /usr/bin/clang-${CLANG_VERSION}"
        sudo ln -s /usr/bin/clang-${CLANG_VERSION} /usr/bin/clang
    fi
    if [[ ! -h "/usr/bin/clang++" ]] && [[ ! -f "/usr/bin/clang++" ]]; then
        echo "symlinking /usr/bin/clang++-${CLANG_VERSION}"
        sudo ln -s /usr/bin/clang++-${CLANG_VERSION} /usr/bin/clang++
    fi
    # prefer upgraded clang
    if [[ -f "/usr/bin/clang++-${CLANG_VERSION}" ]]; then
        export CC="/usr/bin/clang-${CLANG_VERSION}"
        export CXX="/usr/bin/clang++-${CLANG_VERSION}"
    else
        export CC="/usr/bin/clang"
        export CXX="/usr/bin/clang++"
    fi
}

function upgrade_gcc {
    echo "adding gcc-4.8 ppa"
    sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
    echo "updating apt"
    sudo apt-get update -y -qq
    echo "installing C++11 compiler"
    sudo apt-get install -y gcc-4.8 g++-4.8
    if [[ "${CXX#*'clang'}" == "$CXX" ]]; then
        export CC="gcc-4.8"
        export CXX="g++-4.8"
    fi
}

COMPRESSION="tar.bz2"
SDK_URI="https://cartodb-node-binary-redhat.s3.amazonaws.com/dist/dev"
platform=$(echo $UNAME | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/")

if [[ "${CXX11:-false}" != false ]]; then
    # mapnik 3.x / c++11 enabled
    HASH="1702-g65bd9e6"
else
    # mapnik 2.3.x / c++11 not enabled
    HASH="676-g065214e"
fi

if [[ ${platform} == 'linux' ]]; then
    upgrade_clang
fi

if [[ $platform == 'darwin' ]]; then
    platform="macosx"
fi

TARBALL_NAME="mapnik-${platform}-sdk-v2.2.0-${HASH}"
REMOTE_URI="${SDK_URI}/${TARBALL_NAME}.${COMPRESSION}"
export MAPNIK_SDK=${BUILD_DIR}/${TARBALL_NAME}
export PATH=${MAPNIK_SDK}/bin:${PATH}
export PKG_CONFIG_PATH=${MAPNIK_SDK}/lib/pkgconfig

echo "looking for ~/projects/mapnik-packaging/osx/out/dist/${TARBALL_NAME}.${COMPRESSION}"
if [ -f "$HOME/projects/mapnik-packaging/osx/out/dist/${TARBALL_NAME}.${COMPRESSION}" ]; then
    echo "copying over ${TARBALL_NAME}.${COMPRESSION}"
    cp "$HOME/projects/mapnik-packaging/osx/out/dist/${TARBALL_NAME}.${COMPRESSION}" .
else
    if [ ! -f "${TARBALL_NAME}.${COMPRESSION}" ]; then
        echo "downloading ${REMOTE_URI}"
        curl -f -o "${TARBALL_NAME}.${COMPRESSION}" "${REMOTE_URI}"
    fi
fi

if [ ! -d ${TARBALL_NAME} ]; then
    echo "unpacking ${TARBALL_NAME}"
    tar xf ${TARBALL_NAME}.${COMPRESSION}
fi

if [[ ! `which pkg-config` ]]; then
    echo 'pkg-config not installed'
    exit 1
fi

if [[ ! `which node` ]]; then
    echo 'node not installed'
    exit 1
fi

if [[ $UNAME == 'Linux' ]]; then
    readelf -d $MAPNIK_SDK/lib/libmapnik.so
    #sudo apt-get install chrpath -y
    #chrpath -r '$ORIGIN/' ${MAPNIK_SDK}/lib/libmapnik.so
    export LDFLAGS='-Wl,-z,origin -Wl,-rpath=\$$ORIGIN'
else
    otool -L $MAPNIK_SDK/lib/libmapnik.dylib
fi

cd ../
npm install node-pre-gyp
MODULE_PATH=$(node-pre-gyp reveal module_path ${ARGS})
# note: dangerous!
rm -rf ${MODULE_PATH}
npm install --build-from-source ${ARGS} --clang=1
npm ls
# copy lib
cp ${MAPNIK_SDK}/lib/libmapnik.* ${MODULE_PATH}
# copy plugins
cp -r ${MAPNIK_SDK}/lib/mapnik ${MODULE_PATH}
# copy share data
mkdir -p ${MODULE_PATH}/share/
cp -r ${MAPNIK_SDK}/share/mapnik ${MODULE_PATH}/share/
# generate new settings
echo "
var path = require('path');
module.exports.paths = {
    'fonts': path.join(__dirname, 'mapnik/fonts'),
    'input_plugins': path.join(__dirname, 'mapnik/input')
};
module.exports.env = {
    'ICU_DATA': path.join(__dirname, 'share/mapnik/icu'),
    'GDAL_DATA': path.join(__dirname, 'share/mapnik/gdal'),
    'PROJ_LIB': path.join(__dirname, 'share/mapnik/proj')
};
" > ${MODULE_PATH}/mapnik_settings.js

# cleanup
rm -rf $BUILD_DIR
set +u +e
