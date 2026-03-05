$LOAD_PATH.unshift(File.expand_path('lib', __dir__))
require 'rubix'
require 'sqlite3'
require 'json'

# 1. Configure
Rubix.configure do |config|
  config.database_adapter = 'sqlite3'
  config.database_database = 'stress_test.db'
  config.server_port = 3001
end

# 2. Define the Product model
class Product < Rubix::Models::Base
  column :name, :string, null: false
  column :price, :integer, null: false

  validates_presence_of :name
  validates_numericality_of :price, greater_than: 0
end

# 3. Define routes
Rubix.get '/' do
  render json: { message: "Rubix Stress Test App Running" }
end

Rubix.get '/products' do
  products = Product.all
  render json: products.map(&:serializable_hash)
end

Rubix.post '/products' do
  product = Product.new(params.slice(:name, :price))
  if product.save
    render json: product.serializable_hash, status: 201
  else
    render json: { errors: product.errors.full_messages }, status: 422
  end
end

# 4. Run the server
Rubix.run!
