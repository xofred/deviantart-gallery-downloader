# Before use

[Mechanize](http://mechanize.rubyforge.org) and netrc are needed:

`bundle` if u have Bundler installed.

or

`sudo gem install mechanize netrc`

# The downloader uses GALLERY'S PAGE

On the intital run, we need to add your login credential to your users ~/.netrc file, so we don't leave your username and password in the process ID, which could be seen by other users on the system (note: the initial run of this script will show up in your bash history).

`ruby fetch.rb YOUR_USERNAME YOUR_PASSWORD http://azoexevan.deviantart.com/gallery/`

An entry in ~/.netrc is created for you. You can then use '-n' and it will poll the netrc file for your login credentials.

`ruby fetch.rb -n http://azoexevan.deviantart.com/gallery/`

# Deviantart account setting

Please go to https://www.deviantart.com/settings/browsing. In "**General Browsing**" section, make sure "**Display**" as "**24 Thumbnails per Page**" and "**Paging**" as "**Click through pages**"

