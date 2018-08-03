#!/bin/sh

BUILD_TIME=`date`

echo Syncing deploy repo changes
cp CNAME public/
hugo

cd public
git add -A
git commit -am "Content Update $BUILD_TIME"
git pull origin master
git push origin master
