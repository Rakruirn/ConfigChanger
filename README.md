# ConfigChanger
This is a simple and quick PowerShell script for changing MC config files. 

I put this together as I found I was frequently refreshing my MC folder and would forget which changes I wanted to make. 
For example, when a mod update requests/requires a config file refresh. Your config change will either apply or notify you that the value you were trying to change is no longer there. 

One downside, this requires the config files to be already present. Meaning to refresh the configs will require you to start your client twice. Once to generate the config files, and the second after you have applied the changes. 

You will need a properly formatted json file; see example.json.

(I know there are likely better ways, but this is what I came up with.)
