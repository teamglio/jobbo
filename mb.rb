require 'sinatra'
require 'rest_client'
require 'json'


get '/' do
	erb :send
end

post '/' do
	response = RestClient.post 'https://' + params['clientid'] + ':' + params['clientsecret'] + '@auth.mxit.com/token', :grant_type => 'client_credentials', :scope => 'message/send'

	

	request = {:Body => params['message'].to_s, :ContainsMarkup => true , :From => params['appname'].to_s, :To => params['recipientids'].to_s, :Spool => true}


	RestClient.post 'http://api.mxit.com/message/send/', request.to_json, :authorization => 'Bearer ' + JSON.load(response)['access_token'], :content_type => 'application/json'

	"<a href='/'>Back</a><script>alert('Sent!')</script>"

end

error do
  'Sorry there was a nasty error: ' + env['sinatra.error'].message.to_s
end

#m41162520002


