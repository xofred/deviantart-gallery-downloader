# Change log
- [2021-02-19]
  - DeviantArt have refactored their frontend, guys must git pull the newest master branch to use.
  - `ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery/all` can get the 'all' folder of an author, no need for dev branch any more.

# Before use

[Mechanize](http://mechanize.rubyforge.org) and netrc are needed:

`bundle` if u have Bundler installed.

or

`sudo gem install mechanize netrc`

# Deviantart account setting

Please go to https://www.deviantart.com/settings/browsing. In "**General Browsing**" section, make sure "**Display**" as "**24 Thumbnails per Page**" and "**Paging**" as "**Click through pages**"
![Deviantart account setting](https://user-images.githubusercontent.com/2174219/27268778-7a0edf0c-54e4-11e7-859c-c7b0b7200a77.png)

# Usage

On the intital run, we need to add your login credential to your users ~/.netrc file, so we don't leave your username and password in the process ID, which could be seen by other users on the system (note: the initial run of this script will show up in your bash history).

`ruby fetch.rb YOUR_USERNAME YOUR_PASSWORD https://www.deviantart.com/kalfy/gallery`

An entry in ~/.netrc is created for you. You can then use '-n' and it will poll the netrc file for your login credentials.

(Featured)      `ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery`
(all)           `ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery/all`
(some gallery)  `ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery/72183557/characters`
