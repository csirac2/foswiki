#!/bin/bash

LOGFILE=${0%sh}log
exec > >(tee $LOGFILE)
exec 2>&1
exec 3>>$LOGFILE

apacheUser=`awk -F: '/^w/{print $1}' /etc/passwd`
id -u $apacheUser >/dev/null || (echo -e "Could not determine apache user. Found:\n$apacheUser";exit 1)
[ -z "$FOSWIKI_HOME" ] && (echo "No FOSWIKI_HOME set. Please set it and restart this script"; exit 1)
[ -d $FOSWIKI_HOME ] || (echo "FOSWIKI_HOME points to $FOSWIKI_HOME, which is not a directory. Please check it and restart this script"; exit 1)
if [ -d $1 ]; then
    INSTALL_ARGS="$@"
fi
pushd $FOSWIKI_HOME >&3
[ -f lib/LocalSite.cfg ] || hasNoLocalSite=1
if [ -n "$hasNoLocalSite" ]; then
    if [ -f lib/LocalSite.cfg.save ]; then
        cp -p lib/LocalSite.cfg.save lib/LocalSite.cfg
    else
        echo "You haven't configured Foswiki yet, or you didn't backup your LocalSite.cfg in LocalSite.cfg.save."
        exit 3
    fi
fi
sudo chown -R $LOGNAME $FOSWIKI_HOME >&3
find . -type l -exec rm {} \;
rm -rf $FOSWIKI_HOME/data/Temp*
perl pseudo-install.pl -e developer $INSTALL_ARGS >&3
mkdir -p $FOSWIKI_HOME/{{data,working,pub},test/unit/{fake_{templates,data},},lib/Foswiki/Plugins}/
sudo chown -R $apacheUser $FOSWIKI_HOME/{{data,working,pub},test/unit/{fake_{templates,data},},lib/Foswiki/Plugins}/
date '+Starting tests at %Y-%m-%d %H:%M:%S'
cd test/unit && sudo -u $apacheUser perl ../bin/TestRunner.pl -clean "${@:-FoswikiSuite.pm}"
cd -
date '+Finished tests at %Y-%m-%d %H:%M:%S'
sudo chown -R $LOGNAME $FOSWIKI_HOME/{{data,working,pub},test/unit/,lib/Foswiki/Plugins}/
perl pseudo-install.pl -u developer $INSTALL_ARGS >&3
rm -f $FOSWIKI_HOME/working/tmp/{Foswiki,cgisess_}*
[ -n "$hasNoLocalSite" ] && rm lib/LocalSite.cfg
popd >&3
exec 3>&-
if grep 'All tests passed' $LOGFILE >/dev/null; then
  echo -ne '\e[32m'
  GREP_OPTIONS= grep 'All tests passed' $LOGFILE
  RETURN_CODE=0
  # Cleaning up
  find . -name LocalSite.cfg -prune -o -group www-data -type f -exec rm {} \;
  find . -depth -name LocalSite.cfg -prune -o -group www-data -type d -exec rmdir {} \;
  [ -d .git ] && git diff --quiet
else
  echo -ne '\e[31m'
  perl -nle 'if(/^(-+|\d+ failures)$/ ... /^$/){push @a, $_ if /^[^-]+$/}
print join "\n", @a, $_ if /test cases passed/' $LOGFILE
  RETURN_CODE=1
fi
echo -ne '\e[0m'
exit $RETURN_CODE
