require 'sinatra'
require 'mongoid'
require 's3'
require 'stripe'

set :environment, :development
Mongoid.load!('mongoid.yml')

class ContactForm
  include Mongoid::Document
  include Mongoid::Timestamps

  store_in collection: "contact_forms"

  field :name, type: String
  field :email, type: String
  field :phone, type: String
  field :message, type: String
end

class Recipe
  include Mongoid::Document
  include Mongoid::Timestamps

  store_in collection: "recipe_catalogue"

  field :name, type: String
  field :meal, type: String
  field :image_url, type: String
  field :serving_options, type: Array
  field :deleted, type: Boolean
end

set :public_folder, 'public'

get '/' do
  erb :index, locals: { publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'] }
end

post '/contact' do
  ng_params = JSON.parse(request.body.read)
  submission = ContactForm.new(:email => ng_params["email"],
      :name => ng_params['name'],
      :phone => ng_params['phone'],
      :message => ng_params['message'])
  submission.save

  "OK"
end

get '/admin/contact' do
  erb :'admin/contact', locals: { contact_form_submissions: ContactForm.all }, layout: :'admin/layout'
end

post '/admin/contact.json' do
  ContactForm.all.to_json
end

get '/admin-recipes' do
  send_file 'views/admin/layout.html'
end

post '/admin/recipes.json' do
  Recipe.where(:deleted.exists => false).all.to_json
end

post '/admin/recipe.json' do
  ng_params = JSON.parse(request.body.read)
  Recipe.find(ng_params['recipe_id']).to_json
end

get '/admin/add-recipe' do
  erb :'admin/recipe-add', locals: { recipe_id: nil }, layout: :'admin/layout'
end

get '/admin/edit-recipe/:recipe_id' do
  erb :'admin/recipe-add', locals: { recipe_id: params[:recipe_id] }, layout: :'admin/layout'
end

post '/admin/remove-recipe' do

  ng_params = JSON.parse(request.body.read)
  recipe = Recipe.find(ng_params['recipe_id'])
  recipe.deleted = true
  recipe.save

  recipe.to_json
end

post '/admin/add-recipe' do
  ng_params = JSON.parse(request.body.read)
  recipe = Recipe.new(
    :name => ng_params["name"],
    :meal => ng_params["meal"],
    :image_url => ng_params["url"],
    :serving_options => ng_params["serving_options"]
  )
  recipe.save
end

post '/admin/update-recipe' do
  ng_params = JSON.parse(request.body.read)
  recipe = Recipe.find(ng_params['recipe_id'])
  recipe.name = ng_params["name"]
  recipe.meal = ng_params["meal"]
  recipe.image_url = ng_params["url"]
  recipe.serving_options = ng_params["serving_options"]

  recipe.save
end

post '/admin/add-recipe-image' do
  service = S3::Service.new(:access_key_id => ENV['AWS_ACCESS_KEY_ID'], :secret_access_key => ENV['AWS_SECRET_ACCESS_KEY_ID'])
  bucket = service.buckets.find('elasticbeanstalk-us-west-2-480259414258')
  new_object = bucket.objects.build("recipe-images/#{params['image'][:filename]}")
  new_object.acl = :public_read
  new_object.content = params['image'][:tempfile].read
  new_object.save

  { url: new_object.url }.to_json
end

def get_verified_cost(cart)
  total_cost = 0
  cart.each do |item|
    recipe = Recipe.find(item["recipe"]["_id"]["$oid"])
    serving_option = recipe.serving_options.first do |option|
      item["serving_option"]["servings"] == option.servings
    end

    total_cost = total_cost + serving_option["dollars"].to_i
  end

  total_cost
end

def stripe_charge(cost, token, cart)
  Stripe.api_key = ENV['STRIPE_SECRET_KEY']
  stripe_params = {
    :amount => cost * 100,
    :currency => "usd",
    :source => token,
    :description => "Happyfood Web Charge",
    :metadata => {
      cart: cart.map do |item|
        "#{item["recipe"]["name"]} (#{item["serving_option"]["servings"]} servings)"
      end.join(" | ")
    }
  }

  begin
    return Stripe::Charge.create(stripe_params)
  rescue Stripe::CardError => e
    return e
  rescue Exception => e
    return e
  end
end

post '/charge' do
  ng_params = JSON.parse(request.body.read)

  verified_cost = get_verified_cost(ng_params["cart"])

  if(verified_cost != ng_params["browser_total_cost"].to_i)
    status 401
    return {
      expected: verified_cost,
      got: ng_params["browser_total_cost"].to_i
    }.to_json
  end

  result = stripe_charge(verified_cost, ng_params["stripeToken"], ng_params["cart"])

  if(result)
    status 200
    return result.to_json
  else
    status 402
  end
end