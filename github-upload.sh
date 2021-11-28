#!/bin/bash

source $(dirname $0)/github-upload-config.conf

if [[ -z "$GITHUB_USERNAME" ]]; then
    echo "GITHUB_USERNAME is not set"
    exit 1
fi
if [[ -z "$GITHUB_REPOSITORY" ]]; then
    echo "GITHUB_REPOSITORY is not set"
    exit 2
fi
if [[ -z "$BRANCH_NAME" ]]; then
    BRANCH_NAME="master"
fi
if [[ -z "$LOCAL_REPO_PATH" ]]; then
    echo "LOCAL_REPO_PATH is not set"
    exit 3
fi
if [[ -z "$DEPLOY_PRIVATE_KEY" ]]; then
    DEPLOY_PRIVATE_KEY="~/.ssh/id_rsa"
fi
if [[ -z "$NO_GPG_SIGN" ]]; then
    NO_GPG_SIGN="true"
fi
if [[ -z "$GIT_BINARY" ]]; then
    GIT_BINARY="git"
fi
if [[ -z "$CHECKSUM_BINARY" ]]; then
    CHECKSUM_BINARY="md5sum"
fi


no_gpg_sign_option=""
if [ "$NO_GPG_SIGN" = "true" ] ; then
    no_gpg_sign_option="--no-gpg-sign"
fi

year=$(date +%Y)
month=$(date +%m)
target_path="$LOCAL_REPO_PATH/$year/$month"
mkdir -p $target_path

cd $LOCAL_REPO_PATH
$GIT_BINARY checkout --quiet $BRANCH_NAME
unset -v SSH_AUTH_SOCK
export GIT_SSH_COMMAND="ssh -i $DEPLOY_PRIVATE_KEY -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
$GIT_BINARY fetch --all --quiet
$GIT_BINARY pull --rebase --no-edit $no_gpg_sign_option --quiet origin $BRANCH_NAME

datetime=$(date +%Y%m%d%H%M%S)
commit_message_file="/tmp/commit_message_${datetime}.txt"
echo "Upload Images">>$commit_message_file
for file in "$@"
do
    file_base_name=$(basename "$file")
    file_extension="${file_base_name##*.}"
    checksum=`$CHECKSUM_BINARY "$file" | awk '{ print $1 }'`
    file_name="${datetime}_${checksum}_${file_base_name}"
    cp "$file" "$target_path/$file_name"
    echo "- ${file_base_name}">>$commit_message_file
    echo "https://raw.githubusercontent.com/${GITHUB_USERNAME}/${GITHUB_REPOSITORY}/${BRANCH_NAME}/${year}/${month}/${file_name}"
done

$GIT_BINARY add --all
$GIT_BINARY commit --quiet -F $commit_message_file $no_gpg_sign_option
$GIT_BINARY push origin $BRANCH_NAME --quiet

# rm -f $commit_message_file
