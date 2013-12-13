=begin
  YouTube Playlist Grabber
  Author: Gunbard
  
  Gets data associated to a YouTube playlist and outputs a csv file.
=end

require 'open-uri'
require 'json'
require 'tk'

PLAYLIST_ID_PATTERN = /youtube.com\/.*list=([\w-]+)/
OUTFILE_EXT = '.csv'

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
  
  if end_index > 1
    @bar_progress.percent = progress * 100
  end
  
  # Get playlist API response
  open("http://gdata.youtube.com/feeds/api/playlists/#{playlist_id}?v=2&alt=jsonc&start-index=#{start_index}") do |data|
    json_response = data.read
  end

  if json_response && json_response.length > 0
    response_object = JSON.parse(json_response)
    response_items = response_object['data']['items']
    total_items = response_object['data']['totalItems']
    
    # Initial value since we didn't know the total before
    if end_index == 1
      end_index = total_items
    end
  
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
        grabber_done(playlist_id)
        return
      end
    end
    
    if current_index < end_index && current_index < total_items
      get_playlist_data(playlist_id, current_index + 1, end_index)
    end
  end
end

# Callback method when grabbing finishes
def grabber_done(playlist_id)
  @outfile.close
  @bar_progress.percent = 100
  @button_start.state = 'normal'
  
  filename = "#{playlist_id}#{OUTFILE_EXT}"
  show_msg('Done', "Finished OK. Output to #{filename}")
end

# Shows a standard info box with ok button
def show_msg(title, msg)
  msg_box = Tk.messageBox ({
    :type    => 'ok',  
    :icon    => 'info', 
    :title   => title,
    :message => msg
  })
end

# [Ruby tk widget bindings]
@entry_playlist_url = wpath(top_window, ".top45.ent53")
@button_start = wpath(top_window, ".top45.but54")
@button_help = wpath(top_window, ".top45.but46")
@bar_progress = wpath(top_window, ".top45.pro55")

@entry_playlist_url_text = TkVariable.new
@entry_playlist_url.textvariable = @entry_playlist_url_text

# [Ruby tk widget event handlers]
# Click event for the 'Start' button
button_start_pressed = Proc.new {
  
  # Get playlist id
  url = @entry_playlist_url_text.value
  if url.length == 0
    show_msg('Error', 'You didn\'t enter anything!!')
    return
  end
  
  playlist_id = url[PLAYLIST_ID_PATTERN, 1];
  unless playlist_id
    show_msg('Error', 'Unable to determine playlist id from url')
    return
  end
  
  # Reset progress bar
  @bar_progress.percent = 0
  
  # Disable start button
  @button_start.state = 'disabled'
  
  filename = "#{playlist_id}#{OUTFILE_EXT}"
  @outfile = File.open(filename, 'w')
  Thread.new{get_playlist_data(playlist_id, 1, 1)}
}

# Bind start button event
@button_start.command = button_start_pressed

# Click event for the 'Help' button
button_help_pressed = Proc.new {
  show_msg('Help',"Paste (Ctrl+V) the YouTube playlist url into the box and press start.\n\nA standard .csv file with the playlist's id as the name will be written. The file will contain video titles and direct links suitable for download managers such as JDownloader. Note: Only accepts a full YouTube url and not just a playlist id\n\nWritten by Gunbard (gunbard@gmail.com)")
}

# Bind help button event
@button_help.command = button_help_pressed


# Event handler for window close
root.winfo_children[0].protocol(:WM_DELETE_WINDOW) { 
  if defined?(Ocra)
    exit # Don't want to kill when building
  else
    exit!
  end
}

Tk.mainloop
