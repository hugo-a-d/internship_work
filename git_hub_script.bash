# two paths: the path to my repo to execute the checks on the repo; and the path to log file for the output. Also the necessary date-time stamp.
REPO_PATH = path/to/my/repo
LOG_PATH = path/to/my/file.log
TIMESTAMP = $(date +"%Y%m%d%H%M%S")


# get to the repo and Fetch the latest changes and return the count for the if statement
cd $REPO_PATH
git fetch

# Check if there are changes not staged for commit
if [ "$(git status --porcelain)" ]; then
    echo "[$TIMESTAMP] Changes not staged for commit detected" >> "$LOG_FILE"
fi

# Check if there are untracked files
if [ "$(git ls-files --other --exclude-standard)" ]; then
    echo "[$TIMESTAMP] Untracked files detected" >> "$LOG_FILE"
fi


# Check if the remote 'main' is ahead of VM's local using greater than on the count
# and log the timestamp of the git pull to the log file
if [ "$(git rev-list HEAD...origin/main --count)" -gt 0 ]; then
    echo "[$TIMESTAMP] Updating 'main' branch..." >> "$LOG_FILE"
    # Try to perform the pull operation
    if git pull origin main 2>&1 | tee -a "$LOG_FILE"; then
        echo "[$TIMESTAMP] Pull successful" >> "$LOG_FILE"
    else
        # Log if there is a merge conflict
        if grep -q "CONFLICT" "$LOG_FILE"; then
            echo "[$TIMESTAMP] Merge conflict detected" >> "$LOG_FILE"
        fi
    fi
fi
