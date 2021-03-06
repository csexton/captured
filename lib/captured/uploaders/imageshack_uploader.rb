require 'net/http'
require 'uri'
require 'cgi'

# Adapted from http://codesnippets.joyent.com/posts/show/1156
class ImageshackUploader
  attr_reader :url
  USER_AGENT = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en) AppleWebKit/419 (KHTML, like Gecko) Safari/419.3"
  BOUNDARY = '----------PuSHerInDaBUSH_$'

  def initialize(config = {})
    @config = config
    @shack_id = config['upload']['shackid'] || "captured"
  end

  def upload(file_name)
    unless file_name =~ /jpe?g|png|gif|bmp|tif|tiff|swf$/
      raise(NonImageTypeError, 'Expected image file.')
    end
    @img = file_name
    @posted_url, @hosturi, @res = "","",""
    @header, @params = {}, {}
    @header['Cookie'] = "myimages=#{@shack_id}"
    @header['User-Agent'] = USER_AGENT
    @params['uploadtype'] = 'on'  
    @params['brand'] = ''
    @params['refer'] = ''
    @params['MAX_FILE_SIZE'] = '13145728'
    @params['optimage'] = '0'
    @params['rembar'] = '1'
    transfer
    getdirect
    @url = @posted_url.gsub("content.php?page=done&l=", "")
  end

  def prepare_multipart ( params )
    fp = []
    params.each do |k,v|
      if v.respond_to?(:read)
        fp.push(FileParam.new(k,v.path,v.read))
      else fp.push(Param.new(k,v)) 
      end
    end
    query = fp.collect {|p| "--" + BOUNDARY + "\r\n" + p.to_multipart }.join("") + "--" + BOUNDARY + "--"
    return query
  end

  def prepFile(path_to_file)
    file = File.new(path_to_file)
    @header['Content-Type'] = "multipart/form-data, boundary=" + BOUNDARY + " "
    @params['url'] = 'paste image url here'
    @params['fileupload'] = file
    $query = prepare_multipart(@params)
    file.close
  end

  def locate(path)
    path !~ /^http/ ? "local" : "remote"
  end

  def process_upload( query, headers={} )
    Net::HTTP.start(@hosturi.host) do | http |
      http.post(@hosturi.path, query, headers);
    end
  end

  def transload(url)
    @header['Content-Type'] = 'form-data'
    @params['url'] = url
    @params['fileupload'] = ''
    postreq = Net::HTTP::Post.new(@hosturi.path, @header)
    postreq.set_form_data(@params)
    return Net::HTTP.new(@hosturi.host, @hosturi.port).start { |http| http.request(postreq) }
  end

  def transfer
    case locate(@img)
    when "local"
      @hosturi = URI.parse('http://load.imageshack.us/index.php')
      prepFile(@img)
      @res = process_upload($query,@header)
    when "remote"
      @hosturi = URI.parse('http://imageshack.us/transload.php')
      @res = transload(@img)
    end
  end

  def getdirect
    puts @res.header
    puts @res.body
    @posted_url = @res.header['location']
  end

end

class Param
  attr_accessor :k, :v

  def initialize(k,v)
    @k = k
    @v = v
  end

  def to_multipart
    return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"\r\n\r\n#{v}\r\n"
  end
end

class FileParam
  attr_accessor :k, :filename, :content

  def initialize(k, filename, content)
    @k = k
    @filename = filename
    @content = content
    @extension_index = {
      'jpg' => "image/jpeg",
      'jpeg' => "image/jpeg",
      'png' => "image/png",
      'bmp' => "image/bmpimage/x-bmp",
      'tiff' => "image/tiff",
      'tif' => "image/tiff"}
  end

  def type_for(filename)
    ext = filename.chomp.downcase.gsub(/.*\./o, '')
    @extension_index[ext]
  end
  

  def to_multipart
    return "Content-Disposition: form-data; name=\"#{CGI::escape(k)}\"; filename=\"#{filename}\"\r\n" +
      "Content-Type: #{type_for(@filename)}\r\n\r\n" + content + "\r\n"
  end
end



