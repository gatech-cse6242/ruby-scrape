# Extremely basic Ruby image scraper

Note: this is only to serve as an example of using Nokogiri for DOM traversal
and other standard Ruby constructs.

## Example Usage

Create an array of search terms.

```
terms = [
  'acne',
  'rosacea',
  'keratosis',
  'basal cell carcinoma',
  'dermatitis',
  'bullous',
  'cellulitis',
  'eczema'
]
```

Specify a host (with protocol), and initialize your scraper.

```
# Where am I scraping?
host = 'http://www.dermis.net'

# Create a scraper
scraper = Scraper.new({
  # Directory to place images in
  dir: 'my_project',
  # Where we're scraping
  host: host,
  # Base path for most requests
  base_path: host + '/root_path',
  # Lambda containing a expression that will be evaluated for every search term
  #   to specify the search path
  pattern: -> (term) { "results/#{term}/search" },
  # List of terms
  terms: terms,
  # Strings specifying the location of relevant nodes in the DOM
  result_links: '#maindiv a/@href',
  result_images: '#maindiv a/@href',
  target_images: '#maindiv .important a>img/@src'
})

# Let's scrape.
scraper.scrape
```