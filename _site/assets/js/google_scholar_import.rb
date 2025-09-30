#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'json'
require 'fileutils'

# Import publications from Google Scholar list_works JSON and write Jekyll Markdown files under _publications/YYYY
# Usage: ruby assets/js/google_scholar_import.rb <scholar_user_id> [max_pages]

def http_get(url)
  uri = URI.parse(url)
  req = Net::HTTP::Get.new(uri)
  req['User-Agent'] = 'academic-homepage-gs-import/1.0'
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    res = http.request(req)
    raise "HTTP #{res.code} for #{url}" unless res.is_a?(Net::HTTPSuccess)
    res.body
  end
end

def sanitize_filename(name)
  name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-+|-+$/, '')
end

def extract_rows_from_json(html_json)
  # html_json contains HTML rows snippet under key B from Google Scholar
  html = html_json
  rows = html.split('<tr class="gsc_a_tr"')
  rows.shift
  rows.map { |r| '<tr class="gsc_a_tr"' + r }
end

def parse_row(row_html)
  # title
  title = row_html[/class="gsc_a_at"[^>]*>(.*?)<\/a>/m, 1]
  title = title ? title.strip.gsub(/\s+/, ' ') : 'Untitled'
  # authors: first gs_gray
  gs_grays = row_html.scan(/<div class="gs_gray">(.*?)<\/div>/m).flatten
  authors_line = gs_grays[0] || ''
  venue_line = gs_grays[1] || ''
  authors = authors_line.split(/,\s*/).map { |s| s.strip }
  # venue and year
  year = row_html[/class="gsc_a_h gsc_a_hc gs_ibl"\>(\d{4})<\/span>/, 1]
  year = year ? year.to_i : 1900
  venue = venue_line.gsub(/<span[^>]*>.*?<\/span>/, '').strip
  [title, authors, venue, year]
end

user = ARGV[0]
max_pages = (ARGV[1] || '5').to_i
if user.nil? || user.strip.empty?
  STDERR.puts 'Usage: ruby assets/js/google_scholar_import.rb <scholar_user_id> [max_pages]'
  exit 1
end

base_dir = File.expand_path(File.join(__dir__, '..', '..'))
pub_root = File.join(base_dir, '_publications')
FileUtils.mkdir_p(pub_root)

own_name = 'Youngbin Choi'

page = 0
total = 0
loop do
  break if page >= max_pages
  url = "https://scholar.google.com/citations?hl=en&user=#{user}&view_op=list_works&sortby=pubdate&cstart=#{page*100}&pagesize=100&json=1"
  body = http_get(url)
  json = JSON.parse(body) rescue nil
  break unless json && json['B']
  rows = extract_rows_from_json(json['B'])
  break if rows.empty?
  rows.each do |row|
    title, authors, venue, year = parse_row(row)
    year = 1900 if year.nil? || year == 0
    year_dir = File.join(pub_root, year.to_s)
    FileUtils.mkdir_p(year_dir)
    slug = sanitize_filename(title)[0, 60]
    filepath = File.join(year_dir, sprintf('%04d-%s.md', year, slug.empty? ? 'paper' : slug))
    front = []
    front << '---'
    front << "title: \"#{title.gsub('"','\"')}\""
    front << "date: #{year}-01-01 00:00:00 +0900"
    front << 'selected: false'
    front << "pub: \"#{venue.gsub('"','\"')}\""
    front << "pub_date: \"#{year}\""
    front << 'abstract: >-'
    front << '  '
    front << 'authors:'
    authors.each do |name|
      if name == own_name || name == 'Y Choi' || name == 'Youngbin Choi'
        front << "- #{own_name}*"
      else
        front << "- #{name}"
      end
    end
    front << 'links:'
    front << '  GoogleScholar: https://scholar.google.com/scholar'
    front << '---'
    File.write(filepath, front.join("\n") + "\n")
    total += 1
  end
  page += 1
end

puts "Imported/updated ~#{total} items from Google Scholar."


