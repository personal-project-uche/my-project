## Checks that a repo has the following file updates:
#    metadata.rb has a +version number
#    CHANGELOG.md has a version number matching the new one found in metadata.rb
#    cookbook name in metadata.rb, matches the directory name, possibly minus the "chef-" prefix
#
# Assumptions (pre-requisites? requirements?):
#   The Workspace has been cleared before cloning the repo (this script creates a branch)
#
#   The git repo is in a detached-HEAD state
#   (That is how the Jenkins Pull-Request Builder plugin handles the PR.)
#
#   It is a single-cookbook git repo
#
# Note that, for local testing, 'grep -oP' only works on linux, not Mac (sigh...)
# (-P = perl-type syntax, -o = return only text matched)
#
# Note: this file and 'verify_pr_multibooks.sh' do the same basic operation, they validate Pull Requests -
# however this file does single-cookbook repositories, and the other does multiple-cookbook repositories.
#
# So there is some duplicate code - specifically the sanity-checking code done on metadata.rb
# If you update the checks in this file, you should update that file also.
# (If this were Python, I'd refactor the common code out into a library, but no... it's *bash*...)


echo -e "\nValidating various files in the current PR\n"

# Check that we're on a detached-HEAD, not valid branch
export detached_valid=`git status | grep 'HEAD detached' | wc -l`

if [[ "${detached_valid}" != "1"  ]]
then
    echo -e "\nProblem - the git repo must be a detached-HEAD, as created by the Jenkins Pull-Request Builder.\n"
    exit 1
fi

# Re-attach git's detached HEAD
git checkout -b PR_branch

# Instantiate master branch
git checkout master

# And now... we need the PR branch back for testing
git checkout PR_branch

# Check that required files exist
if [[ ! -f "metadata.rb"  ]]
then
    echo -e "\nmetadata.rb does not exist? Weird...\n"
    exit 1
fi
if [[ ! -f "CHANGELOG.md"  ]]
then
    echo -e "\nCHANGELOG.md does not exist? Weird...\n"
    exit 1
fi

# Sanity checking on metadata.rb:

# Metadata.rb: check that cookbook name exists

has_name=`grep -oP "^name\s+'.+'$" metadata.rb`

if [[ -z "${has_name}"  ]]
then
    echo -e "\nmetadata.rb must have a valid name field, in format: name 'some_name'\n"
    exit 1
fi

# Metadata.rb: check that it has a maintainer email
has_email=`grep -oP "^maintainer_email\s+'.+?@[\w+\-\.]+'$" metadata.rb`

if [[ -z "${has_email}"  ]]
then
    echo -e "\nmetadata.rb must have a valid email, in format: maintainer_email 'john.doe@yoyodyne.com'\n"
    exit 1
fi

# Metadata.rb: check that "maintainer" exists as string
has_maintainer=`grep -oP "^maintainer\s+'.+'$" metadata.rb`

if [[ -z "${has_maintainer}"  ]]
then
    echo -e "\nmetadata.rb must have a valid maintainer, in format: maintainer 'some_name'\n"
    exit 1
fi

# Metadata.rb: check that "description" exists as (possibly multi-line) string

has_description=`grep -oP "^description\s+'.+" metadata.rb`

if [[ -z "${has_description}"  ]]
then
    echo -e "\nmetadata.rb must have a valid description, in format: description 'some stuff'\n"
    exit 1
fi

# Determine if the version number was changed in metadata.rb.
# Note that this assumes the original file *also* has a version number,
# otherwise diff returns '>version' for a new line, instead of '+version'.
# Also assumes that there is only one occurrence of the version.
has_version=`git diff master..PR_branch metadata.rb | grep '+version'`

if [[ -z "${has_version}"  ]]
then
    echo -e "\nmetadata.rb must have an updated version number.\n"
    exit 1
fi

# Get just the version number - assumes it is digits, delimited by single-quotes
# "+version           '9.9.9'"
# "+version           '9.9'"
# "+version           '9'"
version_number=`echo "${has_version}" | grep -oP '\d+\.*\d*\.*\d*'`

if [[ -z "${version_number}"  ]]
then
    echo -e "\nmetadata.rb must have a version number consisting of single-quoted digits\n"
    exit 1
else
    echo -e "\nVersion number in metadata.rb is <$version_number>\n"
fi

# Check that the version number from metadata.rb, matches the changelog
has_good_version=`grep ${version_number} CHANGELOG.md`

if [[ -z "${has_good_version}"  ]]
then
    echo -e "\nCHANGELOG.md must match the metadata.rb version number: <${version_number}>\n"
    exit 1
else
    echo -e "\nCHANGELOG.md matches the metadata.rb version number: <${version_number}>\n"
fi

# Check that there's a Jira ticket-number in some message in the commit log
# Look only in the changelog for the PR branch - ignore commits from master
jira_ticket=`git log master.. --oneline --no-merges | grep -oP '[A-Z0-9]+-\d+' | head --lines=1`

if [[ -z "${jira_ticket}"  ]]
then
    echo -e "\nCommit-log is missing a Jira ticket number.\n"
    exit 1
else
    echo -e "\nJira ticket from commit-log is <${jira_ticket}>\n"
fi

echo -e "\nPull-Request files are excellent.\n"
