require 'mechanize'
require 'netrc'

t1 = Time.now

# Check if command right
# Then check if .netrc file exist
# Then check if entry exist
if ARGV.size == 2 && ARGV[0] == "-n"
  if n = Netrc.read
    if n["deviantart.com"]
      puts "Using netrc's credential"
    else
      abort "No entry found, please re-run the program and enter your login and password."
    end
  else
    abort "Reading .netrc failed, please re-run the program and enter your login and password."
  end
elsif ARGV.size == 3
  begin
    n = Netrc.read
    if n["deviantart.com"]
      puts "Updating netrc's entry"
      n["deviantart.com"] = ARGV[0], ARGV[1]
      n.save
    else
      puts "Creating netrc's entry"
      n.new_item_prefix = "# This entry was added by deviantart-gallery-downloader automatically\n"
      n["deviantart.com"] = ARGV[0], ARGV[1]
      n.save
    end
  rescue => ex
    print ex.message, ", writing .netrc file failed, continue.\n"
  end
else
  puts "Usage first time:"
  puts "  ruby with_login.rb LOGIN-EMAIL PASSWORD GALLERY-URL"
  puts "For example:"
  puts "  ruby with_login.rb jack_bauer@ctu.com kim http://azoexevan.deviantart.com/gallery/"
  puts ""
  puts "After:"
  puts "  ruby with_login.rb -n GALLERY-URL"
  puts "For example:"
  puts "  ruby with_login.rb -n http://azoexevan.deviantart.com/gallery/"
  abort
end

HOME_URL = "http://www.deviantart.com/"
if ARGV.size == 3
  GALLERY_URL = ARGV[2].to_s
else
  GALLERY_URL = ARGV[1].to_s
end
AUTHOR_NAME = GALLERY_URL.split('.').first.split('//').last

if GALLERY_URL.split('/').count == 6
  GALLERY_NAME = GALLERY_URL.split('/').last
else
  GALLERY_NAME = "default-gallery"
end

Dir.mkdir("deviantart") unless File.exists?("deviantart") do
  Dir.chdir("deviantart") do
    Dir.mkdir(AUTHOR_NAME) unless File.exists?(AUTHOR_NAME) do
      Dir.mkdir(GALLERY_NAME) unless File.exists?(GALLERY_NAME) 
    end
  end
end

puts "Connecting to deviantART"
HEADERS_HASH = {"User-Agent" => "Ruby/#{RUBY_VERSION}"}
agent = Mechanize.new
begin
  agent.get(HOME_URL)
rescue => ex
  print ex.message, ", retrying\n"
  sleep 1
  retry
end
agent.pluggable_parser.default = Mechanize::Download

# Login 
puts "Logging in" 
begin
  agent.page.form_with(:id => 'form-login') do |f|
    if ARGV.size == 3
      f.username = ARGV[0]
      f.password = ARGV[1]
    else
      f.username = n["deviantart.com"].login
      f.password = n["deviantart.com"].password
    end
  end.click_button
  if agent.cookie_jar.count < 3
    puts "Log on unsuccessful (maybe wrong login/pass combination?)"
    puts "You might not be able to fetch the age restricted resources"
  else
    puts "Log on successful"
  end
rescue => ex
  print ex.message, "retry after 10 secs.\n"
  sleep 10
  retry
end

# Go to the gallery 
puts "Connecting to gallery"
begin
  agent.get(GALLERY_URL)
rescue => ex
  print ex.message, ", retrying\n"
  sleep 1
  retry
end

# Find page link
page_links = Array.new
normal_link_selector = "div.tt-a.tt-fh a.thumb"
mature_link_selector = "div.tt-a.tt-fh a.thumb ismature"
# Find last page number
last_page = agent.page.parser.css('.folderview-art .pagination ul.pages li.number').last

if last_page
  last_page_number = last_page.text.to_i

  # Page 1
  puts "(1/#{last_page_number})Analyzing #{GALLERY_URL}"
  page_links = (agent.page.parser.css(normal_link_selector) || agent.page.parser.css(mature_link_selector)).map{|a| a["href"]}

  # Page 2 to last
  for pg_number in 2..last_page_number do 
    offset = (pg_number - 1) * 24
    gallery_link = GALLERY_URL + "?offset=" + offset.to_s 
    puts "(#{pg_number}/#{last_page_number})Analyzing #{gallery_link}" 
    agent.get(gallery_link)
    page_link = (agent.page.parser.css(normal_link_selector) || agent.page.parser.css(mature_link_selector)).map{|a| a["href"]}
    page_links << page_link 
  end
  page_links.flatten!
else
  # Page 1
  puts "Analyzing #{GALLERY_URL}" 
  page_links = (agent.page.parser.css(normal_link_selector) || agent.page.parser.css(mature_link_selector)).map{|a| a["href"]}
end

# Find image link and download. I guess the token has time limit, so download the image as soon as the download link was founded.
for index in 1..page_links.count
  begin
    agent.get(page_links[index - 1])
    download_link = agent.page.parser.css(".dev-page-button.dev-page-button-with-text.dev-page-download").map{|a| a["href"]}[0] || agent.page.parser.css(".dev-content-full").map{|img| img["src"]}[0] 
    title = agent.page.parser.css(".dev-title-container h1 a").first.text
    
    puts "(#{index}/#{page_links.count})Downloading \"#{title}\""
    
    #Sanitize filename
    file_name = download_link.split('?').first.split('/').last
    
    file_ext = file_name.split('.').last

    file_title = title.strip().gsub(/\.+$/, '').gsub(/^\.+/, '').strip().squeeze(" ").tr('/\\', '-')

    file_name = file_title+'.'+file_ext

    file_path = "deviantart/#{AUTHOR_NAME}/#{GALLERY_NAME}/#{file_name}"
   
    # Download
    agent.get(download_link).save(file_path) unless File.exist?(file_path) 
  rescue => ex
    print ex.message, "\n" 
    next
  end
end

puts "\nAll download completed. Check deviantart/#{AUTHOR_NAME}/#{GALLERY_NAME}.\n\n"
t2 = Time.now
save = t2 - t1
puts "Time costs: #{(save/60).floor} mins #{(save%60).floor} secs."


