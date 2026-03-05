# Business logic and domain models
# This file contains simplified domain models

module Rubix
  module Models
    # Base domain model class
    class Base < Rubix::Database::Model
      include Rubix::Core::Validations
      include Rubix::Core::Callbacks

      define_callbacks :save, :create, :update, :destroy

      # Common attributes for all models
      column :id, :integer, primary_key: true, auto_increment: true
      column :created_at, :datetime, null: false
      column :updated_at, :datetime, null: false

      before_create :set_created_at
      before_save :set_updated_at

      def self.find_by_id(id)
        find(id) rescue nil
      end

      def self.find_or_initialize_by(attributes)
        find_by(attributes) || new(attributes)
      end

      def self.find_or_create_by(attributes)
        find_or_initialize_by(attributes).tap(&:save)
      end

      def to_param
        id.to_s
      end

      protected

      def set_created_at
        self.created_at ||= Time.now
      end

      def set_updated_at
        self.updated_at = Time.now
      end
    end

    # User model
    class User < Base
      self.table_name = :users

      column :email, :string, null: false, unique: true
      column :encrypted_password, :string, null: false
      column :name, :string

      validates_presence_of :email, :encrypted_password
      validates_format_of :email, with: /\A[^@\s]+@[^@\s]+\z/

      attr_accessor :password

      before_save :encrypt_password

      has_many :posts
      has_many :comments

      def valid_password?(password)
        BCrypt::Password.new(encrypted_password).is_password?(password) rescue false
      end

      private

      def encrypt_password
        return unless password.present?
        self.encrypted_password = BCrypt::Password.create(password, cost: 10)
      end
    end

    # Post model
    class Post < Base
      self.table_name = :posts

      column :user_id, :integer, null: false
      column :title, :string
      column :content, :text, null: false

      validates_presence_of :user_id, :content

      belongs_to :user
      has_many :comments
    end

    # Comment model
    class Comment < Base
      self.table_name = :comments

      column :user_id, :integer, null: false
      column :post_id, :integer, null: false
      column :content, :text, null: false

      validates_presence_of :user_id, :post_id, :content

      belongs_to :user
      belongs_to :post
    end
  end
end
