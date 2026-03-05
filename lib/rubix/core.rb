# Core framework classes and modules
# This file contains the base classes and core functionality

module Rubix
  module Core
    # Base class for all framework objects
    class Base
      include Comparable
      include Enumerable

      attr_reader :attributes

      def initialize(attributes = {})
        @attributes = attributes.symbolize_keys
        @new_record = true
        @destroyed = false
      end

      def id
        @attributes[:id]
      end

      def id=(value)
        @attributes[:id] = value
      end

      def new_record?
        @new_record
      end

      def destroyed?
        @destroyed
      end

      def persisted?
        !new_record? && !destroyed?
      end

      def save
        return false unless valid?

        if new_record?
          create
        else
          update
        end
      end

      def save!
        save || raise(ValidationError, errors.full_messages.join(', '))
      end

      def update(attributes)
        assign_attributes(attributes)
        save
      end

      def update!(attributes)
        update(attributes) || raise(ValidationError, errors.full_messages.join(', '))
      end

      def destroy
        return false if new_record? || destroyed?
        delete
        @destroyed = true
        true
      end

      def reload
        return self if new_record?
        fresh_object = self.class.find(id)
        @attributes = fresh_object.attributes
        @new_record = false
        @destroyed = false
        self
      end

      def assign_attributes(attributes)
        attributes.each do |key, value|
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end

      def attributes=(attributes)
        @attributes = attributes.symbolize_keys
      end

      def [](key)
        @attributes[key.to_sym]
      end

      def []=(key, value)
        @attributes[key.to_sym] = value
      end

      def method_missing(method_name, *args)
        method_name = method_name.to_s
        if method_name.end_with?('=')
          @attributes[method_name.chomp('=').to_sym] = args.first
        elsif method_name.end_with?('?')
          !!@attributes[method_name.chomp('?').to_sym]
        else
          @attributes[method_name.to_sym]
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        method_name = method_name.to_s
        @attributes.key?(method_name.to_sym) ||
        @attributes.key?(method_name.chomp('=').to_sym) ||
        @attributes.key?(method_name.chomp('?').to_sym) ||
        super
      end

      def ==(other)
        other.is_a?(self.class) && id == other.id
      end

      def <=>(other)
        id <=> other.id if other.is_a?(self.class)
      end

      def hash
        [self.class, id].hash
      end

      def eql?(other)
        self == other
      end

      def inspect
        "#<#{self.class.name}:#{object_id} @attributes=#{@attributes.inspect}>"
      end

      def to_s
        inspect
      end

      def to_h
        @attributes.dup
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def dup
        self.class.new(@attributes.dup)
      end

      def clone
        dup
      end

      def freeze
        @attributes.freeze
        super
      end

      def frozen?
        @attributes.frozen? && super
      end

      def marshal_dump
        [@attributes, @new_record, @destroyed]
      end

      def marshal_load(data)
        @attributes, @new_record, @destroyed = data
      end

      def yaml_initialize(tag, val)
        @attributes = val['attributes']
        @new_record = val['new_record']
        @destroyed = val['destroyed']
      end

      def to_yaml_properties
        ['@attributes', '@new_record', '@destroyed']
      end

      protected

      def create
        # Implementation in subclasses
        @new_record = false
        true
      end

      def update
        # Implementation in subclasses
        true
      end

      def delete
        # Implementation in subclasses
        true
      end
    end

    # Inflector for string transformations
    module Inflector
      PLURALS = [
        [/([^aeiouy]|qu)y$/i, '\1ies'],
        [/$/, 's']
      ]

      SINGULARS = [
        [/ies$/i, 'y'],
        [/s$/i, '']
      ]

      IRREGULARS = {
        'person' => 'people',
        'man' => 'men',
        'child' => 'children',
        'sex' => 'sexes',
        'move' => 'moves',
        'cow' => 'cows',
        'zombie' => 'zombies'
      }

      UNCLEANS = [
        /_id$/,
        /_/
      ]

      def self.pluralize(word)
        return IRREGULARS[word] if IRREGULARS.key?(word)
        return word if word.end_with?(*%w[s sh ch x z])

        PLURALS.each do |pattern, replacement|
          return word.gsub(pattern, replacement) if word.match?(pattern)
        end

        word + 's'
      end

      def self.singularize(word)
        return IRREGULARS.invert[word] if IRREGULARS.invert.key?(word)

        SINGULARS.each do |pattern, replacement|
          return word.gsub(pattern, replacement) if word.match?(pattern)
        end

        word
      end

      def self.underscore(string)
        string.gsub(/::/, '/').
               gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
               gsub(/([a-z\d])([A-Z])/,'\1_\2').
               tr("-", "_").
               downcase
      end

      def self.camelize(string, uppercase_first_letter = true)
        string = string.sub(/^[a-z\d]*/, &:capitalize) if uppercase_first_letter
        string.gsub!(/(?:_|(\/))([a-z\d]*)/i) do
          "#{Regexp.last_match(1)}#{Regexp.last_match(2).capitalize}"
        end
        string.gsub!('/', '::')
        string
      end

      def self.classify(string)
        camelize(singularize(string))
      end

      def self.tableize(string)
        pluralize(underscore(string))
      end

      def self.humanize(string)
        result = string.to_s.dup
        UNCLEANS.each { |pattern| result.gsub!(pattern, ' ') }
        result.gsub!(/^\w/) { |match| match.upcase }
        result
      end

      def self.titleize(word)
        humanize(underscore(word)).gsub(/\b(?<![''])(?!\w[''])\w/) { |match| match.capitalize }
      end

      def self.dasherize(string)
        string.tr('_', '-')
      end

      def self.parameterize(string, sep = '-')
        string.downcase.gsub(/[^a-z0-9\-_]+/, sep).gsub(/-{2,}/, sep).gsub(/^#{sep}|#{sep}$/, '')
      end

      def self.constantize(string)
        names = string.split('::')
        names.shift if names.empty? || names.first.empty?

        constant = Object
        names.each do |name|
          constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
        end
        constant
      end

      def self.safe_constantize(string)
        constantize(string)
      rescue NameError
        nil
      end

      def self.demodulize(string)
        string.split('::').last
      end

      def self.deconstantize(string)
        string.split('::')[0..-2].join('::')
      end
    end

    # Callbacks system for lifecycle hooks
    module Callbacks
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def define_callbacks(*names)
          names.each do |name|
            instance_variable_set("@#{name}_callbacks", [])
            define_singleton_method("#{name}_callbacks") do
              instance_variable_get("@#{name}_callbacks")
            end
          end
        end

        def set_callback(callback, kind, *methods)
          callbacks = instance_variable_get("@#{callback}_callbacks") || {}
          callbacks[kind] ||= []
          callbacks[kind].concat(methods)
          instance_variable_set("@#{callback}_callbacks", callbacks)
        end

        [:before, :after].each do |time|
          [:create, :update, :save, :destroy].each do |action|
            define_method("#{time}_#{action}") do |*methods, &block|
              methods.each { |method| set_callback("#{time}_#{action}", :methods, method) }
              set_callback("#{time}_#{action}", :block, block) if block
            end
          end
        end
      end

      def run_callbacks(kind, action)
        callbacks = self.class.send("#{kind}_#{action}_callbacks") || []
        callbacks.each do |cb|
          if cb[:method]
            send(cb[:method])
          elsif cb[:block]
            instance_eval(&cb[:block])
          end
        end
      end
    end

    # Validation system
    module Validations
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          @validations = {}
          attr_accessor :errors
        end
      end

      module ClassMethods
        def validates(*attributes, **options)
          @validations ||= {}
          attributes.each do |attribute|
            @validations[attribute] ||= []
            @validations[attribute] << options
          end
        end

        def validates_presence_of(*attributes)
          attributes.each do |attribute|
            validates attribute, presence: true
          end
        end

        def validates_length_of(*attributes, **options)
          attributes.each do |attribute|
            validates attribute, length: options
          end
        end

        def validates_format_of(*attributes, **options)
          attributes.each do |attribute|
            validates attribute, format: options
          end
        end

        def validates_numericality_of(*attributes, **options)
          attributes.each do |attribute|
            validates attribute, numericality: options
          end
        end
      end

      def valid?
        @errors = Errors.new(self)
        run_validations
        @errors.empty?
      end

      def invalid?
        !valid?
      end

      private

      def run_validations
        self.class.instance_variable_get(:@validations).each do |attribute, validations|
          value = send(attribute)
          validations.each do |validation|
            validation.each do |type, options|
              send("validate_#{type}", attribute, value, options)
            end
          end
        end
      end

      def validate_presence(attribute, value, options)
        @errors.add(attribute, :blank) if value.blank?
      end

      def validate_length(attribute, value, options)
        return if value.nil?

        length = value.length
        if options[:minimum] && length < options[:minimum]
          @errors.add(attribute, :too_short, count: options[:minimum])
        end
        if options[:maximum] && length > options[:maximum]
          @errors.add(attribute, :too_long, count: options[:maximum])
        end
        if options[:is] && length != options[:is]
          @errors.add(attribute, :wrong_length, count: options[:is])
        end
        if options[:in] && !options[:in].include?(length)
          @errors.add(attribute, :inclusion)
        end
      end

      def validate_format(attribute, value, options)
        return if value.nil?

        regex = options[:with]
        @errors.add(attribute, :invalid) unless value.match?(regex)
      end

      def validate_numericality(attribute, value, options)
        return if value.nil?

        begin
          numeric_value = Float(value)
        rescue ArgumentError
          @errors.add(attribute, :not_a_number)
          return
        end

        if options[:greater_than] && numeric_value <= options[:greater_than]
          @errors.add(attribute, :greater_than, count: options[:greater_than])
        end
        if options[:greater_than_or_equal_to] && numeric_value < options[:greater_than_or_equal_to]
          @errors.add(attribute, :greater_than_or_equal_to, count: options[:greater_than_or_equal_to])
        end
        if options[:less_than] && numeric_value >= options[:less_than]
          @errors.add(attribute, :less_than, count: options[:less_than])
        end
        if options[:less_than_or_equal_to] && numeric_value > options[:less_than_or_equal_to]
          @errors.add(attribute, :less_than_or_equal_to, count: options[:less_than_or_equal_to])
        end
        if options[:equal_to] && numeric_value != options[:equal_to]
          @errors.add(attribute, :equal_to, count: options[:equal_to])
        end
        if options[:only_integer] && !value.match?(/^\d+$/)
          @errors.add(attribute, :not_an_integer)
        end
      end

      class Errors
        include Enumerable

        def initialize(base)
          @base = base
          @errors = {}
        end

        def add(attribute, message, options = {})
          @errors[attribute] ||= []
          @errors[attribute] << generate_message(message, options)
        end

        def [](attribute)
          @errors[attribute] || []
        end

        def clear
          @errors.clear
        end

        def empty?
          @errors.empty?
        end

        def size
          @errors.size
        end

        def count
          size
        end

        def full_messages
          @errors.flat_map do |attribute, messages|
            messages.map { |message| "#{attribute.to_s.humanize} #{message}" }
          end
        end

        def each(&block)
          @errors.each(&block)
        end

        def to_h
          @errors.dup
        end

        def to_json(*args)
          to_h.to_json(*args)
        end

        private

        def generate_message(message, options)
          case message
          when :blank
            "can't be blank"
          when :too_short
            "is too short (minimum is #{options[:count]} characters)"
          when :too_long
            "is too long (maximum is #{options[:count]} characters)"
          when :wrong_length
            "is the wrong length (should be #{options[:count]} characters)"
          when :invalid
            "is invalid"
          when :not_a_number
            "is not a number"
          when :greater_than
            "must be greater than #{options[:count]}"
          when :greater_than_or_equal_to
            "must be greater than or equal to #{options[:count]}"
          when :less_than
            "must be less than #{options[:count]}"
          when :less_than_or_equal_to
            "must be less than or equal to #{options[:count]}"
          when :equal_to
            "must be equal to #{options[:count]}"
          when :not_an_integer
            "must be an integer"
          when :inclusion
            "is not included in the list"
          else
            message.to_s
          end
        end
      end
    end
  end
end
