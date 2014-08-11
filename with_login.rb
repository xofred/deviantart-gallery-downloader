#require 'rubygems'
require 'mechanize'
#require 'pry'

abort "#{$0} login passwd gallery_full_url" if (ARGV.size != 3)

t1 = Time.now

HOME_URL = "http://www.deviantart.com/"
GALLERY_URL = ARGV[2].to_s 
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
agent.get(HOME_URL)
agent.pluggable_parser.default = Mechanize::Download

# Login 
puts "Logging in" 
agent.page.form_with(:id => 'form-login') do |f|
  f.username = ARGV[0]
  f.password = ARGV[1]
end.click_button

# Go to the gallery 
puts "Connecting to gallery"
agent.get(GALLERY_URL)

# Find page link
page_links = Array.new

if agent.page.parser.css('li.number').last  
  last_page_number = agent.page.parser.css('li.number').last.text.to_i

  # Page 1
  puts "(1/#{last_page_number})Analyzing #{GALLERY_URL}"
  page_links = (agent.page.parser.css("a.thumb") || agent.page.parser.css("a.thumb ismature")).map{|a| a["href"]}

  # Page 2 to last
  for pg_number in 2..last_page_number do 
    offset = (pg_number - 1) * 24
    gallery_link = GALLERY_URL + "?offset=" + offset.to_s 
    puts "(#{pg_number}/#{last_page_number})Analyzing #{gallery_link}" 
    agent.get(gallery_link)
    page_link = (agent.page.parser.css("a.thumb") || agent.page.parser.css("a.thumb ismature")).map{|a| a["href"]}
    page_links << page_link 
  end
  page_links.flatten!
else
  # Page 1
  puts "Analyzing #{GALLERY_URL}" 
  page_links = (agent.page.parser.css("a.thumb") || agent.page.parser.css("a.thumb ismature")).map{|a| a["href"]}
end

# Find image link and download. I guess the token has time limit, so download the image as soon as the download link was founded.
for index in 1..page_links.count
  agent.get(page_links[index - 1])
  download_link = agent.page.parser.css(".dev-page-button.dev-page-button-with-text.dev-page-download").map{|a| a["href"]}[0]
  title = agent.page.parser.css(".dev-title-container h1 a").text
  
  # Download
  begin 
    puts "(#{index}/#{page_links.count})Downloading \"#{title}\""
    file_name = download_link.split('?').first.split('/').last
    file_path = "deviantart/#{AUTHOR_NAME}/#{GALLERY_NAME}/#{file_name}"
    agent.get(download_link).save(file_path) unless File.exist?(file_path) 
  rescue :ex
    print ex.message, "\n" 
    next
  end
end

puts "\nAll download completed. Check deviantart/#{AUTHOR_NAME}/#{GALLERY_NAME}.\n\n"
t2 = Time.now
save = t2 - t1
puts "Time costs: #{(save/60).floor} mins #{(save%60).floor} secs."
