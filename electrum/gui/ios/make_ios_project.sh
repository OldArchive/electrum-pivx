#!/bin/bash

/usr/bin/env python3 --version | grep -q " 3.6"
if [ "$?" != "0" ]; then
	if /usr/bin/env python3 --version; then
		echo "WARNING:: Creating the Briefcase-based Xcode project for iOS requires Python 3.6"
		echo "We will proceed anyway -- but if you get errors, try switching to Python 3.6"
	else
		echo "ERROR: Python 3.6 is required"
		exit 1
	fi
fi

/usr/bin/env python3 -m pip show setuptools > /dev/null
if [ "$?" != "0" ]; then
	echo "ERROR: Please install setupdools like so: sudo python3 -m pip install briefcase"
	exit 2
fi

/usr/bin/env python3 -m pip show briefcase > /dev/null
if [ "$?" != "0" ]; then
	echo "ERROR: Please install briefcase like so: sudo python3 -m pip install briefcase"
	exit 3
fi

/usr/bin/env python3 -m pip show cookiecutter > /dev/null
if [ "$?" != "0" ]; then
	echo "ERROR: Please install cookiecutter like so: sudo python3 -m pip install cookiecutter"
	exit 4
fi

/usr/bin/env python3 -m pip show pbxproj > /dev/null
if [ "$?" != "0" ]; then
	echo "ERROR: Please install pbxproj like so: sudo python3 -m pip install pbxproj"
	exit 5
fi

if [ -d iOS ]; then
	echo "Warning: 'iOS' directory exists. All modifications will be lost if you continue."
	echo "Continue? [y/N]?"
	read reply
	if [ "$reply" != "y" ]; then
		echo "Fair enough. Exiting..."
		exit 0
	fi
	echo "Cleaning up old iOS dir..."
	rm -fr iOS
fi

if [ -d Electrum/electrum ]; then
	echo "Deleting old Electrum/electrum..."
	rm -fr Electrum/electrum
fi

echo "Pulling 'electrum' into project from ../../"
if [ ! -d ../../locale ]; then
    cp -R ../../../deterministic-build/electrum-locale/locale ../../
fi

rsync -av --progress ../.. Electrum/electrum --exclude ../../gui

find Electrum -name \*.pyc -exec rm -f {} \; 

echo ""
echo "Building Briefcase-Based iOS Project..."
echo ""

python3 setup.py ios 
if [ "$?" != 0 ]; then
	echo "An error occurred running setup.py"
	exit 4
fi

