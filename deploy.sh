#!/bin/sh

BUILD_TIME=`date`

echo Syncing deploy repo changes

cd public
git init
git add origin git@github.com:zorndorff/zorndorff.github.io.git
git pull origin master

cd ../
hugo --cleanDestinationDir

cd public
git commit -am "Content Update $BUILD_TIME"
git push origin master
