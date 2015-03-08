#!/bin/bash
# Updates all given (dot)files for current host
# The files or folders to be saved must be given line by line in a file called
# "FILES_$(hostname)". Empty lines and bash comments are allowed. All lines
# start with ! are copied but not added to git.
# 
# Written by Stefan Hackenberg

###############################################################################
## constants ##################################################################
###############################################################################
# replacement of leading dots in file- or dirnames
DOT_REPLACEMENT="dot_"
# file prefix for file containing a list of all files which have to be saved
# in the contents file comment lines start bash-like with #
CONTENTS_PREFIX="FILES_"
# prefix for installation file, i.e. the file you call if you want to reuse
# your updated files
INSTALL_PREFIX="INSTALL_"

###############################################################################
## functions ##################################################################
###############################################################################

# copies file to myconfig/$hostname/file
# where all leading dots are replaced by "dot_"
# and the whole directory tree will be generated if needed
# current directory must be ./$hostname/
#
# $1 -- the file
mygoodcopy(){
    local file=$(realpath $1)
    local owner=$(ls -ld $file | awk '{print $3}')
    local group=$(ls -ld $file | awk '{print $4}')
    local perms=$( stat --format=%a $file )
    echo "get $file"
    file_nodot=$(echo $file | sed "s/\/\./\/${DOT_REPLACEMENT}/g")
    file_nodot=${file_nodot#/}
    mkdir -p $(dirname $file_nodot)
    # if file is directory we must take the parent directory as destination
    local file_nodot_dest=$file_nodot
    if [[ -d $file ]] ; then
        file_nodot_dest=$(dirname $file_nodot)
    fi
    ### copy the file
    rsync -au -r $file $file_nodot_dest
    ### write appropriate entry to install file
    cat <<EOF >> $install_file
if [ -f ${file_nodot} ] || [ -d ${file_nodot} ] ; then
    read -p "copy ${file} ? [Y/n]" -n 1 -r
    echo
    if [[ \$REPLY =~ ^[Y|y]$ ]] ; then
        echo "install -D -d -o $owner -g $group -m $perms "$hostname/$file_nodot" $file"
        install -D -d -o $owner -g $group -m $perms "$hostname/$file_nodot" $file
    fi
fi
EOF
}


###############################################################################
## start of script ############################################################
###############################################################################
echo "This is update script"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
pushd $DIR

hostname=$(hostname)
# get all available file lists
avail_hosts=$(ls ${CONTENTS_PREFIX}* | awk 'BEGIN {FS="_"} {print $2}')

# check if this host is supported
if ! [[ $avail_hosts =~ $hostname ]] ; then
    echo "$hostname not available!"
    exit -1
fi
contents=$(realpath ${CONTENTS_PREFIX}$hostname)
install_file=$(realpath ${INSTALL_PREFIX}$hostname)

echo "###############################################################"
echo "Do update for ${hostname}"
echo "###############################################################"

###### DO UPDATE
# create install file
cat <<EOF > $install_file
#!/bin/bash
#Install file for $hostname
#autogenerated by update.sh
EOF
chmod +x $install_file

# create host dir and copy files
mkdir -p $hostname
pushd $hostname
while read lin ; do
    # leave empty lines and comments out 
    if ! ([ -z "$lin" ] || [[ $lin =~ ^\#.* ]]) ; then
        mygoodcopy ${lin#!}
        # only add to git if line does not start with !
        if ! [[ $lin =~ ^!.* ]] ; then 
            gitfiles="$gitfiles $file_nodot"
        else 
            nogitfiles="$nogitfiles $file_nodot"
        fi
    fi
done < $contents


echo "###############################################################"
echo "update on github"
echo "###############################################################"

git add $gitfiles
git rm --cached --ignore-unmatch -r $nogitfiles
git commit -a -m "${hostname} aktualisiert"
git push

popd
popd
