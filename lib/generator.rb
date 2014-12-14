require 'erb'

class Overrides
  def self.overrides
    @overrides ||= JSON.parse(File.read("./data/overrides.json"))
  end

  def self.for(type, value)
    overrides["#{type}/#{value}"]
  end
end

class Generator
  class Property
    attr_reader :name

    def initialize(name, instance)
      @name = name
      @instance = instance
    end

    def params_hash
      @instance
    end

    def go_type
      return type_for(@instance)
    end

    def type_for(thing)
      return "string" if thing.nil?
      puts "thing is #{thing}, a #{thing.class}"
      t = Time.parse(thing) rescue nil
      if t
        return "time.Time"
      elsif thing.is_a?(Array) && thing == []
        return "[]interface{}"
      elsif thing.is_a?(Array)
        return "[]#{type_for(thing.first)}"
      elsif thing.is_a?(Integer)
        return "int64"
      elsif thing.is_a?(Float)
        return "float64"
      elsif thing.is_a?(TrueClass) || thing.is_a?(FalseClass)
        return "bool"
      elsif thing.is_a?(Hash)
        # is this an embedded, other first-order property?
        if klass = Generator.klasses[thing.keys.sort.join("")]
          return klass.name
        else
          # generate a new embedded type
          type = name.singularize.camelize

          unless Generator.klasses.values.any? { |k| k.name == type }
            Generator.new({"name" => type, "actions" => []}, thing)
          end

          return type
        end
      else
        return "string"
      end
    end

    def imports
      if go_type == "time.Time"
        ["time"]
      else
        []
      end
    end
  end

  class Action
    def initialize(klass, action)
      @klass = klass
      @name = action
    end

    def endpoint
      "/admin/#{@klass.name.underscore.pluralize}"
    end

    def render
      if File.exist? "./templates/#{@name}.go.erb"
       template = File.read("./templates/#{@name}.go.erb")
        
        ERB.new(template).result(binding)
      else
        puts "// TODO implement #{@klass.name}.#{@name}"
      end
    end

    def imports
      imports = ["encoding/json", "fmt"]
      if @name == "update"
        imports << "bytes"
      end
      imports
    end
  end

  attr_reader :name

  def initialize(api, instance)
    @api = api # name, endpoint, actions array
    @instance = instance
    @name = api["name"].gsub(' ', '')

    Generator.klasses[@instance.keys.sort.join("")] = self
  end

  def parse
    return if @parsed

    @properties = @instance.keys.map do |p| 
      Property.new(p, @instance[p])
    end

    @actions = @api["actions"].map { |a| Action.new(self, a) }
    @parsed = true
  end

  def render(result, template)
    return if @rendered
    File.write(result, ERB.new(template).result(binding))
    @rendered = true
  end

  def imports
    (@properties + @actions).map(&:imports).flatten.compact.sort.uniq
  end

  @@package = ""
  @@klasses = {}

  def self.klasses
    @@klasses
  end

  def self.package=(pkg)
    @@package = pkg
  end

  def package
    @@package
  end
end
