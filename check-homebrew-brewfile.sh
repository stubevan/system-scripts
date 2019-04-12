#!/usr/local/bin/bash

MAC_SYSTEM_APPS="SystemApps.txt"
MANUAL_MAPPINGS="ManualMappings.txt"
APPS_TO_IGNORE="AppsToIgnore.txt"

#get Agreed brews
exclude_str=""
for brew in $(grep 'brew "' $1 | awk -F\" '{print $2}')
do
	exclude_str="${exclude_str}${brew}|"
done
exclude_str=${exclude_str::-1}

echo "Looking for unrepresented Brews"
brew-graph --installed | gawk -F\" \
'{
	brew=$2;
	depends=$4;
	if (brew != "" && !(brew in brews))
	{
		brews[brew]=1;
	}
	if (depends != "")
	{
		brews[depends]=0;
	}
	#printf("%s => %s --> %d\n", brew, depends, deps[brew][depends]=1);

}
END {

	for(brew in brews)
	{
		key=brews[brew];
		if (key==1)
		{
    			printf("%s\n", brew);
		}
	}
}' | egrep -v "${exclude_str}" | sort

echo "Looking for unrepresented Applications"

#Create the exclude string - start with Mac Apps"
IFS=$'\n'
exclude_str=""
for app in $(cat ${APPS_TO_IGNORE})
do
	exclude_str="${exclude_str}${app}|"
done
#exclude_str=${exclude_str::-1}

for app in $(cat ${MAC_SYSTEM_APPS})
do
	exclude_str="${exclude_str}${app}|"
done
#exclude_str=${exclude_str::-1}

# Now add Apps installed from the app stored
for app in $(grep "^mas" $1 | awk -F\" '{print $2}')
do
	exclude_str="${exclude_str}${app}.app|"
done
#exclude_str=${exclude_str::-1}

# Now add Apps install via brew cask install
# We need to add additional info to map to the True app name
for cask in $(grep "^cask" $1 | awk -F\" '{print $2}')
do
	appname=$(brew cask info $cask | grep "(App)" | sed "s/ (App)//" | sed "s/^.*-> //")
	if [ ! -z "${appname}" ]; then
		exclude_str="${exclude_str}${appname}|"
	else
		#echo "Looking for $cask"
		appname=$(awk -F\| '$1==caskname {print $2}' caskname=${cask} $MANUAL_MAPPINGS)
		if [ ! -z "${appname}" ]; then
			#echo "Found $appname from $cask"
			exclude_str="${exclude_str}${appname}|"
		fi
	fi
done
if [ ! -z "${exclude_str}" ]; then 
	exclude_str=${exclude_str::-1}
fi


echo ${exclude_str}

(cd /Applications; find . -type d -name \*.app) | egrep -v "${exclude_str}" | sort | grep -v ".app/"

	
