# Before use

<a href=http://mechanize.rubyforge.org/>Mechanize</a> is needed:

`sudo gem install mechanize`

Mechanize, as well as the rest of your Ruby gems, can be kept up to date using the command:

`sudo gem update`

# Usage:

`ruby with_login.rb LOGIN-EMAIL PASSWORD GALLERY-URL`

or login using .netrc's credentials

`ruby with_login.rb -n GALLERY-URL`

For example: 

`ruby with_login.rb jack_bauer@ctu.com kim http://azoexevan.deviantart.com/gallery/`

or

`ruby with_login.rb -n http://azoexevan.deviantart.com/gallery/`
