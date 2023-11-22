**Various parts of the code/scripts were changed to avoid security risks**

This section of the Notion is a series of documentation about the various key technologies/languages, which BeeSage use for Hivemap. The current techstack is: Amazon Web Services (AWS), Python, Fluentd (logging tool), Docker. Within the tech stack we also use Bash to help us automate within the Virtual Machines (VMs) 
The audience for this documentation is the general team, such that everyone is able to understand broadly what is being done with Hivemap. Currently, the structure is a series of section on work that has been done, as well as sub-pages for sections that are larger to prevent it from being too cluttered. 

# Docker-compose
Docker-Compose allows us to start up multiple docker instances with a few simple commands. This is done by creating a docker-compose.yaml file. This file essentially serves as a series of instructions for docker in creating the various services. YAML IS A VERY SENSITVE WHEN IT COMES TO SPACING. Here’s a useful beginner friendly video: https://www.youtube.com/watch?v=DM65_JyGxCo&t=56s

Now let’s go over some of the docker services that BeeSage uses and explain the code. Since yaml is space sensitive, the streamlit and fluentd are indented into the scope of services. All the subsequent keywords (build, ports, volumes) are part of their respected service
```yaml
version: "3.8"
services: 
  streamlit:
    build: . 
    ports:
      - "8501:8501" # default streamlit port number
    volumes:
      - .:/app
    command: streamlit run app.py #1
  fluentd:
    container_name: fluentd
    user: root #2
    build:
      context: .
    image: fluentd
    volumes: #3
      - /var/lib/docker/containers:/fluentd/logs/containers
      - ./fluent.conf:/fluentd/etc/fluent.conf
      - ./logs:/output
    logging:
      driver: "local"
```
1) Some services require a command to be start, user have to run streamlit run app.py in their terminal, but since we are running a docker, we need the docker to run it.
2) the root user in Linux has special admin right, this makes sure the docker will always be able to do what’s needed regardless of admin rights.
3) Within fluentdvolumes has specific mapping for files and directories as they are the default locations that fluentd would normally look for them. Since we are installing it on a VM we need to make sure those files are there and in the correct location. 

# Adding a user to AWS EC2
To add another user to the VM we need to give them access with a new private SSH key. This new key is just for them. Firstly, you need to go the AWS site, select the EC2 instance’s security group and add an `inbound rule`for the new user. 