infoplist="iOS/Electrum/Electrum-Info.plist"
if [ -f "${infoplist}" ]; then
	echo ""
	echo "Adding custom keys to ${infoplist} ..."
	echo ""
	plutil -insert "NSAppTransportSecurity" -xml '<dict><key>NSAllowsArbitraryLoads</key><true/></dict>' -- ${infoplist} 
	if [ "$?" != "0" ]; then
		echo "Encountered error adding custom key NSAppTransportSecurity to plist!"
		exit 1
	fi
	#plutil -insert "UIBackgroundModes" -xml '<array><string>fetch</string></array>' -- ${infoplist}
	#if [ "$?" != "0" ]; then
	#	echo "Encountered error adding custom key UIBackgroundModes to plist!"
	#	exit 1
	#fi
	longver=`git describe --tags`
	if [ -n "$longver" ]; then
		shortver=`echo "$longver" | cut -f 1 -d -`
		plutil -replace "CFBundleVersion" -string "$longver" -- ${infoplist} && plutil -replace "CFBundleShortVersionString" -string "$shortver" -- ${infoplist}
		if [ "$?" != "0" ]; then
			echo "Encountered error adding custom keys to plist!"
			exit 1
		fi
	fi
	# UILaunchStoryboardName -- this is required to get proper iOS screen sizes due to iOS being quirky AF
	if [ -e "Resources/LaunchScreen.storyboard" ]; then 
		plutil -insert "UILaunchStoryboardName" -string "LaunchScreen" -- ${infoplist}
		if [ "$?" != "0" ]; then
			echo "Encountered an error adding LaunchScreen to Info.plist!"
			exit 1
		fi
	fi
	# Camera Usage key -- required!
	plutil -insert "NSCameraUsageDescription" -string "The camera is needed to scan QR codes" -- ${infoplist}

	# Stuff related to being able to open .txn and .txt files (open transaction from context menu in other apps)
	plutil -insert "CFBundleDocumentTypes" -xml '<array><dict><key>CFBundleTypeIconFiles</key><array/><key>CFBundleTypeName</key><string>Transaction</string><key>LSItemContentTypes</key><array><string>public.plain-text</string></array></dict></array>' -- ${infoplist}
	plutil -insert "UTExportedTypeDeclarations" -xml '<array><dict><key>UTTypeConformsTo</key><array><string>public.plain-text</string></array><key>UTTypeDescription</key><string>Transaction</string><key>UTTypeIdentifier</key><string>org.electrum.Electrum.txn</string><key>UTTypeSize320IconFile</key><string>signed@2x</string><key>UTTypeSize64IconFile</key><string>signed</string><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>txn</string><string>txt</string></array></dict></dict></array>' -- ${infoplist}
	plutil -insert "UTImportedTypeDeclarations" -xml '<array><dict><key>UTTypeConformsTo</key><array><string>public.plain-text</string></array><key>UTTypeDescription</key><string>Transaction</string><key>UTTypeIdentifier</key><string>org.electrum.Electrum.txn</string><key>UTTypeSize320IconFile</key><string>signed@2x</string><key>UTTypeSize64IconFile</key><string>signed</string><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>txn</string><string>txt</string></array></dict></dict></array>' -- ${infoplist}
	plutil -insert 'CFBundleURLTypes' -xml '<array><dict><key>CFBundleTypeRole</key><string>Viewer</string><key>CFBundleURLName</key><string>bitcoincash</string><key>CFBundleURLSchemes</key><array><string>bitcoincash</string></array></dict></array>' -- ${infoplist}
	plutil -replace 'UIRequiresFullScreen' -bool NO -- ${infoplist}
	plutil -insert 'NSFaceIDUsageDescription' -string 'FaceID is used for wallet authentication' -- ${infoplist}
	plutil -insert 'ITSAppUsesNonExemptEncryption' -bool NO -- ${infoplist}

	# Un-comment the below to enforce only portrait orientation mode on iPHone
	#plutil -replace "UISupportedInterfaceOrientations" -xml '<array><string>UIInterfaceOrientationPortrait</string></array>' -- ${infoplist}
	# Because we are using FullScreen = NO, we must support all interface orientations
	plutil -replace 'UISupportedInterfaceOrientations' -xml '<array><string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string><string>UIInterfaceOrientationLandscapeRight</string><string>UIInterfaceOrientationPortraitUpsideDown</string></array>' -- ${infoplist}
	plutil -insert 'UIViewControllerBasedStatusBarAppearance' -bool NO -- ${infoplist}
	plutil -insert 'UIStatusBarStyle' -string 'UIStatusBarStyleLightContent' -- ${infoplist}
	plutil -insert 'NSPhotoLibraryAddUsageDescription' -string 'Required to save QR images to the photo library' -- ${infoplist}
	plutil -insert 'NSPhotoLibraryUsageDescription' -string 'Required to save QR images to the photo library' -- ${infoplist}
fi

if [ -d overrides/ ]; then
	echo ""
	echo "Applying overrides..."
	echo ""
	(cd overrides && cp -fpvR * ../iOS/ && cd ..)
fi

stupid_launch_image_grr="iOS/Electrum/Images.xcassets/LaunchImage.launchimage"
if [ -d "${stupid_launch_image_grr}" ]; then
	echo ""
	echo "Removing deprecated LaunchImage stuff..."
	echo ""
	rm -fvr "${stupid_launch_image_grr}"
fi

