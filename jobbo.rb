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

before do
	@mixup_ad = RestClient.get 'http://serve.mixup.hapnic.com/9502655'
end

get '/' do
	erb :jobsearch
end

post '/job' do
	session['job'] = params['job']  == 'all' ? '' : params['job']
	erb :locationsearch
end

post '/location' do
	session['location'] = params['location']  == 'all' ? '' : params['location']
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
	  :subject => 'Jobbo feedback',
	  :from => 'emile@silvis.co.za',
	  :to => 'emile@silvis.co.za',
	  :body_text => params['feedback'] + ' - ' + Mxit.new(request.env).user_id
	  )
	erb "Thanks!" 
end

get '/stats' do
	#protected!
	s3 = AWS::S3.new
	bucket = s3.buckets['emilesilvis']
	object = bucket.objects['mxitjobsearch/log.json']
	log = JSON.parse(object.read)

	queries = log.values.each do |record|
		record
	end

	users = queries.collect do |query|
		query["user"]
	end

	erb 'Number of queries: ' + queries.count.to_s + ' <br />Number of users: ' + users.uniq.count.to_s + '<br />Average queries per user: ' + format('%.2f', (queries.count.to_f/users.uniq.count.to_f))

end

error do
  'Sorry there was a nasty error: ' + env['sinatra.error'].message.to_s
end