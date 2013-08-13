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

# Get our functions
source functions.sh

# Are we forcing a build or force uploading? -f is build and upload
[ ! -z $1 ] && [ $1 = "-f" ] && build=1 || build=doUpdate

# Update, and build if we have changes
if $build; then
	cd $repo

	# Get the buildnumber
	buildnumber=`cat build/sbBuildInfo.mk.in | grep BuildNumber= | sed -e 's/BuildNumber=//g'`
	
	# Get the version
	version=`cat build/sbBuildInfo.mk.in | grep SB_MILESTONE= | sed 's/SB_MILESTONE=//g'`
	
	# Get the branchname
	branchname=`cat build/sbBuildInfo.mk.in | grep SB_BRANCHNAME= | sed 's/SB_BRANCHNAME=//g'`

	# Check if we are on trunk
	[ "$branchname" != 'sb-trunk-oldxul' ] && branchname=`echo $branchname | sed 's/Songbird//g'`

	# Build, package, and upload if we don't hit any errors
	buildNgale && makePackage $version $branchname $buildnumber && uploadPackages && echo "Buildbot complete." || echo "Build, packaging, or upload error." && exit 1
else
	echo "No changes since last time, exiting."
	exit 0
fi
