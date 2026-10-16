require 'fileutils'
require 'open-uri'
require 'time'
require 'digest'

POSTS_DIR = File.join(__dir__, 'medium-import', 'posts')
OUTPUT_DIR = File.join(__dir__, '_posts')
IMAGES_DIR = File.join(__dir__, 'assets', 'images')

FileUtils.mkdir_p(OUTPUT_DIR)
FileUtils.mkdir_p(IMAGES_DIR)

def slugify(text)
  text.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-+|-+$/, '')
end

def download_image(url, images_dir)
  ext = File.extname(url.split('?').first)
  ext = '.jpg' if ext.empty? || ext.length > 5
  hash = Digest::MD5.hexdigest(url)
  filename = "#{hash}#{ext}"
  local_path = File.join(images_dir, filename)

  unless File.exist?(local_path)
    begin
      URI.open(url) do |remote|
        File.open(local_path, 'wb') { |f| f.write(remote.read) }
      end
      puts "  Downloaded: #{url}"
    rescue => e
      puts "  FAILED to download #{url}: #{e.message}"
      return nil
    end
  end

  "/assets/images/#{filename}"
end

Dir.glob(File.join(POSTS_DIR, '*.html')).sort.each do |filepath|
  content = File.read(filepath)
  filename = File.basename(filepath)

  title_match = content.match(/<h1[^>]*class="[^"]*p-name[^"]*"[^>]*>(.*?)<\/h1>/m)
  title = title_match ? title_match[1].gsub(/<[^>]+>/, '').strip : filename.gsub('.html', '')

  time_match = content.match(/<time[^>]*datetime="([^"]+)"/)
  unless time_match
    puts "SKIPPING #{filename} -- no datetime found"
    next
  end
  timestamp = Time.parse(time_match[1])

  body_match = content.match(/<section[^>]*data-field="body"[^>]*>(.*?)<\/section>/m)
  body = body_match ? body_match[1] : content

  body = body.gsub(/<img[^>]+src="([^"]+)"[^>]*>/) do |img_tag|
    src = $1
    local_src = download_image(src, IMAGES_DIR)
    local_src ? img_tag.sub(src, local_src) : img_tag
  end

  date_str = timestamp.strftime('%Y-%m-%d')
  slug = slugify(title)
  slug = filename.gsub('.html', '').gsub(/^\d{4}-\d{2}-\d{2}_/, '') if slug.empty?
  out_filename = "#{date_str}-#{slug}.html"
  out_path = File.join(OUTPUT_DIR, out_filename)

  front_matter = <<~FM
    ---
    layout: post
    title: "#{title.gsub('"', '\\"')}"
    date: #{timestamp.strftime('%Y-%m-%d %H:%M:%S %z')}
    ---
  FM

  File.write(out_path, front_matter + "\n" + body)
  puts "Created: #{out_filename}"
end

puts "\nDone. #{Dir.glob(File.join(OUTPUT_DIR, '*.html')).length} posts now in _posts/"
