#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'uri'
require 'fileutils'

# Simple importer from Semantic Scholar authorId to Jekyll _publications/*.md
# Usage: ruby assets/js/semantic_scholar_import.rb <authorId>

def http_get(url)
  uri = URI.parse(url)
  req = Net::HTTP::Get.new(uri)
  req['User-Agent'] = 'academic-homepage-import/1.0'
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
    res = http.request(req)
    raise "HTTP #{res.code} when fetching #{url}" unless res.is_a?(Net::HTTPSuccess)
    res.body
  end
end

def sanitize_filename(name)
  name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-+|-+$/, '')
end

author_id = ARGV[0]
if author_id.nil? || author_id.strip.empty?
  STDERR.puts 'Usage: ruby assets/js/semantic_scholar_import.rb <authorId>'
  exit 1
end

base_dir = File.expand_path(File.join(__dir__, '..', '..'))
pub_root = File.join(base_dir, '_publications')
FileUtils.mkdir_p(pub_root)

fields = %w[title year venue publicationTypes externalIds authors abstract]
api_url = "https://api.semanticscholar.org/graph/v1/author/#{author_id}/papers?fields=#{fields.join(',')}&limit=200"

data = JSON.parse(http_get(api_url))
papers = data.fetch('data', [])

own_name = 'Youngbin Choi'

papers.each do |paper|
  p = paper['paper'] || paper
  title = p['title'] || 'Untitled'
  year = (p['year'] || 1900).to_i
  venue = p['venue'] || (p['publicationTypes'] || []).join(', ')
  abstract = (p['abstract'] || '').strip
  authors = (p['authors'] || []).map { |a| a['name'] }
  links = []
  if p['externalIds']
    if p['externalIds']['DOI']
      links << [ 'DOI', "https://doi.org/#{p['externalIds']['DOI']}" ]
    end
    if p['externalIds']['ArXiv']
      links << [ 'arXiv', "https://arxiv.org/abs/#{p['externalIds']['ArXiv']}" ]
    end
    if p['externalIds']['CorpusId']
      links << [ 'SemanticScholar', "https://www.semanticscholar.org/paper/#{p['externalIds']['CorpusId']}" ]
    end
  end

  year_dir = File.join(pub_root, year.to_s)
  FileUtils.mkdir_p(year_dir)
  slug = sanitize_filename(title)[0,60]
  path = File.join(year_dir, sprintf('%04d-%s.md', year, slug.empty? ? 'paper' : slug))

  front = []
  front << '---'
  front << "title: \"#{title.gsub('"','\"')}\""
  front << "date: #{year}-01-01 00:00:00 +0900"
  front << 'selected: false'
  front << "pub: \"#{venue.gsub('"','\"')}\""
  front << "pub_date: \"#{year}\""
  front << 'abstract: >-'
  if abstract.empty?
    front << '  '
  else
    abstract.split("\n").each { |line| front << "  #{line}" }
  end
  front << 'authors:'
  authors.each do |name|
    if name == own_name
      front << "- #{own_name}*"
    else
      front << "- #{name}"
    end
  end
  unless links.empty?
    front << 'links:'
    links.each do |kv|
      label, url = kv
      front << "  #{label}: #{url}"
    end
  end
  front << '---'

  File.write(path, front.join("\n") + "\n")
  puts "Wrote #{path}"
end

puts "Imported #{papers.size} papers."


