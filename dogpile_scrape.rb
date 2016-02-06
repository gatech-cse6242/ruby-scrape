require 'nokogiri'
require 'open-uri'
require 'watir-webdriver'
require 'uri'
require 'cgi'

terms = [
  'acne',
  'bullous disease',
  'melanoma',
  'melanoma lesion',
  'rosacea',
  'actinic keratosis',
  'dermatitis',
  'pimples',
  'lupus',
  'squamous cell carcinoma',
  'squamous cell carcinoma lesion',
  'basal cell carcinoma',
  'basal cell carcinoma lesion',
  'eczema',
  'psoriasis',
  'warts',
  'cellulitis',
  'rash',
  'lichen planus'
  'melanoma',
  'melanoma lesion'
]

base = 'http://www.dogpile.com/search/images?q='

main_dir = File.join(Dir.home, 'proj', 'dogpile')

threads = terms.map do |term|
  Thread.new(term) do |term|
    safe_term = term.downcase.tr(' ', '_')
    dir_path = File.join(main_dir, safe_term)

    unless File.directory?(dir_path)
      Dir.mkdir(dir_path, 0700)
      puts "Created new directory: #{dir_path}."
    else
      puts "Using existing directory: #{dir_path}."
    end

    search_url = base + URI::encode(term)
    page = 1

    b = Watir::Browser.new :firefox
    b.goto base + URI.encode(term)

    retries = 0

    while true
      begin
        # Wait until some results are ready.
        Watir::Wait.until { b.link(class: 'resultThumbnailLink').visible? }

        # Locate the links
        links = b.links(class: 'resultThumbnailLink')

        puts "Found #{links.count} links."

        links.each do |l|
          begin
            doc = Nokogiri::HTML(l.html)

            href = doc.css('a.resultThumbnailLink/@href').first

            if href
              src = href.value

              uri = URI.parse(src)
              params = CGI.parse(uri.query)

              if (ru = params['ru'].first)
                src = ru
                puts "Located image href - #{src}."
              else
                next
              end

              basename = File.basename(src)
              extname = File.extname(basename)

              image_path = File.join(dir_path, basename)

              if File.file?(image_path)
                basename = File.basename(src, '.*') + '_' + rand(1e6).to_s + extname
                image_path = File.join(dir_path, basename)
              end

              File.open(image_path, 'wb') do |f|
                begin
                  f.write(open(src).read)
                  puts "---> Success! Saved file at #{image_path}."
                rescue => e
                  puts '!--- Error! Error hitting link.'
                  next
                end
              end
            else
              puts "Failed to locate image href."
              next
            end
          rescue => e
            p '!--- Error! Hit error.'
            p e
            next
          end
        end

        # Click the next link
        li = b.li(css: "[data-page-number=\"#{page+1}\"]")

        if li.exists?
          puts "Going to next page - page #{page+1}."
          li.link.click
        else
          puts 'No further pages found. Done.'
          break
        end

        # Reset retries.
        retries = 0
        # Increment page.
        page += 1
      rescue => e
        p '!--- Error! Hit error.'
        p e
        retries += 1
        redo if retries < 3
      end
      # end of while
    end
  end
end

threads.each { |t| t.join }