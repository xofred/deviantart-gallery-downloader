require 'mechanize'
require 'netrc'

class DeviantartGalleryDownloader
  def self.fetch
    t1 = Time.now

    netrc_credential = create_or_update_credential
    create_image_directories
    connect_to_deviantart
    netrc_credential.nil? ? puts("You might not be able to fetch the age restricted resources") : login_to_deviantart(netrc_credential)
    go_to_gallery_page

    # Find page link
    page_links = [] 
    normal_link_selector = "div.tt-a.tt-fh a.thumb"
    mature_link_selector = "div.tt-a.tt-fh a.thumb ismature"
    # Find last page number
    last_page = @@agent.page.parser.css('.zones-top-left .pagination ul.pages li.number').last

    #The page number is just for information
    if last_page
      last_page_number = last_page.text
    elsif @@agent.page.parser.css('.zones-top-left .pagination ul.pages li.next a').first['href'].nil?
      last_page_number = '1'
    else
      last_page_number = '?'
    end

    pg_number = 1
    gallery_link = @@gallery_url

    loop do 
      #We fetch the curent page
      puts "(#{pg_number}/#{last_page_number})Analyzing #{gallery_link}"
      page_link = (@@agent.page.parser.css(normal_link_selector) || @@agent.page.parser.css(mature_link_selector)).map{|a| a["href"]}
      page_links << page_link 

      #If the curent page is the last page, we exit the loop
      break if @@agent.page.parser.css('.zones-top-left .pagination ul.pages li.next a').first['href'].nil?

      #If not, we load the next page
      pg_number = pg_number + 1
      offset = (pg_number - 1) * 24
      gallery_link = @@gallery_url.include?("?") ? @@gallery_url + "&" : @@gallery_url + "?" 
      gallery_link = gallery_link + "offset=" + offset.to_s 

      @@agent.get(gallery_link)
    end 
    page_links.flatten!

    # Find image link and download. I guess the token has time limit, so download the image as soon as the download link was founded.
    page_links.each_with_index do |page_link, index|
      retry_count = 0
      begin
        @@agent.get(page_link)
        download_link = @@agent.page.parser.css(".dev-page-button.dev-page-button-with-text.dev-page-download").map{|a| a["href"]}[0] || @@agent.page.parser.css(".dev-content-full").map{|img| img["src"]}[0] 
        title_art_elem = @@agent.page.parser.css(".dev-title-container h1 a")
        title_elem = title_art_elem.first
        title_art = title_art_elem.last.text
        title = title_elem.text

        puts "(#{index + 1}/#{page_links.count})Downloading \"#{title}\""

        #Sanitize filename
        file_name = download_link.split('?').first.split('/').last
        file_id = title_elem['href'].split('-').last
        file_ext = file_name.split('.').last
        file_title = title.strip().gsub(/\.+$/, '').gsub(/^\.+/, '').strip().squeeze(" ").tr('/\\', '-')

        file_name = title_art+'-'+file_title+'.'+file_id+'.'+file_ext
        file_path = "deviantart/#{@@author_name}/#{@@gallery_name}/#{file_name}"

        # Download
        @@agent.get(download_link).save(file_path) unless File.exist?(file_path) 
      rescue => ex
        puts ex.message
        if retry_count < 3
          retry_count = retry_count + 1
          puts "retrying..."
          retry
        else
          puts "failed after 3 retries, next"
          next
        end
      end
    end

    puts "\nAll download completed. Check deviantart/#{@@author_name}/#{@@gallery_name}.\n\n"
    t2 = Time.now
    save = t2 - t1
    puts "Time costs: #{(save/60).floor} mins #{(save%60).floor} secs."   
  end

  private

  def self.create_or_update_credential
    # Check if command right
    # Then check if .netrc file exist
    # Then check if entry exist
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

  def self.display_help_msssage
    puts "Usage first time:"
    puts "  ruby fetch.rb LOGIN-EMAIL PASSWORD GALLERY-URL"
    puts "For example:"
    puts "  ruby fetch.rb jack_bauer@ctu.com kim http://azoexevan.deviantart.com/gallery/"
    puts ""
    puts "After:"
    puts "  ruby fetch.rb -n GALLERY-URL"
    puts "For example:"
    puts "  ruby fetch.rb -n http://azoexevan.deviantart.com/gallery/"  
  end

  def self.create_image_directories
    @@home_url = "http://www.deviantart.com/"
    @@gallery_url = ARGV.size == 3 ? ARGV[2].to_s : ARGV[1].to_s
    @@author_name = @@gallery_url.split('.').first.split('//').last
    @@gallery_name = @@gallery_url.split('/').count == 6 ? @@gallery_url.split('/').last : @@gallery_name = "default-gallery"
    Dir.mkdir("deviantart") unless File.exists?("deviantart") do
      Dir.chdir("deviantart") do
        Dir.mkdir(@@author_name) unless File.exists?(@@author_name) do
          Dir.mkdir(@@gallery_name) unless File.exists?(@@gallery_name) 
        end
      end
    end
  end

  def self.connect_to_deviantart
    puts "Connecting to deviantART"
    @@agent = Mechanize.new
    retry_count = 0
    begin
      @@agent.get(@@home_url)
    rescue => ex
      puts ex.message
      if retry_count < 3
        retry_count = retry_count + 1
        puts "will retry after 1 second"
        sleep 1
        retry
      else
        puts "failed to connect to deviantART, abort"
        abort
      end
    end
    @@agent.pluggable_parser.default = Mechanize::Download   
  end

  def self.login_to_deviantart(netrc_credential)
    # Login 
    puts "Logging in" 
    retry_count = 0
    begin
      @@agent.page.form_with(:id => 'form-login') do |f|
        if ARGV.size == 3
          f.username = ARGV[0]
          f.password = ARGV[1]
        else
          f.username = netrc_credential["deviantart.com"].login
          f.password = netrc_credential["deviantart.com"].password
        end
      end.click_button
      if @@agent.cookie_jar.count < 3
        puts "Log on unsuccessful (maybe wrong login/pass combination?)"
        puts "You might not be able to fetch the age restricted resources"
      else
        puts "Log on successful"
      end
    rescue => ex
      puts ex.message
      if retry_count < 3
        retry_count = retry_count + 1
        puts "will retry after 1 second"
        sleep 1
        retry  
      else
        puts "login failed after 3 retries"
        puts "You might not be able to fetch the age restricted resources"
      end
    end   
  end

  def self.go_to_gallery_page
    retry_count = 0
    # Go to the gallery 
    puts "Connecting to gallery"
    begin
      @@agent.get(@@gallery_url)
    rescue => ex
      puts ex.message
      if retry_count < 3
        retry_count = retry_count + 1
        puts "will retry after 1 second"
        sleep 1
        retry
      else
        puts "failed to connect to gallery after 3 retries, abort"
        abort
      end
    end   
  end
end
