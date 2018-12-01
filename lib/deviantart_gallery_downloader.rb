require 'mechanize'
require 'netrc'
require 'fileutils'

class DeviantartGalleryDownloader
  attr_accessor :agent, :gallery_url, :author_name
  HOME_URL = "https://www.deviantart.com/users/login"

  def initialize
    @agent = Mechanize.new
    @agent.user_agent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36'
    @agent.request_headers = { 'Referer' => 'https://www.deviantart.com/' }
    @gallery_url = ARGV.size == 3 ? ARGV[2].to_s : ARGV[1].to_s
    @author_name = @gallery_url.split('.com/').last.split('/').first
  end

  def fetch
    t1 = Time.now

    netrc_credential = create_or_update_credential
    login_to_deviantart(netrc_credential)

    folders = get_folders
    puts "\n#{folders.size} folders found:\n\n"
    folders.map {|folder| puts "#{folder[:name]}"}
    puts "\n"
    create_image_directories(folders)

    folders.each do |folder|
      image_page_links = get_image_page_links(folder[:link])
      next if image_page_links.nil?
      image_page_links.each_with_index do |page_link, index|
        retry_count = 0
        begin
          @agent.get(page_link)
          download_button_link = @agent.page.parser.css(".dev-page-button.dev-page-button-with-text.dev-page-download").map{|a| a["href"]}[0]
          image_link = @agent.page.parser.css(".dev-content-full").map{|img| img["src"]}[0]
          if ARGV[0].include?("-s")
            download_link = image_link
          else
            download_link = download_button_link || image_link
          end
          if not download_link.nil?
            file_path = get_file_path(index, image_page_links, download_link, folder[:name], true)
            @agent.get(download_link).save(file_path) unless File.exist?(file_path)
          else
            page_path = get_file_path(index,image_page_links, page_link, folder[:name], false)
            #@agent.page.parser.css("div.text").save(page_path) unless File.exist?(page_path)
            @agent.page.save(page_path) unless File.exist?(page_path)
          end
        rescue => ex
          puts ex.message
          if retry_count < 3
            retry_count += 1
            puts "retrying..."
            retry
          else
            next "failed after 3 retries, next"
          end
        end
      end
      
      puts "\nAll download completed. Check deviantart/#{@author_name}/#{folder[:name]}\n\n"
      t2 = Time.now
      save = t2 - t1
      puts "Time costs: #{(save/60).floor} mins #{(save%60).floor} secs."
    end
  end

  private

  def create_or_update_credential
    if ARGV.size == 2 && ARGV[0].include?("-n")
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
    puts "The downloader uses GALLERY'S PAGE"
    puts ""
    puts "On the intital run, we need to add your login credential to your users ~/.netrc file, so we don't leave your username and password in the process ID,"
    puts "which could be seen by other users on the system (note: the initial run of this script will show up in your bash history)."
    puts ""
    puts "ruby fetch.rb YOUR_USERNAME YOUR_PASSWORD http://azoexevan.deviantart.com/gallery/"
    puts ""
    puts "An entry in ~/.netrc is created for you. You can then use '-n' and it will poll the netrc file for your login credentials."
    puts ""
    puts "ruby fetch.rb -n http://azoexevan.deviantart.com/gallery/"
  end

  def create_image_directories(folders)
    Dir.mkdir("deviantart") unless File.exists?("deviantart")
    Dir.chdir("deviantart") do
      Dir.mkdir(@author_name) unless File.exists?(@author_name)
      Dir.chdir(@author_name) do
        folders.each do |folder|
          Dir.mkdir(folder[:name]) unless File.exists?(folder[:name])
        end
        if File.exists?('default-gallery') # For compatibility
          FileUtils.mv(Dir['default-gallery/*'],'Featured')
        end
      end
    end
  end

  def login_to_deviantart(netrc_credential)
    puts "Logging in" 
    retry_count = 0
    begin
      @agent.get(HOME_URL)
      @agent.page.form_with(:id => 'login') do |f|
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

  def get_folders
    @agent.get(@gallery_url)

    gallery_folders = @agent.page.parser.css('.tv150-cover')
    folders = []
    if gallery_folders.length > 0
      gallery_folders.each do |folder|
        link = folder['href']
        name = link.split('/').last
        folders.push({link: link, name: name})
        subfolders = get_folders_in_folder(link,name)
        if not subfolders.nil?
          folders.concat(subfolders)
        end
      end
    end
    folders.push({link: @gallery_url, name: 'Featured'})
    folders
  end

  def get_folders_in_folder(parent_link,parent_name)
    @agent.get(parent_link)

    gallery_folders = @agent.page.parser.css('.tv150-cover')
    folders = []
    if gallery_folders.length > 0
      gallery_folders.each do |folder|
        link = folder['href']
        name = "#{parent_name}/#{link.split('/').last}"
        folders.push({link: link, name: name})
        subfolders = get_folders_in_folder(link,name)
        if not subfolders.nil?
          folders.concat(subfolders)
        end
      end
    end
    folders
  end

  def get_image_page_links(folder_link)
    retry_count = 0
    puts "Connecting to #{folder_link}"
    begin
      @agent.get(folder_link)
      image_page_links = []
      link_selector = 'a.torpedo-thumb-link'
      last_page_number = get_last_page_number
      
      return if last_page_number == 0
      
      folder_link = folder_link.include?("?") ? folder_link + "&" : folder_link + "?"

      last_page_number.times do |i|
        current_page_number = i + 1
        current_page_link = folder_link + "offset=" + ((current_page_number - 1) * 24).to_s
        puts "(#{current_page_number}/#{last_page_number})Analyzing #{current_page_link}"
        current_page_image_links = @agent.page.parser.css(link_selector).map{|a| a["href"]}
        image_page_links.push(current_page_image_links)
        next_page_link = folder_link + "offset=" + (current_page_number * 24).to_s
        @agent.get(next_page_link)
      end
      image_page_links.flatten!
    rescue => ex
      ex.backtrace.each do |detail|
        puts detail
      end
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

  def get_file_path(index, image_page_links, download_link, folder_name, is_image)
    title_art_elem = @agent.page.parser.css(".dev-title-container h1 a")
    title_elem = title_art_elem.first
    title_art = title_art_elem.last.text
    title = title_elem.text

    #Sanitize filename
    file_name = download_link.split('?').first.split('/').last
    file_id = title_elem['href'].split('-').last
    
    if is_image
      file_ext = @agent.page.parser.css(".dev-page-button.dev-page-button-with-text.dev-page-download").text.split(' ')[1] # Use the 'download' button, if it exists, to figure out the file extension.
	  if file_ext.nil?
		file_ext = 'jpg' # if there's no download button, we need to pick something, and it's probably an image...
	  end
      puts "(#{index + 1}/#{image_page_links.count})Downloading \"#{title}\""
    else
      file_ext = 'htm'
      puts "(#{index + 1}/#{image_page_links.count})Saving \"#{title}\""
    end
    
    file_title = title.strip().gsub(/\.+$/, '').gsub(/^\.+/, '').strip().squeeze(" ").tr('/:?\\', '-')

    file_name = title_art+'-'+file_title+'.'+file_id+'.'+file_ext
    file_path = "deviantart/#{@author_name}/#{@gallery_name}/#{folder_name}/#{file_name}"
  end

  def get_last_page_number
    page_numbers_selector = '.zones-top-left .pagination ul.pages li.number'
    last_page = @agent.page.parser.css(page_numbers_selector).last

    if last_page
      last_page_number = last_page.text.to_i
    elsif @agent.page.parser.css('.torpedo-thumb-link img').any?
      last_page_number = 1
    else
      puts "gallery has no images, skipping"
      last_page_number = 0
    end
  end
end
