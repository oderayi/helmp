# Description: This script is used to generate release note for a release.

# current branch
current_branch=$(git branch --show-current)

# last_release_tag is the last release tag, if not provided, it will be the last tag in the current branch
if [ -z "$1" ]; then
    last_release_tag=$(git describe --tags --abbrev=0)
else
    last_release_tag=$1
fi

# step: use last release tag and current tag to generate release note
# extract and store repository name and tag in mojaloop's values.yaml file
helm show values mojaloop | grep -E 'repository:|tag:' | awk '{print $1 $2}' > current-tags.log

# checkout out last release tag and extract repository name and tag in its mojaloop's values.yaml file
git stash # stash current changes
git checkout $last_release_tag
helm show values mojaloop | grep -E 'repository:|tag:' | awk '{print $1 $2}' > last-release-tags.log

# checkout back to current branch
git checkout $current_branch
git stash pop # pop stashed changes

# walk through the current-tags.log file and compare with last-release-tags.log file
# for each repository, write change log to file using tag from current-tags.log file and last-release-tags.log file










