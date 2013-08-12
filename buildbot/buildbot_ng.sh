#!/bin/bash

set -e

# Include the config file
source config.sh
export PATH=$PATH

# Check the OS
case $OSTYPE in
	linux*)   osname='linux' ;;
	msys*)    osname='windows' ;;
	darwin*)  osname='macosx' ;;
	solaris*) osname='solaris' ;;
	bsd*)     osname='bsd' ;;
	*)        osname='unknown' ;;
esac

# Check the architecture
[ "$osname" == "macosx" ] && arch="i686" || arch=`uname -m`

# Today's date
ngalebuild=`date "+%Y-%m-%d"`

# One day before to get git changes
[ "$osname" == "macosx" ] && daybefore=`date -v -1d "+%Y-%m-%d"` || daybefore=`date "+%Y-%m-%d" --date '1 days ago'`

# Update, and build if we have changes
if [ doUpdate ]; then
	cd $repo

	# Get the buildnumber
	buildnumber=`cat build/sbBuildInfo.mk.in | grep BuildNumber= | sed -e 's/BuildNumber=//g'`
	
	# Get the version
	version=`cat build/sbBuildInfo.mk.in | grep SB_MILESTONE= | sed 's/SB_MILESTONE=//g'`
	
	# Get the branchname
	branchname=`cat build/sbBuildInfo.mk.in | grep SB_BRANCHNAME= | sed 's/SB_BRANCHNAME=//g'`

	# Check if we are on trunk
	[ "$branchname" != 'sb-trunk-oldxul' ] && { branchname=`echo $branchname | sed 's/Songbird//g'` }

	[ buildNgale ] && [ makePackage($version, $branchname, $buildnumber) ] && uploadPackages || echo "We encountered a build error."
else
	echo "No changes since last time, exiting."
fi

function doUpdate() {
	cd $repo

	# Clean up
	git reset --hard

	# Checkout the right branch
	git checkout $branch

	# Fetch changes from GitHub
	git fetch origin

	# Rebase on the origin
	git rebase origin/$branch

	# Get the hash for the last built version
	[ -f "$compiled/lastbuilt.txt" ] && lasthash=`cat "$compiled/lastbuilt.txt"` || lasthash="new" 
	
	# Get the current hash	
	lasthash=`git rev-parse HEAD`	
	
	# Return true if we need to rebuild
	[ "$curhash" != "$lasthash" ] && return 0 || return 1
}

function buildNgale() {
	cd $repo

	# Remove the old build
	make clean

	# Build!!!
	bash ./build.sh | tee "$repo/buildlog"

	# If everything worked...
	[ "`grep Succeeded buildlog`" ] && return 0 || return 1
}

function makePackage() {
	# Store the currently built hash as the last since it succeeded
	echo $curhash > "$compiled/lastbuilt.txt"

	mv compiled/dist compiled/Nightingale
	cd compiled

	changes=`git log --after={${daybefore}}`
	echo "Nightingale "$1" - branch "$2" - build "$3 > README.md
	echo "" >> README.md
	echo "Git source: <https://github.com/nightingale-media-player/nightingale-hacking/tree/"$branch">" >> README.md
	echo "" >> README.md
	echo "Changes:" >> README.md
	echo "" >> README.md

	if [ "$changes" == "" ]; then
		echo "none" >> README.md
		cat /dev/null > changes.txt
	else
		echo "$changes" >> README.md
		echo "$changes" > changes.txt
	fi

	if [ "$osname" == "windows" ]; then
		# Zip
		zip -r -9 nightingale-$1-$3_$osname-$arch.zip Nightingale
		
		# Making a md5sum
		md5sum nightingale-$1-$3_$osname-$arch.zip > nightingale-$1-$3_$osname-$arch.zip.md5
	fi
	
	if [ "$osname" == "linux" ]; then
		# Tar then bz2
		tar cvf nightingale-$1-$3_$osname-$arch.tar Nightingale
		bzip2 nightingale-$1-$3_$osname-$arch.tar

		# Making a md5 sum
		md5sum nightingale-$1-$3_$osname-$arch.tar.bz2 > nightingale-$1-$3_$osname-$arch.tar.bz2.md5
	fi

	# Creating a folder and moving the file to be reachable
	mkdir $compiled/$ngalebuild
	mkdir $compiled/$ngalebuild/addons

	[ "$osname" != "macosx" ] && mv nightingale-$1-$3_$osname-$arch.* $compiled/$ngalebuild
	mv changes.txt $compiled/$ngalebuild
	mv README.md $compiled/$ngalebuild

	# Unless we have binary addons, we should always use the Linux built ones
	mv xpi-stage/albumartlastfm/*.xpi $compiled/$ngalebuild/addons
	mv xpi-stage/audioscrobbler/*.xpi $compiled/$ngalebuild/addons
	mv xpi-stage/concerts/*.xpi $compiled/$ngalebuild/addons
	mv xpi-stage/mashTape/*.xpi $compiled/$ngalebuild/addons
	mv xpi-stage/shoutcast-radio/*.xpi $compiled/$ngalebuild/addons

	[ -d _built_installer ] && mv _built_installer/* $compiled/$ngalebuild

	# Remove the old local "latest" directory
	[ -d "$compiled/latest" ] && rm -rf "$compiled/latest/*" || mkdir "$compiled/latest"
	
	# Copy everything over to "latest" ...rsync because Macs are weird
	rsync -aPr $compiled/$ngalebuild/* $compiled/latest
	
	uploadPackages
}

function uploadPackages() {
	# Uploading on sourceforge.net
	cd $compiled
	rsync -e ssh $ngalebuild ${sfnetuser}@frs.sourceforge.net://home//pfs//project//ngale//${branchname}-Nightlies -r --progress
	rsync -e ssh latest ${sfnetuser}@frs.sourceforge.net://home//pfs//project//ngale//${branchname}-Nightlies -r --progress
	rsync -e ssh $ngalebuild/addons ngaleoss@getnightingale.com://home//ngaleoss//addon-files.getnightingale.com//xpis//nightlies -r --progress
}

exit 0
