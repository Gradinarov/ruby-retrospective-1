class Song
  attr_accessor :name, :artist, :genre, :subgenre, :tags
  def initialize(line)
    arr = []
    line.each_line('.') { |s| arr << s }
    @name = arr[0].delete(".").strip
    @artist = arr[1].delete(".").strip
    @genre = arr[2].partition(",").first.delete(".").strip
    @subgenre = arr[2]=="" ? nil : arr[2].partition(",").last.delete(".").strip
    @tags = tags_helper(arr[2], arr[3])
  end
  
  def tags_helper(song_genre, song_tags)
    arr = Array.new([@genre.to_s.downcase, @subgenre.to_s.downcase])
    if !(song_genre.include?("\n"))
      song_tags.chomp!
      song_tags.each_line(",") { |tag| arr << tag.delete(",").strip }
    end
    arr.flatten!
    arr.delete_if { |tag| tag == "" || tag == nil || tag == ',' }
    return arr
  end
  
  def full_name
    name + " " + artist + " " + genre + " " + subgenre + " " + tags.to_s
  end  

  def add_tags(more_tags)
    @tags << more_tags
    @tags.flatten!    
  end
  
  def check(tags_in_criteria)
    tags_in_criteria.flatten.each do |str|
      if str.include?("!") && self.tags.include?(str.delete("!"))
        return false
      elsif !(self.tags.include?(str)) && !(str.include?("!"))
        return false
      end
    end
    return true    
  end
end

class Collection
  def initialize(songs_as_string, artist_tags = {})
    arr = []
    songs_as_string.each_line { |line| arr << Song.new(line) }
    artist_tags.each do |key, value|
      arr.select{ |song| key == song.artist }.map{ |song| song.add_tags(value) }
    end
    @songs = arr
  end

  def find(criteria)
    arr = Array.new(@songs)
    arr = arr.select{ |song| song.name == criteria[:name] } if criteria[:name]
    arr=arr.select{|song| song.artist == criteria[:artist]} if criteria[:artist]
    arr = arr.select(&criteria[:filter]) if criteria[:filter]    
    arr = arr.select{ |song| song.check(Array(criteria[:tags])) }
    return arr
  end
end