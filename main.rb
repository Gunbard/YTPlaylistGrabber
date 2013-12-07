require 'open-uri'
require 'json'
require 'yaml'

PLAYLIST_ID_PATTERN = /youtube.com\/playlist\?list=([\w-]+)/
TEST_PLAYLIST_URL = 'https://www.youtube.com/playlist?list=FL6qJQ-sVQLSY6aGo6mBtM0w&feature=mh_lolz'

def get_playlist_data(playlist_id, start_index, end_index)
  json_response = ''
  response_object = nil
  current_index = start_index

  progress = current_index.to_f / end_index
  load_percent = progress * 100
  print "#{load_percent}% (#{start_index}/#{end_index})\r"
  
  open("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}?v=2&alt=jsonc&start-index=#{start_index}") do |data|
    json_response = data.read
  end

  if json_response && json_response.length > 0
    response_object = JSON.parse(json_response)
    response_items = response_object['data']['items']
    total_items = response_object['data']['totalItems']
  
    response_items.each do |item|
      prev_index = current_index
      current_index = item['position']      
            
      missing_videos = current_index - prev_index
      if missing_videos > 1        
        (missing_videos - 1).times do |i|
          @outfile.puts 'Video removed'
        end
      end
      
      title = item['video']['title']
      
      if item['video']['player']
        url = item['video']['player']['default'].gsub(/&feature=youtube_gdata_player/, '')
        @outfile.puts "\"#{title}\",#{url}"
      else
        @outfile.puts 'Video removed'
      end
      
      if current_index == end_index || current_index == total_items 
        return
      end
    end
    
    if current_index < end_index && current_index < total_items
      get_playlist_data(playlist_id, current_index + 1, end_index)
    end
  end
end

@outfile = File.open('out.csv', 'w')

puts 'Starting'
get_playlist_data(TEST_PLAYLIST_URL[PLAYLIST_ID_PATTERN, 1], 1, 100)
puts 'Done                 '

@outfile.close