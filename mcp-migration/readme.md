# MCP Test

https://wiki-engr.mcp-services.net/pages/viewpage.action?pageId=107219624#PE-14.5AsanMCPEngineer,HowdoItestCloudControlfunctionalityusingAnsible?-Index


Setting up the Credentials for the NTT_MCP Ansible Modules
The modules require the Cloud Control API credentials to be setup in either a credential file in the root of the user's home directory or as environment variables. The filename must be .nttmcp and should be chmod'd to 600. Pick one of the two methods shown below. Note when using this in the NTT CIS lab environment you must also supply the API endpoint (I'm not changing the core module code to support lab environments as this code will become public).

vi ~/.nttmcp
 
 
[nttmcp]
NTTMCP_USER: <CC username>
NTTMCP_PASSWORD: <CC password>
NTTMCP_API: <API URL e.g. api-ash99-patchqa.mcp-services.net>
NTTMCP_API_VERSION: 2.10
set +o history
export NTTMCP_USER=<CC username>
export NTTMCP_PASSWORD=<CC password>
export NTTMCP_API=<API URL e.g. api-ash99-patchqa.mcp-services.net>
export NTTMCP_API_VERSION=2.10
set -o history



### Getting Started
For MaC OS USERs
- Install Python3.# (or reinstall)
    - brew reinstall python3 --force
    - curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
    - python3 get-pip.py
- Install VirtualENV
    - pip3 install virtualenv
- Create a virtual environment
    - Go to location where you want to create your virtual env
    - virtualenv foldername 
    - virtualenv --python=/usr/bin/python3.7 foldername (to assign specific permission)
- Activate virtual environment
    - source folername/bin/activate
- Install Ansible 
    - pip install ansible
- Install NTT MCP Ansible Module
    - pip install requests configparser PyOpenSSL netaddr
    - ansible-galaxy collection install -f nttmcp.mcp
    - https://galaxy.ansible.com/nttmcp/mcp
    - create .nttmcp environment file 
        NTTMCP_API: api-<geo>.mcp-services.net
        NTTMCP_API_VERSION: 2.11
        NTTMCP_PASSWORD: mypassword
        NTTMCP_USER: myusername
    - Temporary creds
        set +o history
        export NTTMCP_API=api-<geo>.mcp-services.net
        export NTTMCP_API_VERSION=2.11
        export NTTMCP_PASSWORD=mypassword
        export NTTMCP_USER=myusername
        set -o history

