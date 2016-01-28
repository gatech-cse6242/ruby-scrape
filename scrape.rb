#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

#
# Example of an extremely basic multi-threaded image scraper. Likely suitable
#   only for very small-volume scrapes.
#

class Scraper
  # Create a new Scraper.
  #
  # 'dir' is the directory in your home directory where you'll be storing the
  #   scraped images
  # 'host' is the website to be scraped with the protocol, e.g., http://google.com
  # 'base_path' is a helper that gives us a portion of the URI that remains
  #   static for most requests
  # 'pattern' is a lambda that contains a string interpolation for inserting
  #   search terms in the middle of a path
  # 'terms' is an array of terms to be searched
  # 'result_links', 'result_images', and 'target_images' are strings that tell
  #   us how to locate certain relevant DOM elements that we'll need to locate
  def initialize(opts = {})
    @dir = opts[:dir]
    @host = opts[:host]
    @base_path = opts[:base_path]
    @pattern = opts[:pattern]
    @terms = opts[:terms] || []
    @result_links = opts[:result_links]
    @result_images = opts[:result_images]
    @target_images = opts[:target_images]
  end

  # Orchestrates the pulling of image results.
  #
  # Creates a new thread for each search term and creates a new directory
  # corresponding to the search term. Once a result page is found, scrapes it.
  #
  # Uses Nokogiri's .css method to then retrieve links off the result page,
  # corresponding to other pages with image thumbnails.
  #
  # Once on the thumbnail pages, extracts the link to the full-size image and
  # retrieves the data, writing to disk.
  def scrape
    pull_results
  end

  private

  def pull_results
    threads = @terms.map do |term|
      Thread.new(term) do |term|
        safe_term = term.downcase.tr(' ', '_')
        dir_path = File.join(Dir.home, @dir, safe_term)

        unless File.directory?(dir_path)
          Dir.mkdir(dir_path, 0700)
          puts "Created new directory: #{dir_path}."
        else
          puts "Using existing directory: #{dir_path}."
        end

        scrape_path = @base_path + @pattern.call(URI.escape(term))
        puts "Getting from #{scrape_path}."

        result_page = Nokogiri::HTML(open(scrape_path))

        retried = false

        if result_links = result_page.css(@result_links)
          result_links.each do |result_link|
            begin
              puts "Retrying for #{term}..." if retried

              if href = result_link.value
                pull_images(href, dir_path)

                retried = false
                sleep(1)
              end
            rescue
              puts "Error! Connection reset. Sleeping for 11s."

              sleep(11)
              retried = true

              redo
            end
          end
        end
      end
    end

    threads.each { |t| t.join }
  end

  def pull_images(path, dir_path)
    scrape_path = @base_path + path

    result_page = Nokogiri::HTML(open(scrape_path))

    if result_image_links = result_page.css(@result_images)
      result_image_links.each do |ril|
        if href = ril.value
          image_path = @base_path + href
          image_page = Nokogiri::HTML(open(image_path))

          if target_image = image_page.css(@target_images).first
            src = target_image.value
            uri = @host + src

            basename = File.basename(uri)
            extname = File.extname(basename)

            image_path = File.join(dir_path, basename)

            if File.file?(image_path)
              basename = File.basename(uri, '.*') + '_' + rand(1e6).to_s + extname
              image_path = File.join(dir_path, basename)
            end

            File.open(image_path, 'wb') do |f|
              f.write(open(uri).read)
            end

            puts "---> Saved #{image_path}."
          end
        end
      end
    end
  end
end