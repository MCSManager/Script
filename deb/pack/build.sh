#!/bin/bash


echo "Building..."

# Find dpkg
if ! command -v dpkg;then
    echo "Error: dpkg not found"
    exit 1
fi

# Some prepare work
mv -f ../src/DEBIAN/postinst.sh ../src/DEBIAN/postinst
mv -f ../src/DEBIAN/preinst.sh ../src/DEBIAN/preinst
mv -f ../src/DEBIAN/prerm.sh ../src/DEBIAN/prerm

# Remove old files
echo "Remove old files..."
rm -rf ./*/DEBIAN/preinst
rm -rf ./*/DEBIAN/postinst
rm -rf ./*/DEBIAN/prerm
rm -rf ./*/etc

# Copy new files
echo "Copy new service files..."
cp -r -v ../src/etc/ ./amd64/etc/
cp -r -v ../src/etc/ ./arm64/etc/
cp -r -v ../src/etc/ ./arm/etc/
cp -r -v ../src/etc/ ./i386/etc/
cp -r -v ../src/etc/ ./ppc64le/etc/
cp -r -v ../src/etc/ ./s390x/etc/ 

echo "Copy new script files..."
cp -r -v ../src/DEBIAN/* ./amd64/DEBIAN/
cp -r -v ../src/DEBIAN/* ./arm64/DEBIAN/
cp -r -v ../src/DEBIAN/* ./arm/DEBIAN/
cp -r -v ../src/DEBIAN/* ./i386/DEBIAN/
cp -r -v ../src/DEBIAN/* ./ppc64le/DEBIAN/
cp -r -v ../src/DEBIAN/* ./s390x/DEBIAN/

# Set Premission
echo "Set Permission..."
chmod 775 ./*/DEBIAN/pre*
chmod 775 ./*/DEBIAN/post*
chown -R debian ./*

mv -f ../src/DEBIAN/postinst ../src/DEBIAN/postinst.sh
mv -f ../src/DEBIAN/preinst ../src/DEBIAN/preinst.sh
mv -f ../src/DEBIAN/prerm ../src/DEBIAN/prerm.sh
# OH THE SHIT CODE

# Build
if ! dpkg -b ./amd64/ MCSManager-amd64.deb; then
    echo "Error: Build amd64 arch deb failed"
    exit 1
fi
if ! dpkg -b ./arm/ MCSManager-arm.deb; then
    echo "Error: Build arm arch deb failed"
    exit 1
fi
if ! dpkg -b ./arm64/ MCSManager-arm64.deb; then
    echo "Error: Build arm64 arch deb failed"
    exit 1
fi
if ! dpkg -b ./i386/ MCSManager-i386.deb; then
    echo "Error: Build i386 arch deb failed"
    exit 1
fi
if ! dpkg -b ./ppc64le/ MCSManager-ppc64le.deb; then
    echo "Error: Build ppc64le arch deb failed"
    exit 1
fi
if ! dpkg -b ./s390x/ MCSManager-s390x.deb; then
    echo "Error: Build s390x arch deb failed"
    exit 1
fi

echo "Build complete"
