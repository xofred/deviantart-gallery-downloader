require 'mechanize'
require 'netrc'

class DeviantartGalleryDownloader
  attr_accessor :agent, :gallery_url, :author_name, :gallery_name
  DA_ENDPOINT = 'https://www.deviantart.com/'
  HOME_URL = "#{DA_ENDPOINT}users/login"

  def initialize
    @agent = Mechanize.new
    @agent.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36'
    @agent.request_headers = { 'Referer' => DA_ENDPOINT }
    @gallery_url = ARGV.size == 3 ? ARGV[2].to_s : ARGV[1].to_s
    find_out_which_kind_of_gallery
    @image_page_selector = '#sub-folder-gallery > div > div:nth-child(2) > div > div > div > div > div > div > section > a'
    @download_button_selector = '#root > main > div > div > section > div > div > div:nth-child(3) > span:nth-child(3) > div > div > a'
    @image_selector = '#root > main > div > div > div > div > div > div > div > img'
    @image_title_selector = '#root > main > div > div > div > div > div > div > div > h1'
  end

  def fetch
    t1 = Time.now

    create_image_directories
    netrc_credential = create_or_update_credential
    login_to_deviantart(netrc_credential)
    image_page_links = get_image_page_links
    image_page_links.each_with_index do |page_link, index|
      retry_count = 0
      begin
        @agent.get(page_link)
        download_button_link = @agent.page.parser.css(@download_button_selector).map{|a| a["href"]}[0]
        image_link = @agent.page.parser.css(@image_selector).map{|img| img["src"]}[0]
        download_link = download_button_link || image_link
        next puts "can't find download link or image src in #{page_link}" if !download_link

        file_path = get_file_path(index, image_page_links, download_link)
        next print "image already exist, skiped\n" if File.exist?(file_path)

        @agent.get(download_link).save(file_path)
        print "download completed\n"
      rescue => ex
        puts ex.message
        puts ex.backtrace.join("\n")
        if retry_count < 3
          retry_count += 1
          puts "retrying..."
          retry
        else
          next "failed after 3 retries, next"
        end
      end
    end

    puts "\nAll download completed. Check deviantart/#{@author_name}/#{@gallery_name}\n\n"
    t2 = Time.now
    save = t2 - t1
    puts "Time costs: #{(save/60).floor} mins #{(save%60).floor} secs."
  end

  private

  def find_out_which_kind_of_gallery
    begin
      if @gallery_url.split(DA_ENDPOINT)[1].split('/').size == 2 && @gallery_url.split(DA_ENDPOINT)[1].split('/')[-1] == 'gallery'
        # https://www.deviantart.com/kalfy/gallery
        @author_name = @gallery_url.split(DA_ENDPOINT)[1].split('/')[0]
        @gallery_name = "default-gallery" # aka 'Featured'
        @gallery_url = @gallery_url.chop if @gallery_url[-1] == '/'
      elsif @gallery_url.split(DA_ENDPOINT)[1].split('/gallery')[1] == '/all' ||
        @gallery_url.split(DA_ENDPOINT)[1].split('/gallery')[1] == '/all/'
        # https://www.deviantart.com/kalfy/gallery/all
        @author_name = @gallery_url.split(DA_ENDPOINT)[1].split('/')[0]
        @gallery_name = 'all'
        @gallery_url = @gallery_url.chop if @gallery_url[-1] == '/'
      elsif @gallery_url.split(DA_ENDPOINT)[1].split('/gallery')[1].split('/').size == 3
        # https://www.deviantart.com/kalfy/gallery/72183557/characters
        @author_name = @gallery_url.split(DA_ENDPOINT)[1].split('/')[0]
        @gallery_name = @gallery_url.split(DA_ENDPOINT)[1].split('/gallery')[1].split('/')[-1]
        @gallery_url = @gallery_url.chop if @gallery_url[-1] == '/'
      else
        puts "Probably not a valid deviantart gallery url, abort"
        display_help_msssage
        abort
      end
    rescue
      puts "Probably not a valid deviantart gallery url, abort"
      display_help_msssage
      abort
    end
  end

  def create_or_update_credential
    if ARGV.size == 2 && ARGV[0] == "-n"
      if n = Netrc.read
        if n["deviantart.com"]
          puts "Using netrc's credential"
          n
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
          n
        else
          puts "Creating netrc's entry"
          #n.new_item_prefix = "# This entry was added by deviantart-gallery-downloader automatically\n"
          n["deviantart.com"] = ARGV[0], ARGV[1]
          n.save
          n
        end
      rescue => ex
        puts "#{ex.message}, writing .netrc file failed, continue.\n"
      end
    else
      display_help_msssage
      abort
    end
  end

  def display_help_msssage
    puts "----------"
    puts "Usage:\n\n"
    puts "On the intital run, we need to add your login credential to your users ~/.netrc file, so we don't leave your username and password in the process ID,"
    puts "which could be seen by other users on the system (note: the initial run of this script will show up in your bash history)."
    puts ""
    puts "ruby fetch.rb YOUR_USERNAME YOUR_PASSWORD https://www.deviantart.com/kalfy/gallery"
    puts ""
    puts "An entry in ~/.netrc is created for you. You can then use '-n' and it will poll the netrc file for your login credentials."
    puts ""
    puts "(Featured)      ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery"
    puts "(all)           ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery/all"
    puts "(some gallery)  ruby fetch.rb -n https://www.deviantart.com/kalfy/gallery/72183557/characters"
    puts "----------"
  end

  def create_image_directories
    Dir.mkdir("deviantart") unless File.exists?("deviantart") do
      Dir.chdir("deviantart") do
        Dir.mkdir(@author_name) unless File.exists?(@author_name) do
          Dir.mkdir(@gallery_name) unless File.exists?(@gallery_name)
        end
      end
    end
  end

  def login_to_deviantart(netrc_credential)
    puts "Logging in"
    retry_count = 0
    begin
      @agent.get(HOME_URL)
      @agent.page.form_with(:action => '/_sisu/do/signin') do |f|
        if ARGV.size == 3
          f.username = ARGV[0]
          f.password = ARGV[1]
        else
          f.username = netrc_credential["deviantart.com"].login
          f.password = netrc_credential["deviantart.com"].password
        end
      end.click_button
      if @agent.cookie_jar.count < 3
        puts "Log on unsuccessful (maybe wrong login/pass combination?)"
        puts "You might not be able to fetch the age restricted resources"
      else
        puts "Log on successful"
      end
      @agent.pluggable_parser.default = Mechanize::Download
    rescue => ex
      puts ex.message
      if retry_count < 3
        retry_count += 1
        puts "Will retry after 1 second"
        sleep 1
        retry
      else
        puts "Login failed after 3 retries"
        puts "You might not be able to fetch the age restricted resources"
      end
    end
  end

  def get_image_page_links
    retry_count = 0
    puts "Connecting to gallery"
    begin
      gallery_link = @gallery_url
      @agent.get(gallery_link)
      page_links = []
      last_page_number = get_last_page_number
      last_page_number.times do |i|
        current_page_number = i + 1
        puts "(#{current_page_number}/#{last_page_number})Analyzing #{gallery_link}"
        page_links_of_this_page = @agent.page.parser.css(@image_page_selector).map{|a| a["href"]}
        page_links << page_links_of_this_page
        gallery_link = @gallery_url + "?page=#{current_page_number + 1}"
        @agent.get(gallery_link)
      end
      page_links = page_links.flatten.uniq
      page_links
    rescue => ex
      puts ex.message
      if retry_count < 3
        retry_count += 1
        puts "will retry after 1 second"
        sleep 1
        retry
      else
        abort "failed to connect to gallery after 3 retries, abort"
      end
    end
  end

  def get_file_path(index, image_page_links, download_link)
    title_elem = @agent.page.parser.css(@image_title_selector)
    title = title_elem.text
    print "(#{index + 1}/#{image_page_links.count})Downloading \"#{title}\"..."

    #Sanitize filename
    file_name = download_link.split('?').first.split('/').last
    file_ext = file_name.split('.').last
    file_title = title.strip().gsub(/\.+$/, '').gsub(/^\.+/, '').strip().squeeze(" ").tr('/\\', '-')
    file_name = file_title+'.'+file_ext

    "deviantart/#{@author_name}/#{@gallery_name}/#{file_name}"
  end

  def get_last_page_number
    page_numbers = @agent.page.parser.css('#sub-folder-gallery > div > div:nth-child(3) > div > a')
    last_page = page_numbers[-2] # the last one is 'Next', so it should be the one before
    return last_page.text.to_i if last_page

    return 1 if @agent.page.parser.css(@image_page_selector).any?

    abort "gallery has no images, abort"
  end
end
