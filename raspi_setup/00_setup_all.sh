#!/bin/bash


repo=GROWTH-FY2015-Software

git_dir=$HOME/git
log_dir=$HOME/log

for dir in ${git_dir} ${log_dir}; do
	if [ ! -f ${dir} ]; then
		mkdir -p ${dir}
	fi
done


date=`date +'%Y%m%d_%H%M'`
log_git=${log_dir}/log_setup_all_git_clone_${date}.text
log_apt=${log_dir}/log_setup_all_apt_${date}.text

#---------------------------------------------
# Clone GROWTH-FY2015-Software repo if not present
#---------------------------------------------
pushd ${git_dir}
if [ ! -f ${repo} ]; then
	git clone https://github.com/growth-team/${repo} > ${log_git}
	if [ ! -f ${repo} ]; then
		echo "Error: git repository could not be cloned."
		exit -1
	fi
fi
popd


#---------------------------------------------
# Copy (link) zsh profile
#---------------------------------------------
pushd $HOME
ln -s /home/pi/git/${repo}/raspi_setup/zshrc .zshrc
popd


#---------------------------------------------
# Install apt modules
#---------------------------------------------
bash $HOME/git/${repo}/raspi_setup/install_apt-get.sh > ${log_apt}


#---------------------------------------------
# Prepare .ssh directory and authorized_keys
#---------------------------------------------
bash $HOME/git/${repo}/raspi_setup/setup_ssh.sh
