require 'sinatra'
require 'mongoid'
require 's3'

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
  field :image_url, type: String
  field :serving_options, type: Array
end

set :public_folder, 'public'

get '/' do
  erb :index
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

get '/admin/add-recipe' do
  erb :'admin/recipe-add', locals: { }, layout: :'admin/layout'
end

post '/admin/add-recipe' do
  ng_params = JSON.parse(request.body.read)
  puts ng_params
  recipe = Recipe.new(
    :name => ng_params["name"],
    :image_url => ng_params["url"],
    :serving_options => ng_params["serving_options"]
  )
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