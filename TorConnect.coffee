#jslint node:true

"use strict"
	
util	= require 'util'
net		= require 'net'
cp		= require 'child_process'


class TorConnect

	regex	: /\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b/
	timeout	: 10
	once	: true

	constructor: (proxy, controlPort) ->
		@proxy = proxy or 'localhost:64059'
		@controlPort = controlPort or 9051

	getIp: (callback) ->
		$ = @

		getUrl $, 'http://checkip.dyndns.org/', (err, stdout, stderr) ->
			if err then console.log err

			exec	= $.regex.exec stdout
			ip		= if exec then exec.shift() else ''
			
			callback err, ip
			

	getLocation: (callback) ->
		$ = @

		getUrl $, 'http://freegeoip.net/json/', (err, stdout, stderr) ->
			if err then console.log err

			try 
				json = JSON.parse stdout
			catch e
				console.log e
				json = {}

			callback err, json


	changeIdentity: (password, callback) ->
		$ = @
		timer = null
		authenticated = false

		client = net.connect $.controlPort, (err) ->
			if err then console.log err

			util.log "Connected to localhost: #{$.controlPort}"
			client.write 'AUTHENTICATE "' + password + '"\r\n'


		client.on 'data', (data) ->
			result = data.toString().trim()

			if result is not '250 OK' then return util.log result

			if $.authenticated
				
				$.getLocation (err, location) ->
					if err then return handleError err

					util.log "Hey! You moved to #{location.city}, #{location.country_name}.\nLet me know if you need help carrying the boxes!\n"

					if callback
						callback null, location
			else
				console.log 'Successful authenticated'
				$.authenticated = true

			if $.once
				return client.end 'SIGNAL NEWNYM\r\n'

			timer = setTimeout () ->
				client.write('SIGNAL NEWNYM\r\n');
			, timeout * 1000
			
		client.on 'end', () ->
			if timer
				clearTimeout timer


	# ! Private Methods

	getUrl = ($, url, callback) ->
		cp.exec 'curl --socks5-hostname ' + $.proxy + ' ' + url, (err, stdout, stderr) ->
			callback err, stdout, stderr
		



# Export
root = exports ? window
root.TorConnect = TorConnect