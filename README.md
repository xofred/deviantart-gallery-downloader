# Change log
- [2022-03-07]
  - Refactored commandline processing; add requirement for 'getopt/std'
  - Added "-p" option to download one page of 24 at a time
  - Added support for "favourites":
    - https://www.deviantart.com/kalfy/favourites
    - https://www.deviantart.com/kalfy/favourites/all
    - https://www.deviantart.com/kalfy/favourites/72183557/characters
- [2021-02-19]
  - DeviantArt have refactored their frontend, guys must git pull the newest master branch to use.
  - `ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery/all` can get the 'all' folder of an author, no need for dev branch any more.

# Before use

[Getopt](https://github.com/djberg96/getopt), [Mechanize](http://mechanize.rubyforge.org), and netrc are needed:

`bundle` if u have Bundler installed.

or

`sudo gem install mechanize netrc getopt`

# Deviantart account setting

Please go to https://www.deviantart.com/settings/browsing. In "**General Browsing**" section, make sure "**Display**" as "**24 Thumbnails per Page**" and "**Paging**" as "**Click through pages**"
![Deviantart account setting](https://user-images.githubusercontent.com/2174219/27268778-7a0edf0c-54e4-11e7-859c-c7b0b7200a77.png)

# Usage

On the intital run, we need to add your login credential to your users ~/.netrc file, so we don't leave your username and password in the process ID, which could be seen by other users on the system (note: the initial run of this script will show up in your bash history).

`ruby fetch.rb YOUR_USERNAME YOUR_PASSWORD https://www.deviantart.com/kalfy/gallery`

An entry in ~/.netrc is created for you. You can then use '-n' and it will poll the netrc file for your login credentials.

For large galleries, you can use the "-p" option to download one page at a time:

`ruby fetch.rb -p 1 YOUR_USERNAME YOUR_PASSWORD https://www.deviantart.com/kalfy/gallery`
or
`ruby fetch.rb -p 1 -n https://www.deviantart.com/kalfy/gallery`

For a large gallery with, for example, 57 pages: (assuming bash shell on Linux)
`for i in {1..57} ; do ruby fetch.rb -p $i -n https://www.deviantart.com/kalfy/gallery ; sleep 60 ; done`

- (Featured)              `ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery`
- (all)                   `ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery/all`
- (some gallery)          `ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery/72183557/characters`
- (Favourites)            `ruby fetch.rb -n https://www.deviantart.com/kalfy/favourites`
- (All Favourites)        `ruby fetch.rb -n https://www.deviantart.com/kalfy/favourites/all`
- (Favourites gallery)    `ruby fetch.rb -n https://www.deviantart.com/kalfy/favourites/72183557/characters`
