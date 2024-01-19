# Description: This script is used to generate release note for a release.
# Requirements: bash >= v4.0.0, jq, curl, git, helm, mo, sed
# Usage: .github/workflows/scripts/generate-release-note.sh release_version [last_release_tag]
# Environment variables: AUTO_RELEASE_TOKEN

######################
# Helper functions   #
######################
usage() {
    echo "export AUTO_RELEASE_TOKEN=<github token>"
    echo "generate-release-note.sh release_version [last_release_tag]"
}

function escape_sed {
  echo "$1" | sed -e 's/[\/&]/\\&/g'
}

breaking_changes() {
    # Loop over each json file in .tmp/changelogs directory
    # Extract the pull request titles from the json file into an associative array of array indexed by the file basename
    # The value of the associative array is an array of breaking changes
    # We then iterate through the associative array and generate the breaking changes section
    declare -A breaking_changes
    for file in $dir/changelogs/*.json
    do
        repository=$(basename $file | cut -d'.' -f1)
        breaking_changes[$repository]=$(cat $file | jq -r '.files[] | select(.filename | contains("default.json") or contains("migration")) | "  * \(.filename): (\(.blob_url))"')
    done

    # Generate breaking changes section
    # We loop over each repository in the associative array and generate the breaking changes section
    # If there are no breaking changes, we return an empty string
    # If there are breaking changes, we return the breaking changes section
    breaking_changes_section=""
    for repository in "${!breaking_changes[@]}"
    do
        if [[ ${breaking_changes[$repository]} ]]
        then
            breaking_changes_section+="* $repository: <br>"
            breaking_changes_section+="${breaking_changes[$repository]}"
        fi
    done

    echo "$breaking_changes_section"
}

release_summary_points() {
    # TODO: Sumarrize the release note into 3-5 points
    echo "<Release summary points go here...>"
}

new_features() {
    # TODO: Group PRs by their epics 
    echo ""
}

bug_fixes() {
    # TODO: Add logic here
    echo ""
}

application_versions() {
    application_versions=""
    line_number=0

    for repository in "${!current_tags[@]}"
    do
        if [[ $repository == mojaloop* ]]
        then
            if [[ ${current_tags[$repository]} != ${last_release_tags[$repository]} ]]
            then
                application_versions+="$((++line_number)). $repository: ${last_release_tags[$repository]} -> [${current_tags[$repository]}](https://github.com/$repository/releases/${current_tags[$repository]}) ([Compare](https://github.com/$repository/compare/${last_release_tags[$repository]}...${current_tags[$repository]})) <br>"
            fi
        fi
    done

    for repository in "${!current_tags[@]}"
    do
        if [[ $repository == mojaloop* ]]
        then
            if [[ ${current_tags[$repository]} == ${last_release_tags[$repository]} ]]
            then
                application_versions+="$((++line_number)). $repository: [${current_tags[$repository]}](https://github.com/$repository/releases/${current_tags[$repository]}) <br>"
            fi
        fi
    done

    echo "$application_versions"
}

ttk_test_cases_version() {
    # TODO: Add logic here
    echo ""
}

example_mojaloop_backend_version() {
    # TODO: Add logic here
    echo ""
}

individual_contributors() {
    # Loop over each json file in .tmp/changelogs directory and extract the commit author login
    # We then remove duplicates, sort the list, and convert the list to a comma separated string
    individual_contributors=""
    for file in $dir/changelogs/*.json
    do
        repository=$(basename $file | cut -d'.' -f1)
        individual_contributors+=$(cat $file | jq -r '.commits[].author | select(.login != null) .login' | sort -u | tr '\n' ',' | sed 's/,$//g' | sed 's/,/, /g')
    done

    echo "$individual_contributors"
}

####################################
# Environment and arguments check  #
####################################

# Check if the current shell is bash and the version is >= 4.0.0
if [ -z "$BASH_VERSION" ] || [ "${BASH_VERSION:0:1}" -lt 4 ]; then
    echo "This script requires bash >= v4.0.0. Please install bash >= v4.0.0 and try again."
    exit 1
fi

# Check if the AUTO_RELEASE_TOKEN environment variable is set
if [ -z "$AUTO_RELEASE_TOKEN" ]; then
    echo "The AUTO_RELEASE_TOKEN environment variable is not set. Please set the AUTO_RELEASE_TOKEN environment variable and try again."
    usage
    exit 1
fi

# Check if the release_version argument is provided
if [ -z "$1" ]; then
    echo "The release_version argument is not provided. Please provide the release_version argument and try again."
    usage
    exit 1
fi

#######################
# Prepare environment #
#######################

# We store the changelogs, commits, tags etc. in a temporary directory
dir=".tmp"

# If the directory exists, remove its contents
if [ -d "$dir" ]; then
    rm -rf "$dir"/*
fi

# Create the temp directory and subdirectories
mkdir -p "$dir/changelogs"
mkdir -p "$dir/commits"
mkdir -p "$dir/tags"

######################
# Generate changelog #
######################

release_version=$1
current_branch=$(git branch --show-current)

# 'last_release_tag' is the last release tag, if not provided, it will be the last tag in the current branch
if [ -z "$2" ]; then
    last_release_tag=$(git describe --tags --abbrev=0)
else
    last_release_tag=$2
fi

# Extract and store repository name and tag in mojaloop's values.yaml file
helm show values mojaloop | grep -E 'repository:|tag:' | awk '{print $1 $2}' > $dir/tags/current-tags.log

# Checkout out last release tag and extract repository name and tag in its mojaloop's values.yaml file
git stash # stash current changes
git switch --detach $last_release_tag
helm show values mojaloop | grep -E 'repository:|tag:' | awk '{print $1 $2}' > $dir/tags/last-release-tags.log

# Checkout back to current branch
git checkout $current_branch
git stash pop # pop stashed changes

# accept all stashed changes
# git stash list | awk -F: '{print $1}' | xargs -n 1 git stash apply

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
done < "$dir/tags/last-release-tags.log"

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
done < "$dir/tags/current-tags.log"

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
            https://api.github.com/repos/$repository/compare/${last_release_tags[$repository]}...${current_tags[$repository]} > $dir/changelogs/$repository_short_name.json
    fi
done

#########################
# Generate release note #
#########################

# Generate release note
# We use a template (.github/workflows/templates/release-note-template.md) to generate the release note
# The template contains placeholders that are replaced with the PR titles from the changelogs and other information

# Populate and export template variables for "mo"
export RELEASE_DATE=$(date +%Y-%m-%d)
export BREAKING_CHANGES=$(breaking_changes)
[[ -z $BREAKING_CHANGES  ]] && export BREAKING_CHANGES_STATUS_TEXT="non-breaking" || export BREAKING_CHANGES_STATUS_TEXT="breaking"
[[ -z $BREAKING_CHANGES  ]] && BREAKING_CHANGES="There are no breaking changes in this release."
export RELEASE_SUMMARY_POINTS=$(release_summary_points)
export NEW_FEATURES=$(new_features)
export BUG_FIXES=$(bug_fixes)
export APPLICATION_VERSIONS=$(application_versions)
export TTK_TEST_CASES_VERSION=$(ttk_test_cases_version)
export EXAMPLE_MOJALOOP_BACKEND_VERSION=$(example_mojaloop_backend_version)
export CURRENT_RELEASE_VERSION=$release_version
export LAST_RELEASE_VERSION=$(echo $last_release_tag | cut -d'/' -f2)
export INDIVIDUAL_CONTRIBUTORS=$(individual_contributors)

release_note=$(cat .github/workflows/templates/release-note-template.md | mo) 

if [[ $release_note == *"{{"* ]] || [[ -z $release_note ]]
then
    echo "Error: One or more template variables are not replaced. Please check the template variables and try again."
    exit 1
fi

# Write release_note content to .changelog/release-$CURRENT_RELEASE_VERSION.md
mkdir -p .changelog
echo "$release_note" > .changelog/release-$CURRENT_RELEASE_VERSION.md

######################
# Cleanup            #
######################
# Remove temporary directory and files
# rm -rf "$dir"

# End process
echo "Process completed successfully."
echo "Release note generated at .changelog/release-$CURRENT_RELEASE_VERSION.md"
