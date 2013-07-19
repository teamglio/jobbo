require 'sinatra'
require 'rest_client'
require 'json'
require 'aws-sdk'
require 'dotenv'
require 'firebase'
require_relative 'lib/jobbo.rb'

enable :sessions

configure do
	Dotenv.load if settings.development?
	Firebase.base_uri = "https://glio-mxit-users.firebaseio.com/#{ENV['MXIT_APP_NAME']}/"	
	AWS.config(
	  :access_key_id => ENV['AWS_KEY'],
	  :secret_access_key => ENV['AWS_SECRET']
	)
end

before do
	@mixup_ad = RestClient.get "http://serve.mixup.hapnic.com/#{ENV['MXIT_APP_NAME']}"
end

get '/' do
	create_user unless get_user	
	erb :jobsearch
end

post '/job' do
	session['job'] = params['job'].downcase  == 'all' ? '' : params['job']
	erb :locationsearch
end

post '/location' do
	session['location'] = params['location'].downcase  == 'all' ? '' : params['location']
	redirect to ('/jobs')
end

get '/jobs' do

	parameters = {
		:publisher => ENV['PUB_ID'],
	 	:v => '2',
		:format => 'json',
		:q => session[:job],
		:l => session[:location],
		:co => 'za',
		:chnl => 'mxitjobsearch',
		:highlight => 0
	}

	response = RestClient.get 'http://api.indeed.com/ads/apisearch', :params => parameters

	@jobs = JSON.load(response)

	erb :jobs
end

get '/feedback' do
	erb :feedback
end

post '/feedback' do
	ses = AWS::SimpleEmailService.new
	ses.send_email(
	  :subject => 'Jobbo feedback',
	  :from => 'mxitappfeedback@glio.co.za',
	  :to => 'mxitappfeedback@glio.co.za',
	  :body_text => params['feedback'] + ' - ' + MxitUser.new(request.env).user_id
	  )
	erb "Thanks! <a href='/'>Back</a>" 
end

error do
  'Sorry there was a nasty error: ' + env['sinatra.error'].message.to_s
end

helpers do
	def get_user
		mxit_user = MxitUser.new(request.env)
		data = Firebase.get(mxit_user.user_id).response.body
		data == "null" ? nil : data
	end
	def create_user
		mxit_user = MxitUser.new(request.env)
		Firebase.set(mxit_user.user_id, {:date_joined => Time.now})
	end
end