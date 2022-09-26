#!/bin/bash

if [[ $# != 1 ]]
then
  echo "Usage: $0 <plugin>"
  exit 1
fi

type jq > /dev/null 2>&1
ret=$?
if [[ $ret != 0 ]]
then
  echo "jq not found, please install it and try again"
  exit 1
fi

getjenkinsdeps() {
  local jsonindex=$1
  local plugin=$2
  deps=$(cat "${jsonindex}" |jq ".plugins.${plugin}.dependencies[] | select(.optional==false)|.name")
  if [[ xxx$deps != "xxx" ]]
  then
    for dep in $deps
    do
      echo $dep
      getjenkinsdeps ${jsonindex} ${dep}
    done
  fi
}

# install jenkins plugins
mkdir -p -m 0755 $HOME/.jenkins/plugins

# these are the plugins we need, double-quote names containing dashes
getplugins="git bitbucket \"build-timeout\" \"pipeline-model-definition\""

# get the jenkin plugin index and strip it
toc=$(mktemp)
curl -s https://updates.jenkins.io/current/update-center.actual.json -o ${toc}

# make a list of our plugins and their dependencies
for getplugin in $getplugins
do
  plugins="$plugins ${getplugin} $(getjenkinsdeps ${toc} ${getplugin})"
done

# sort and uniq the results
plugins=$(for word in ${plugins}; do echo "$word "; done | sort |uniq)

# get all plugins
for plugin in ${plugins}
do
  curlcmd="curl -s --location $(cat ${toc} | jq -r ".plugins.${plugin}.url") \
    -o $HOME/.jenkins/plugins/$(echo ${plugin} |sed 's/\"//g').jpi"
  echo ${curlcmd}
done

# remove temp files
rm -f "${toc}"
