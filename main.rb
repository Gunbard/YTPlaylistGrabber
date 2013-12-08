=begin
  YouTube Playlist Grabber
  Author: Gunbard
  
  Gets data associated to a YouTube playlist and outputs a csv file.
=end

require 'open-uri'
require 'json'
require 'tk'

PLAYLIST_ID_PATTERN = /youtube.com\/playlist\?list=([\w-]+)/
OUTFILE_NAME = 'out.csv'

# [Tk/Tcl stuff]
temp_dir = File.dirname($0)
Tk.tk_call('source', "#{temp_dir}/main.tcl")

root = TkRoot.new

top_window = root.winfo_children[0]
top_window.resizable = false, false

# Gets the widget in a window [window] given a path [str]
def wpath(window, str)
  window.winfo_children.each do |some_widget|
    if some_widget.path == str
      return some_widget
    end
  end
end

def get_playlist_data(playlist_id, start_index, end_index)
  json_response = ''
  response_object = nil
  current_index = start_index

  # Loading meter
  progress = current_index.to_f / end_index
  @bar_progress.percent = progress * 100

  #print "#{load_percent}% (#{start_index}/#{end_index})\r"
  
  # Get playlist API response
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
            
      # Detect videos that the API "skipped"
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
        grabber_done()
        return
      end
    end
    
    if current_index < end_index && current_index < total_items
      get_playlist_data(playlist_id, current_index + 1, end_index)
    end
  end
end

# Callback method when grabbing finishes
def grabber_done()
  @outfile.close
  @bar_progress.percent = 100
  @button_start.state = 'normal'
  show_msg("Done. Wrote to #{OUTFILE_NAME}")
end

# Shows a standard info box with ok button
def show_msg(msg)
  msg_box = Tk.messageBox ({
    :type    => 'ok',  
    :icon    => 'info', 
    :title   => 'Alert',
    :message => msg
  })
end

# [Ruby tk widget bindings]
@entry_playlist_url = wpath(top_window, ".top45.ent53")
@button_start = wpath(top_window, ".top45.but54")
@bar_progress = wpath(top_window, ".top45.pro55")

@entry_playlist_url_text = TkVariable.new
@entry_playlist_url.textvariable = @entry_playlist_url_text

# [Ruby tk widget event handlers]
# Click event for the 'Start' button
button_start_pressed = Proc.new {
  
  # Get playlist id
  url = @entry_playlist_url_text.value
  if url.length == 0
    show_msg('You didn\'t enter anything!!')
    return
  end
  
  playlist_id = url[PLAYLIST_ID_PATTERN, 1];
  unless playlist_id
    show_msg('Unable to determine playlist id from url')
    return
  end
  
  # Reset progress bar
  @bar_progress.percent = 0
  
  # Disable start button
  @button_start.state = 'disabled'
  
  @outfile = File.open(OUTFILE_NAME, 'w')
  Thread.new{get_playlist_data(playlist_id, 1, 100)}
}

# Bind start button event
@button_start.command = button_start_pressed

# Event handler for window close
root.winfo_children[0].protocol(:WM_DELETE_WINDOW) { 
  if defined?(Ocra)
    exit # Don't want to kill when building
  else
    exit!
  end
}

Tk.mainloop
