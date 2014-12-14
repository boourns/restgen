require 'erb'
require 'json'
require 'active_support/all'
require 'pp'
require './lib/generator'
require 'byebug'
require 'net/http'

if ARGV.size != 3
  puts "\n\nUsage: ruby restgen.rb (package name) (schema stem) (starting endpoint)\n\n\n"
  exit
end

stem = JSON.parse(File.read(ARGV[1]))

examples_dir = File.dirname(ARGV[1])

Dir.mkdir(ARGV[0]) rescue nil

Generator.package = ARGV[0]

def get(uri, endpoint) 
  uri = URI.parse(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  request = Net::HTTP::Get.new("#{uri.path}/#{endpoint}.json", {'Content-Type' =>'application/json'})
  request.basic_auth(uri.user, uri.password)

  http.request(request)
end

missing = []

stem.each do |klass|
  name = klass["name"]

  endpoint = name.underscore.pluralize

  example = nil
  example_file = "#{examples_dir}/#{name.underscore}.json"

  if File.exist?(example_file)
    puts "#{example_file} exists, using as schema for #{name}"
    example = JSON.parse(File.read(example_file))
  else
    puts "#{example_file} does not exist, attempting to fetch"

    result = get(ARGV[2], endpoint)

    if result.code != "200"
      puts "Skipping rendering #{name} because index method failed, result #{result.code}"
      missing << example_file
      next
    end

    example = JSON.parse(result.body)[endpoint].first
    if example != nil
      File.write(example_file, JSON.dump(example))
    end
  end

  if example == nil
    puts "Skipping rendering #{name} because index GET returned []"
    missing << example_file
    next
  end

  Generator.new(klass, example)
end

# twice - on first pass we might find new sub-types
2.times do
  Generator.klasses.values.each do |k|
    k.parse
    output = "./#{ARGV[0]}/#{k.name.underscore}.go"
    k.render(output, File.read("./templates/template.go.erb"))
  end
end

puts "Missing the following example JSON structs:"
puts missing.join("\n")

