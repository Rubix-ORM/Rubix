module Rubix
  module Database
    class Connection
      def initialize(config = {})
        @config = config
        require 'sqlite3'
        @db = SQLite3::Database.new(@config[:database] || ':memory:')
      end

      def execute(sql, params = [])
        @db.execute(sql, params)
      end

      def last_insert_rowid
        @db.last_insert_row_id
      end

      def close
        @db.close
      end
    end

    class Column
      attr_reader :name, :type, :options

      def initialize(name, type, options = {})
        @name = name
        @type = type
        @options = options
      end
    end

    class Query
      def initialize(klass)
        @klass = klass
        @conditions = {}
        @limit = nil
        @offset = nil
        @order = nil
      end

      def where(conditions)
        @conditions.merge!(conditions)
        self
      end

      def order(order)
        @order = order
        self
      end

      def limit(limit)
        @limit = limit
        self
      end

      def offset(offset)
        @offset = offset
        self
      end

      def first
        to_a.first
      end

      def count
        sql = "SELECT COUNT(*) FROM #{@klass.table_name}"
        sql << " WHERE #{where_clause}" unless @conditions.empty?
        result = @klass.connection.execute(sql, where_values).first
        result[0]
      end

      def to_a
        sql = "SELECT * FROM #{@klass.table_name}"
        sql << " WHERE #{where_clause}" unless @conditions.empty?
        sql << " ORDER BY #{order_clause}" if @order
        sql << " LIMIT #{@limit}" if @limit
        sql << " OFFSET #{@offset}" if @offset

        results = @klass.connection.execute(sql, where_values)
        results.map do |row|
          attrs = {}
          @klass.columns.each do |name, _|
            attrs[name] = row[name.to_s]
          end
          @klass.new(attrs)
        end
      end

      private

      def where_clause
        @conditions.map { |k, v| "#{k} = ?" }.join(' AND ')
      end

      def where_values
        @conditions.values
      end

      def order_clause
        case @order
        when Hash
          @order.map { |k, v| "#{k} #{v}" }.join(', ')
        when String
          @order
        end
      end
    end

    class Model < Rubix::Core::Base
      include Rubix::Core::Validations
      include Rubix::Core::Callbacks

      define_callbacks :save, :create, :update, :destroy

      class << self
        attr_accessor :table_name, :connection

        def inherited(subclass)
          subclass.table_name = subclass.name.tableize
        end

        def establish_connection(config)
          @connection = Connection.new(config)
        end

        def column(name, type, options = {})
          @columns ||= {}
          @columns[name] = { type: type }.merge(options)
          attr_accessor name
        end

        def belongs_to(association, options = {})
          define_method(association) do
            foreign_key = options[:foreign_key] || "#{association}_id"
            associated_class = options[:class_name] || association.to_s.classify.constantize
            associated_class.find(send(foreign_key))
          end
        end

        def has_many(association, options = {})
          define_method(association) do
            foreign_key = options[:foreign_key] || "#{self.class.name.underscore}_id"
            associated_class = options[:class_name] || association.to_s.singularize.classify.constantize
            associated_class.where(foreign_key => id)
          end
        end

        def validates_uniqueness_of(*attributes)
          attributes.each do |attribute|
            validates attribute, uniqueness: true
          end
        end

        def all
          Query.new(self)
        end

        def where(conditions = {})
          all.where(conditions)
        end

        def find(id)
          where(id: id).first || raise("Record not found")
        end

        def find_by(conditions = {})
          where(conditions).first
        end

        def first
          all.limit(1).first
        end

        def last
          all.order('id DESC').limit(1).first
        end

        def count
          all.count
        end

        def create(attributes = {})
          new(attributes).tap(&:save)
        end

        def columns
          @columns ||= {}
        end
      end

      def initialize(attributes = {})
        super
        @errors = Rubix::Core::Validations::Errors.new(self)
      end

      def save
        return false unless valid?

        if new_record?
          create
        else
          update
        end
      end

      def destroy
        delete
        @destroyed = true
      end

      private

      def create
        attrs = attributes.dup
        attrs.delete(:id)
        columns = attrs.keys
        values = attrs.values
        placeholders = (['?'] * columns.size).join(', ')

        sql = "INSERT INTO #{self.class.table_name} (#{columns.join(', ')}) VALUES (#{placeholders})"
        self.class.connection.execute(sql, values)
        self.id = self.class.connection.last_insert_rowid
        @new_record = false
        true
      end

      def update
        attrs = attributes.dup
        attrs.delete(:id)
        set_clause = attrs.keys.map { |k| "#{k} = ?" }.join(', ')
        values = attrs.values + [id]

        sql = "UPDATE #{self.class.table_name} SET #{set_clause} WHERE id = ?"
        self.class.connection.execute(sql, values)
        true
      end

      def delete
        sql = "DELETE FROM #{self.class.table_name} WHERE id = ?"
        self.class.connection.execute(sql, [id])
        true
      end

      def validate_uniqueness(attribute, value, options)
        return if value.nil?

        query = self.class.where(attribute => value)
        query = query.where.not(id: id) unless new_record?

        @errors.add(attribute, :taken) if query.count > 0
      end
    end
  end
end
