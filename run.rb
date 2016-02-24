require 'typhoeus'
require 'yaml'
require 'ruby-thumbor'
require 'fileutils'
require 'pp'

# setup
stamp     = Time.now.to_i.to_s
@passed   = true
@config   = YAML.load_file('config.yml')
@crypto   = Thumbor::CryptoURL.new @config[:thumbor_key]
@results  = {}

# make the test dir
@pwd = File.expand_path( File.dirname(__FILE__) )
Dir.mkdir(File.join(@pwd, "source/images/results"), 0700) unless File.exists?("source/images/results")
Dir.mkdir(File.join(@pwd, "source/images/results/#{stamp}"), 0700)


def handle(response, result)
  if response.success?
    File.open(result[:file], "wb") do |file|
      file.write(response.response_body)
    end
    result[:response_time] = response.time
  elsif response.timed_out?
    result[:fail] = true
    result[:fail_reason] = "Request timed out"
  elsif response.code == 0
    result[:fail] = true
    result[:fail_reason] = "Request failed with no HTTP response"
  else
    result[:fail] = true
    result[:fail_reason] = "Unknown request error: #{response.response_headers}"
  end
end

def get_thumbor_url(image)
  merged = image[:options].merge({
    :image => image[:original]
    # :image => image[:original].sub(/^https?\:\/\//, '').sub(/^www./,'') # breaks on hymnal images
  })
  @config[:thumbor_host] + (@crypto.generate merged)
end



@config[:images].each_with_index do |image, index|
  # unique, request set
  hydra = Typhoeus::Hydra.new(max_concurrency: 2)
  @results[index.to_s] = {}
  @results[index.to_s][:label] = image[:label]
  save_dir = "source/images/results/#{stamp}/#{index}"
  FileUtils.mkdir_p File.join(@pwd, save_dir)

  ['original', 'transformed'].each do |version|
    @results[index.to_s][version.to_sym] = {
      file:           File.join(@pwd, "#{save_dir}/#{version}.jpg"),
      response_time:  0
    }
    image_url = version == 'original' ? image[version.to_sym] : get_thumbor_url(image)
    re = Typhoeus::Request.new(image_url)
    re.on_complete { |response| handle(response, @results[index.to_s][version.to_sym] ) }
    hydra.queue(re)
  end

  hydra.run


  # caclulate DSSIM
  unless @results[index.to_s][:original][:fail] || @results[index.to_s][:transformed][:fail]
    original_png    = @results[index.to_s][:original][:file].split('.')[0] + '.png'
    transformed_png = @results[index.to_s][:transformed][:file].split('.')[0] + '.png'

     @results[index.to_s][:original][:file_size] = `stat -f%z #{@results[index.to_s][:original][:file]}`.chomp
    `convert #{@results[index.to_s][:original][:file]} #{original_png}`

    @results[index.to_s][:transformed][:file_size] = `stat -f%z #{@results[index.to_s][:transformed][:file]}`.chomp
    `convert #{@results[index.to_s][:transformed][:file]} #{transformed_png}`

    @results[index.to_s][:dssim] = `dssim -o "#{save_dir}/difference.png" #{original_png} #{transformed_png}`.split(' ')[0]
    @results[index.to_s][:dssim_image] = File.join(@pwd, "#{save_dir}/difference.png")

    if @results[index.to_s][:dssim].to_f > @config[:dssim_threshold].to_f
      @results[index.to_s][:transformed][:fail] = true
      @results[index.to_s][:transformed][:fail_reason] = "DSSIM of #{@results[index.to_s][:dssim]} if over the max threshold of #{@config[:dssim_threshold]}"
    end
  end
end


File.open(File.join(@pwd, "source/images/results/#{stamp}/results.yml"), "w") do |file|
  file.write @results.to_yaml
end


@results.each do |key, result|
  if result[:transformed][:fail]
    @passed = false
    puts "Image #{key} failed: #{result[:transformed][:fail_reason]}"
  end

  if result[:original][:fail]
    @passed = false
    puts "Image #{key} failed: #{result[:original][:fail_reason]}"
  end
end

if @passed
  puts "Passed"
  exit 0
else
  abort "Failed"
end
