# Description: This script is used to generate release note for a release.

# Check if the current shell is bash and the version is >= 4.0.0
if [ -z "$BASH_VERSION" ] || [ "${BASH_VERSION:0:1}" -lt 4 ]; then
    echo "This script requires bash >= v4.0.0. Please install bash >= v4.0.0 and try again."
    exit 1
fi

# Current branch
current_branch=$(git branch --show-current)

# 'last_release_tag' is the last release tag, if not provided, it will be the last tag in the current branch
if [ -z "$1" ]; then
    last_release_tag=$(git describe --tags --abbrev=0)
else
    last_release_tag=$1
fi

# Extract and store repository name and tag in mojaloop's values.yaml file
helm show values mojaloop | grep -E 'repository:|tag:' | awk '{print $1 $2}' > current-tags.log

# Checkout out last release tag and extract repository name and tag in its mojaloop's values.yaml file
git stash # stash current changes
git checkout $last_release_tag
helm show values mojaloop | grep -E 'repository:|tag:' | awk '{print $1 $2}' > last-release-tags.log

# Checkout back to current branch
git checkout $current_branch
git stash pop # pop stashed changes

# Generate the changelog using repositories and tags from last-release-tags.log and current-tags.log
# We create two associative arrays to store the repositories and tags from last-release-tags.log and current-tags.log
# The associative arrays are indexed by the repository name and the value is the tag
# We then iterate through the associative arrays and generate the changelog for each repository that has changed

# NOTE: bash >= v4.0.0 is required for associative array
declare -A last_release_tags
declare -A current_tags

# Read last release tags into associative array 'last_release_tags' 
last_repo=null
while IFS= read -r line
do
    if [[ $line == *"repository:"* ]]
    then
        repository=$(echo $line | cut -d':' -f2 | cut -d' ' -f1)
        last_repo=$repository
        last_release_tags[$last_repo]=null
    fi
    
    if [[ $line == *"tag:"* ]]
    then
        tag=$(echo $line | cut -d':' -f2)
        last_release_tags[$last_repo]=$tag
    fi
done < "last-release-tags.log"

# Read current tags into associative array 'current_tags'
last_repo=null
while IFS= read -r line
do
    if [[ $line == *"repository:"* ]]
    then
        repository=$(echo $line | cut -d':' -f2 | cut -d' ' -f1)
        last_repo=$repository
        current_tags[$last_repo]=null
    fi
    
    if [[ $line == *"tag:"* ]]
    then
        tag=$(echo $line | cut -d':' -f2)
        current_tags[$last_repo]=$tag
    fi
done < "current-tags.log"

# Generate the github changelog
# We store the changelogs in a temporary directory
dir=".tmp-changelogs"

# If the directory exists, remove its contents
if [ -d "$dir" ]; then
    rm -rf "$dir"/*
else
    # If the directory does not exist, create it
    mkdir -p "$dir"
fi

# Generate changelog for each mojaloop repository that has changed using github api
for repository in "${!last_release_tags[@]}"
do
    if [[ $repository == mojaloop* && ${current_tags[$repository]} && ${last_release_tags[$repository]} != ${current_tags[$repository]} ]]
    then
        repository_short_name=$(echo $repository | cut -d'/' -f2)
        curl -s -L \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $AUTO_RELEASE_TOKEN" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            https://api.github.com/repos/$repository/compare/${last_release_tags[$repository]}...${current_tags[$repository]} > $dir/$repository_short_name-changelog.json
    fi
done

# Generate release note.
# We use a template (.github/workflows/templates/release-note-template.md) to generate the release note
# The template contains placeholders that are replaced with the PR titles from the changelogs and other information













