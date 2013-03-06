require 'sinatra'
require 'rest_client'
require 'json'
require 'aws-sdk'
require_relative 'mxit'

enable :sessions

configure do
	AWS.config(
	  :access_key_id => ENV['AWS_KEY'],
	  :secret_access_key => ENV['AWS_SECRET']
	)
end

get '/' do
	erb :jobsearch
end

post '/job' do
	session['job'] = params['job']	
	erb :locationsearch
end

post '/location' do
	session['location'] = params['location']
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

	s3 = AWS::S3.new
	bucket = s3.buckets['emilesilvis']
	object = bucket.objects['mxitjobsearch/log.json']
	#log = {Time.now => {:user => Mxit.new(request.env).user_id, :keyword => session[:job] ,:location => session[:location]}}
	log = JSON.parse(object.read)
	log[Time.now] = {:user => Mxit.new(request.env).user_id, :keyword => session[:job] ,:location => session[:location]}
	object.write(log.to_json)

	erb :jobs
end

get '/feedback' do
	erb :feedback
end

post '/feedback' do
	ses = AWS::SimpleEmailService.new
	ses.send_email(
	  :subject => 'WolframMu feedback',
	  :from => 'emile@silvis.co.za',
	  :to => 'emile@silvis.co.za',
	  :body_text => params['feedback'] + ' - ' + Mxit.new(request.env).user_id
	  )
	erb "Thanks!" 
end

error do
  'Sorry there was a nasty error: ' + env['sinatra.error'].message.to_s
end

helpers do
	def get_ad
		Net::HTTP.start("serve.mixup.hapnic.com") do |http|
			response = http.get("http://serve.mixup.hapnic.com/8215822")
			return response.body
		end
	end
end