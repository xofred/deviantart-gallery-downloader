# Before use

[Mechanize](http://mechanize.rubyforge.org) and netrc are needed:

`sudo gem install mechanize netrc`

Mechanize, as well as the rest of your Ruby gems, can be kept up to date using the command:

`sudo gem update`

On the intital run, we need to add your login credential to your users ~/.netrc file, so we don't leave your username and password in the process ID, which could be seen by other users on the system (note: the initial run of this script will show up in your bash history).

`ruby with_login.rb jack_bauer@ctu.com kim http://azoexevan.deviantart.com/gallery/`

An entry in ~/.netrc is created for you. You can then use '-n' and it will poll the netrc file for your login credentials.

`ruby with_login.rb -n http://azoexevan.deviantart.com/gallery/`
