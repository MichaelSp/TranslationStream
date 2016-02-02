#!/usr/bin/env ruby

# Required software:
####################
# 
# sudo apt-get install qrencode icecast2 rbenv
# rbenv install 2.2.3 && rbenv global 2.2.3
#

require 'webrick'

http_port = 5000
host_ip = `dig +short \`hostname\``.chomp
shout_url = "http://#{host_ip}:8000"
web_url = "http://#{host_ip}:#{http_port}"
stream_name = "stream"
stream_url = "#{shout_url}/#{stream_name}.mp3"

puts "Update qrcode"
`qrencode -o stream_qrc.png -s 5 '#{stream_url}'`

puts "Update index.html"
filename="index.html"
outdata = File.read(filename).gsub(/<a(href=.*)?>.*<\/a>/, "<a href=#{stream_url.inspect}>#{stream_url}</a>")

File.open(filename, 'w') do |out|
  out << outdata
end

if `systemctl is-active icecast2.service` != 'active'
    puts "Start Icecast2 (su required)"
    `sudo service icecast2 start`
end

puts "Stargin Webserver on #{web_url}"
server = WEBrick::HTTPServer.new Port: http_port, BindAddress: host_ip,
                                 DocumentRoot: Dir.pwd, DocumentRootOptions: {FancyIndexing: false}
trap 'INT' do 
    begin 
        server.shutdown
    rescue Exception => e
        puts e
        exit 1
    end
end
Thread.new do
    server.start
end

transcoder = "#transcode{vcodec=none,acodec=mp3,ab=128,channels=2,samplerate=44100}"
shout_sink = "{access=shout,mux=mp3,dst=source:hackme@localhost:8000/#{stream_name}.mp3}\""
cmd = "cvlc alsa://default :live-caching=500 --sout-shout-mp3 :sout=\"#{transcoder}:std#{shout_sink}"
puts "Start Streaming"
puts `#{cmd}`

puts "Shutting down"
server.shutdown