patches=patches/*.patch
if [ -n "$patches" ]; then
	echo ""
	echo "Applying patches..."
	echo ""
	for p in $patches; do
		[ -e $p ] && patch -p 1 < $p
	done
fi

# Get latest rubicon with all the patches from Github
echo ""
echo "Updating rubicon-objc to latest from forked repository on github..."
echo ""
[ -e scratch ] && rm -fr scratch
mkdir -v scratch || exit 1
cd scratch || exit 1
git clone http://www.github.com/cculianu/rubicon-objc
gitexit="$?"
cd rubicon-objc
git checkout send_super_fix
gitexit2="$?"
cd ..
cd ..
[ "$gitexit" != "0" -o "$gitexit2" != 0 ] && echo '*** Error crabbing the latest rubicon off of github' && exit 1
rm -fr iOS/app_packages/rubicon/objc
cp -fpvr scratch/rubicon-objc/rubicon/objc iOS/app_packages/rubicon/ 
[ "$?" != "0" ] && echo '*** Error copying rubicon files' && exit 1
rm -fr scratch

xcode_file="Electrum.xcodeproj/project.pbxproj" 
echo ""
echo "Mogrifying Xcode .pbxproj file to use iOS 10.0 deployment target..."
echo ""
sed  -E -i original1 's/(.*)IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+(.*)/\1IPHONEOS_DEPLOYMENT_TARGET = 10.0\2/g' "iOS/${xcode_file}" && \
  sed  -n -i original2 '/ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME/!p' "iOS/${xcode_file}"
if [ "$?" != 0 ]; then
	echo "Error modifying Xcode project file iOS/$xcode_file... aborting."
	exit 1
else
	echo ".pbxproj mogrifid ok."
fi

xcode_target=Electrum

echo ""
echo "Adding HEADER_SEARCH_PATHS to Xcode .pbxproj..."
echo ""
python3 -m pbxproj flag -t "${xcode_target}" iOS/"${xcode_file}" -- HEADER_SEARCH_PATHS '"$(SDK_DIR)"/usr/include/libxml2'
if [ "$?" != 0 ]; then
	echo "Error adding libxml2 to HEADER_SEARCH_PATHS... aborting."
	exit 1
fi

resources=Resources/*
if [ -n "$resources" ]; then
	echo ""
	echo "Adding Resurces/ and CustomCode/ to project..."
	echo ""
	cp -fRav Resources CustomCode iOS/
	(cd iOS && python3 -m pbxproj folder -t "${xcode_target}" -r -i "${xcode_file}" Resources)
	if [ "$?" != 0 ]; then
		echo "Error adding Resources to iOS/$xcode_file... aborting."
		exit 1
	fi
	(cd iOS && python3 -m pbxproj folder -t "${xcode_target}" -r "${xcode_file}" CustomCode)
	if [ "$?" != 0 ]; then
		echo "Error adding CustomCode to iOS/$xcode_file... aborting."
		exit 1
	fi
fi

so_crap=`find iOS/app_packages -iname \*.so -print`
if [ -n "$so_crap" ]; then
	echo ""
	echo "Deleting .so files in app_packages since they don't work anyway on iOS..."
	echo ""
	for a in $so_crap; do
		rm -vf $a
	done
fi

echo ''
echo '**************************************************************************'
echo '*                                                                        *'
echo '*   Operation Complete. An Xcode project has been generated in "iOS/"    *'
echo '*                                                                        *'
echo '**************************************************************************'
echo ''
echo '  IMPORTANT!'
echo '        Now you need to manually add AVFoundation and libxml2.tbd to the '
echo '        project Frameworks else you will get build errors!'
echo ''
echo '  Also note:'
echo '        Modifications to files in iOS/ will be clobbered the next    '
echo '        time this script is run.  If you intend on modifying the     '
echo '        program in Xcode, be sure to copy out modifications from iOS/ '
echo '        manually or by running ./copy_back_changes.sh.'
echo ''
echo '  Caveats for App Store & Ad-Hoc distribution:'
echo '        "Release" builds submitted to the app store fail unless the '
echo '        following things are done in "Build Settings" in Xcode: '
echo '            - "Strip Debug Symbols During Copy" = NO '
echo '            - "Strip Linked Product" = NO '
echo '            - "Strip Style" = Debugging Symbols '
echo '            - "Enable Bitcode" = NO '
echo ''

