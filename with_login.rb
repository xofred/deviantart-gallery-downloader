#require 'rubygems'
require 'mechanize'
require 'pry'

abort "#{$0} login passwd gallery_full_url" if (ARGV.size != 3)

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

puts "Connecting to deviantART..."
HEADERS_HASH = {"User-Agent" => "Ruby/#{RUBY_VERSION}"}
agent = Mechanize.new
agent.get(HOME_URL)
agent.pluggable_parser.default = Mechanize::Download

# Login 
puts "Logging in..." 
agent.page.form_with(:id => 'form-login') do |f|
  f.username = ARGV[0]
  f.password = ARGV[1]
end.click_button

# Go to the gallery 
puts "Connecting to gallery..."
agent.get(GALLERY_URL)

page_links = Array.new 
page_links << GALLERY_URL
a_links_first_page = Array.new
a_links = Array.new
image_links_first_page = Array.new
image_links_next_page = Array.new
image_links = Array.new
if agent.page.parser.css('li.number').last  
  last_page_number = agent.page.parser.css('li.number').last.text.to_i

  # Page 1
  puts "Analyzing #{GALLERY_URL}..."
  a_links_first_page = (agent.page.parser.css("a.thumb") || agent.page.parser.css("a.thumb ismature"))
  image_links_first_page = a_links_first_page.map{|thumb| thumb["data-super-img"]}.compact.uniq
  image_links = image_links_first_page

  # Page 2 to last
  for pg_number in 2..last_page_number do 
    offset = (pg_number - 1) * 24
    page_link = GALLERY_URL + "?offset=" + offset.to_s 
    puts "Analyzing #{page_link}..." 
    agent.get(page_link)
    a_links = (agent.page.parser.css("a.thumb") || agent.page.parser.css("a.thumb ismature"))
    image_links_next_page = a_links.map{|thumb| thumb["data-super-img"]}.compact.uniq
    page_links << page_link 
    image_links = image_links + image_links_next_page
  end
else
  # Page 1
  puts "Analyzing #{GALLERY_URL}..."
  a_links_first_page = (agent.page.parser.css("a.thumb") || agent.page.parser.css("a.thumb ismature"))
  image_links_first_page = a_links_first_page.map{|thumb| thumb["data-super-img"]}.compact.uniq
  image_links = image_links_first_page
end

puts "Total #{page_links.length} pages, #{image_links.count} images. Now start downloading.\n\n"

image_links.each_with_index { |link, index| 
  print "(#{index + 1}/#{image_links.count})"
  puts "Downloading #{link}..."
  file_name = link.to_s.split('/').last
  file_path = "deviantart/#{AUTHOR_NAME}/#{GALLERY_NAME}/#{file_name}"
  agent.get(link).save(file_path) unless File.exist?(file_path) 
}

puts "\nAll download completed. Check deviantart/#{AUTHOR_NAME}/#{GALLERY_NAME}."
