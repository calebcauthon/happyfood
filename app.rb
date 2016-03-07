require 'sinatra'
require 'mongoid'

set :environment, :development
Mongoid.load!('mongoid.yml')

class ContactForm
  include Mongoid::Document

  store_in collection: "contact_forms"

  field :name, type: String
  field :email, type: String
  field :phone, type: String
  field :message, type: String
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
end