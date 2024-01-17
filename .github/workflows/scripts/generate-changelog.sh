# NOTE: bash >= v4.0.0 is required for associative array

declare -A last_release_tags
declare -A current_tags

# read last release tags into associative array 'last_release_tags' 
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

# read current tags into associative array 'current_tags'
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

# generate the github compare terms
echo -e "\n zipped tags"

# we store the changelogs in a temporary directory
dir=".tmp-changelogs"
# If the directory exists, remove its contents
if [ -d "$dir" ]; then
    rm -rf "$dir"/*
else
    # If the directory does not exist, create it
    mkdir -p "$dir"
fi
# generate changelog for each repository that has changed using github api
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