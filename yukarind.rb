require 'twitter'
require 'json'
require 'yaml'
require 'time'
require 'faraday'
require 'indico'

require_relative 'route.rb'


def routin text, char=""
  t = Time.now.to_s
  t.slice! ' +0900'

  # url parser
  text.gsub!(/(https?|ftp)(:\/\/[-_.!~*\'();a-zA-Z0-9;\/?:\@&=+\$,%#]+)/, '(url)')
  # 改行その他変換
  text.gsub!(/　|\ |\n/, '、')
  # エスケープ
  text.delete!(",\\.\"\'|\<\>\\;:/*`()#}{@$-%!\=\+\[\]")
  
  text = kidding text

  return if text.empty? || text.length>140

  asj = analyze text # return {a: ,s: ,j: }

  File.open('log','a') do |f|
    f.puts "[#{t}]: #{text}\n"
  end
  File.open('deep_log','a') do |f|
    f.puts "[#{t}]: #{text}\n"
  end

  vol = '2.0'
  if char == 'ai'
    `yukarin -s 1.0 -c ai -q #{text}`
  else 
    char = "-c #{char}" unless char.empty?
    p char
    p `yukarin2 -v #{vol} #{char} -q -a #{asj[:a]} -s #{asj[:s]} -j #{asj[:j]} #{text}`
  end
end

def kidding text
  # result = docomo text
  result = text

  if text.match(/八雲|やくも|yakumo|ヤクモ|ﾔｸﾓ|淫夢|野獣|ゾ〜|クルルァ/)
    result = "汚いこと言わせようとしないでください"
  elsif text.match (/^世の中には/)
    result = "世の中には魔女や魔法少女という存在がいる。"
  end

  return result
end


def analyze text
  url = "https://translate.google.com"
  conn = Faraday.new url do |faraday|
    faraday.request :url_encoded
    faraday.adapter :net_http
  end
  res = conn.get do |req|
    req.params[:h1] = "ja"
    req.params[:langpair] = "ja%7Cen"
    req.params[:text] = text
  end
  res = res.body.match(/TRANSLATED_TEXT='(.*)';var ctr,/)[1]

  res = Indico.emotion res
  p res

  return {a: format('%.2f',res['anger']), s: format('%.2f',res['sadness']), j: format('%.2f',res['joy'])}
end

def docomo(text) 
  apikey = "634b4d4856307a37433749704f754735424e6b6d5348725566506b765958667a697757596254492e506e41"

  url = "https://api.apigw.smt.docomo.ne.jp/dialogue/v1/dialogue"

  conn = Faraday.new url
  res = conn.post do |req|
    req.url '?APIKEY='+apikey
    req.headers['Content-Type'] = 'application/json'
    req.body = {
      "utt": text,
    }.to_json
  end
  JSON.parse(res.body)['utt']

end

Thread.abort_on_exception = true
tw = Thread.new do 
  auth = YAML.load_file 'auth.yml'  
  cl = Twitter::Streaming::Client.new do |config|
    config.consumer_key = auth["ck"]
    config.consumer_secret = auth["cs"]
    config.access_token = auth["at"]
    config.access_token_secret = auth["as"]
  end
  print "thread established"
  cl.filter(track: "#rccyukari") do |status|
    next unless status.is_a? Twitter::Tweet
    text = status.text.dup
    next if text.start_with? "RT"
    text.gsub!("#rccyukari", "")
    puts "tw: #{text}"
    routin text
  end
  print "something happen"
end

Indico.api_key = YAML.load_file('auth.yml')["indico"]

File.open 'pid', 'w' do |f|
  f.write Process.pid
end

Route.start