This `inbound rule` needs to be set to TCP, with the users IP address (please add a description of the users name i.e. `username_ip)`. This allows the server to receive inbound traffic from the user.

Next you need to create an SSH key for the user. This can be done by using `keygen` or by adding a keypair on the AWS console. With the keypairs created we need to add the public part of the key to the VM's `authorized_keys` file. 

In case you get the error `**SSH Agent Not Running**: The SSH agent isn't running or isn't available in your current shell session`. You need to start the SSH agent before you can use `ssh-add` , this done with the following command:

```bash
eval $(ssh-agent)
```

The SSH-key has a public key and a private key; where the public key is stored in the VM and the private key is stored in the users local machine.

In order to get the public part of the key and give it the correct permissions do the following:

```bash
ssh-add Key_Name.pem # adds the keys to shh on your machine
ssh-keygen -e -m RFC4716 -f Key_Name.pem # return the public key of your SSH key
chmod 600 Key_Name.pem # changes the permissions of the key to make it more secure otherwise it'll be too public and you won't be granted access.
```
Now we need to take the public key string and add it to the `authorized_keys` :
```bash
echo "ssh-ed25519 <generated_string> Key_Name" >> authorized_keys # adds the public key to the authorized_keys file
nano authorized_keys # to check if the file is correct
```
If you see the correct string on the `authorized_keys` file, you can now access the VM via your terminal:
```bash
ssh -i "~/.ssh/Key_Name.pem" <ubuntu@vms_address.region.compute.amazonaws.com>
```
You should now have access to the VM's terminal.

# Linux/Bash: Edit Cron job (in VM)
Cron jobs allow our Linux systems to run specified commands at specified times. This is done by running crontab -e , which asks you to choose an editor (pick nano as it most user-friendly). Then this file will open; explaining how cron jobs are formatted.  

``` bash
* * * * * <example command> >> <example output>
* * * * * /path/to_my/scripts/git_repo_check.sh >> /path/to_my/scripts/git_repo_check.log 2>&1
``` 

We can enter various values for each of the 5 time entries (minutes, hours, day of the month, month and day of the week). 
After we write the command that we want performed. 
For example, the second command above runs a script to check the GitHub and have it return the output to a log file.
N.B. each cronjob must be on a separate line


# Bash: GitHub Script 
This section goes over our script to automate updating the GitHub on the AWS EC2. The script needs to check the repo and either pull or notify us of any changes.

We use a couple of variables (`REPO_PATH`, `LOG_PATH` and `TIMESTAMP`) as we need to provide the paths GitHub repo (since the script has to be in the directory of the repo to successfully perform any git actions)  and the log file (so we can output the logging information to the correct place). The following code block goes over the crux of the script.
```bash
# Fetch the latest changes and return the count for the if statement
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
```
Git fetch is very important as it checks to see if any changes have been made, most importantly, to see if the VM’s repo is on the same count as the Origins. In that, the branch Count is the condition of the initial IF-statement, where if the VM’s count is behind then it’ll try to pull. The nested IF-statement is informs us if it was successful or if there are merge conflicts. 
There are other IF-statements to check other important Git conditions.

This section goes over our script to automate updating the GitHub on the AWS EC2. The script needs to check the repo and either pull or notify us of any changes.

We use a couple of variables (`REPO_PATH`, `LOG_PATH` and `TIMESTAMP`) as we need to provide the paths GitHub repo (since the script has to be in the directory of the repo to successfully perform any git actions)  and the log file (so we can output the logging information to the correct place). The following code block goes over the crux of the script.

```bash
# Fetch the latest changes and return the count for the if statement
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
```

Git fetch is very important as it checks to see if any changes have been made, most importantly, to see if the VM’s repo is on the same count as the Origins. In that, the branch Count is the condition of the initial IF-statement, where if the VM’s count is behind then it’ll try to pull. The nested IF-statement is informs us if it was successful or if there are merge conflicts. 
There are other IF-statements to check other important Git conditions.

# Python Logging File Boilerplate
With the BeeSage expanding the number of micro-services it uses, logging will become a more and more important tool for us to debug problems and prevent issues from occurring. The following code block allows us to create a very basic configuration for a logging. It contains the level at which we want it to log messages, the format for those messages, the date format and the file we want the logs sent to.
```python
logging.basicConfig(
   level=logging.DEBUG,
   format="%(asctime)s %(levelname)s %(message)s",
   datefmt="%Y-%m-%d %H:%M:%S",
   filename="stremlit.log")
```
However, the issue with this is it cannot be exported to other Python modules (files). Instead, we can use the following code to create a series of logging objects which we can export to other modules.
```python
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

formatter = logging.Formatter("%(levelname)s:%(name)s:%(message)s")

file_handler = logging.FileHandler('streamlit.log')
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)
```
Logger is the main object used. It uses __name__  as dunder in order to be able to create the object anywhere (part of the reason we can use this in other modules). Then we set the level of information we want logged, once done with test/debugging set it to DEBUG unless certain INFO is needed.
Formatter allows us to format messages.
File_handler allows us to handle the files, meaning we can specify the log file we want it sent too. We set a format and then we add the handler to the logger object. Logger objects in Python follow a strict hierarchy as shown in this code block.  

# Python Fluentd Logging File Boilerplate
We need a tag (which fluentd needs to use the correct block), the host and port, as well as the log_level.
```python
import fluent.handler
import fluent.sender
import logging

def fluentd_logger(tag, host:str, port:int, log_level=logging.DEBUG):
    ''' Creates a logger using fleuntd. Requires the fluentd tag, host, portnumber.
    LogLevel is currently set to debug get all messages. It creates a custom '''

The FluentSender object does what it says and requires the fluentd tag and the relevant host and port.

fluent_logger = fluent.sender.FluentSender(tag, host=host, port=port)

we need to make a custom handler

class FluentdHandler(logging.Handler):
        def emit(self, record):
            try:
                msg = self.format(record)
                fluent_logger.emit(tag, {'message': msg})
            except Exception:
                self.handleError(record)
```
Then, we need to set the basicConfig using the log level argument; and finally, we put all out objects together.
```python
logging.basicConfig(level=log_level)
root_logger = logging.getLogger()
root_logger.addHandler(FluentdHandler)
fluent_logger = root_logger
	return fluent_logg
```
