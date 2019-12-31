#
# Author::      Madhusudhan Reddy Marri.
# Copyright::   Copyright (c) 20019
# License::     MIT
# URL::         https://github.com/ps7exp/read_config_data

class ReadConfigData

  Version = '0.0.1'

  attr_accessor :config_file, :params, :groups, :workers, :pairs
  
  def initialize(config_file=nil, separator='=', comments=['#', ';'])
    @config_file = config_file
    @params = {}
    @groups = []
    @workers = []
    @pairs = []
    @splitRegex = '\s*' + separator + '\s*'
    @comments = comments

    if(self.config_file)
      self.validate_config()
      self.import_config()
    end
  end

  # Validate the config file, and contents
  def validate_config()
    unless File.readable?(self.config_file)
      raise Errno::EACCES, "#{self.config_file} is not readable"
    end

    # FIX ME: need to validate contents/structure?
  end

  # Import data from the config to our config object.
  def import_config()
    # The config is top down.. anything after a [group] gets added as part
    # of that group until a new [group] is found.
    group = nil
    worker = ''
    workers = []
    pairs = []
    tag_name = nil
    tag_id = nil
    worker_h = {}
    open(self.config_file) { |f| f.each_with_index do |line, i|
      line.strip!

      # force_encoding not available in all versions of ruby
      begin
        if i.eql? 0 and line.include?("\xef\xbb\xbf".force_encoding("UTF-8"))
          line.delete!("\xef\xbb\xbf".force_encoding("UTF-8"))
        end
      rescue NoMethodError
      end

      is_comment = false
      @comments.each do |comment|
        if (/^#{comment}/.match(line))
          is_comment = true
          break
        end
      end

      tag, name = line.split 
      if(tag == "<worker")
        tag_id = name.gsub('>', '')
        tag_name = tag
      end 
          
      if(tag == "</worker>")
        tag_name = tag
      end 

      if(tag_name == "<worker")
        worker = worker + ' ' + line
      end

      if(tag_name == "</worker>")
        work_tags = worker + tag_name
        worker_h[tag_id] = work_tags.lstrip 
        if( work_tags != "</worker>") 
          pairs.push(worker_h)
          workers.push(work_tags.lstrip)
        end    
        worker = ''
        worker_h = {}
      end

      if(workers)
        self.add_to_workers(workers)
      end

      if(pairs)
        self.add_to_pairs(pairs)
      end

  
      unless is_comment
        if(/#{@splitRegex}/.match(line))
          param, value = line.split(/#{@splitRegex}/, 2)      

          var_name = "#{param}".chomp.strip
          value = value.chomp.strip
          new_value = ''
          if (value)
            if value =~ /^['"](.*)['"]$/
              new_value = $1
            else
              new_value = value
            end
          else
            new_value = ''
          end

          if group
            self.add_to_group(group, var_name, new_value)
          else
            self.add(var_name, new_value)
          end

        elsif(/^\[(.+)\]$/.match(line).to_a != [])
          group = /^\[(.+)\]$/.match(line).to_a[1]
          self.add(group, {})

        end
      end
    end }
  end

  # This method will provide the value held by the object "@param"
  # where "@param" is actually the name of the param in the config
  # file.
  #
  # DEPRECATED - will be removed in future versions
  #
  def get_value(param)
    puts "ParseConfig Deprecation Warning: get_value() is deprecated. Use " + \
         "config['param'] or config['group']['param'] instead."
    return self.params[param]
  end

  # This method is a shortcut to accessing the @params variable
  def [](param)
    return self.params[param]
  end

  # This method returns all parameters/groups defined in a config file.
  def get_params()
    return self.params.keys
  end

  # List available sub-groups of the config.
  def get_groups()
    return self.groups
  end

  def get_workers()
    self.workers
  end

  def get_pairs()
    self.pairs
  end

  def get_pair(worker_id)
    self.pairs.select {|s| s[worker_id]}
  end


  # This method adds an element to the config object (not the config file)
  # By adding a Hash, you create a new group
  def add(param_name, value, override = false)
    if value.class == Hash
      if self.params.has_key?(param_name)
        if self.params[param_name].class == Hash
          if override
            self.params[param_name] = value
          else
            self.params[param_name].merge!(value)
          end
        elsif self.params.has_key?(param_name)
          if self.params[param_name].class != value.class
            raise ArgumentError, "#{param_name} already exists, and is of different type!"
          end
        end
      else
        self.params[param_name] = value
      end
      if ! self.groups.include?(param_name)
        self.groups.push(param_name)
      end
    else
      self.params[param_name] = value
    end
  end

  # Add parameters to a group. Note that parameters with the same name
  # could be placed in different groups
  def add_to_group(group, param_name, value)
    if ! self.groups.include?(group)
      self.add(group, {})
    end
    self.params[group][param_name] = value
  end

  def add_to_workers(w)
    self.workers = w
  end

  def add_to_pairs(w)
    self.pairs = w
  end

  # Writes out the config file to output_stream
  def write(output_stream=STDOUT, quoted=true)
    self.params.each do |name,value|
      if value.class.to_s != 'Hash'
        if quoted == true
          output_stream.puts "#{name} = \"#{value}\""
        else
          output_stream.puts "#{name} = #{value}"
        end
      end
    end
    output_stream.puts "\n"

    self.groups.each do |group|
      output_stream.puts "[#{group}]"
      self.params[group].each do |param, value|
        if quoted == true
          output_stream.puts "#{param} = \"#{value}\""
        else
          output_stream.puts "#{param} = #{value}"
        end
      end
      output_stream.puts "\n"
    end
  end

  def eql?(other)
    self.params == other.params && self.groups == other.groups
  end
  alias == eql?

end
