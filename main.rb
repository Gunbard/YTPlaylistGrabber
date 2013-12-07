require 'open-uri'
require 'json'
require 'yaml'

PLAYLIST_ID_PATTERN = /youtube.com\/playlist\?list=([\w-]+)/
TEST_PLAYLIST_URL = 'https://www.youtube.com/playlist?list=FL6qJQ-sVQLSY6aGo6mBtM0w&feature=mh_lolz'

def get_playlist_data(playlist_id, start_index, end_index)
  progress = start_index.to_f / end_index
  load_percent = progress * 100
  print "#{load_percent}%\r"
  
  json_response = ''
  response_object = nil
  last_index = 0
  
  open("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}?v=2&alt=jsonc&start-index=#{start_index}") do |data|
    json_response = data.read
  end

  if json_response && json_response.length > 0
    response_object = JSON.parse(json_response)
    response_items = response_object['data']['items']
  
    response_items.each do |item|
      title = item['video']['title']
      
      if item['video']['player']
        url = item['video']['player']['default'].gsub(/&feature=youtube_gdata_player/, '')
        @outfile.puts title
        @outfile.puts url
      else
        @outfile.puts 'Video removed'
      end
      
      last_index = item['position']
      
      if last_index == end_index || last_index == response_object['data']['totalItems']
        return
      end
    end
    
    if last_index < end_index
      get_playlist_data(playlist_id, last_index, end_index)
    end
  end
end

@outfile = File.open('out.txt', 'w')

puts 'Starting'
get_playlist_data(TEST_PLAYLIST_URL[PLAYLIST_ID_PATTERN, 1], 1, 100)
puts 'Done   '

@outfile.close