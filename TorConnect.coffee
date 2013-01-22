#jslint node:true

"use strict"
 
fs 			= require 'fs'
net 		= require 'net'
q 			= require 'q'
util 		= require 'util'
color 		= require 'colors'
cp			= require 'child_process'

class TorConnect

	regex	: /\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b/

	constructor: (@socksPort, @socksHost, @controlPort, @controlHost) ->
		@proxy = @socksHost + ':' + @socksPort
 
	##
	##	Request tor get new identity, i.e. reset circuit
	##	@param {String} [auth]
	##	@param {Function} callback
	##		Callback taking result (err)
	##
	changeIdentity : (auth, callback) ->
		if typeof auth is 'function'
			callback = auth
			auth = null
	 
		sock = new net.Socket { allowHalfOpen: false }
		@.connect(sock, @controlPort, @controlHost)
			.then =>
				console.log 'authenticating'.blue
				@.write sock, 'AUTHENTICATE "' + auth + '"'
			.then =>
				console.log 'sending new identity request'.blue
				@.write sock, 'SIGNAL NEWNYM'
			.then =>
				sock.destroy()
				console.log 'tor was successful'.green
				@.getLocation (err, location) ->
					console.log 'location callback'.blue
					if err and callback
						return callback err, location
					util.log "Hey! You moved to #{location.city}, #{location.country_name}.\nLet me know if you need help carrying the boxes!\n"
				
					callback null, location
			.fail (err) ->
				sock.destroy()
 

	write : (sock, cmd) ->
		deferred = q.defer()
		if not sock.writable
			process.nextTick ->
				deferred.reject new Error('Socket is not writable')
			return deferred.promise
	 
		sock.removeAllListeners 'error'
		sock.removeAllListeners 'data'
	 
		sock.once 'data', (data) ->
			res = data.toString().replace /[\r\n]/g, ''
			tokens = res.split ' '
			code = parseInt tokens[0]
	 
			if code isnt 250
				console.log 'no 250'.red
				deferred.reject new Error(res)
			else
				deferred.resolve();
	 
		sock.once 'err', deferred.reject
		sock.write cmd + '\r\n'
		deferred.promise
 
 
	##	
	##	Connect to Tor control service in promise-style
	##	
	##	@param {net.Socket} sock
	##	   Socket object
	##	@param {String|Number} port
	##	   Tor control port
	##	@param host
	##	   Tor control host
	##	@return {promise}
	##	   Promise object
	##	
	connect : (sock, port, host) ->
		deferred = q.defer()
		sock.once 'connect', deferred.resolve
		sock.once 'error', deferred.reject
		sock.connect port, host
		deferred.promise

	getIp: (callback) ->

		getUrl @, 'http://checkip.dyndns.org/', (err, stdout, stderr) =>
			if err then console.log err

			exec	= @.regex.exec stdout
			ip		= if exec then exec.shift() else ''
			
			callback err, ip
			

	getLocation: (callback) ->
		console.log 'getting location'.blue
		@.getUrl 'http://freegeoip.net/json/', (err, stdout, stderr) ->
			if err then console.log err
			console.log 'geo ip callback'.blue
			try 
				json = JSON.parse stdout
			catch e
				console.log e
				json = {}

			callback err, json

	getUrl: (url, callback) ->
		cp.exec 'curl --socks5-hostname ' + @.proxy + ' ' + url, (err, stdout, stderr) ->
			callback err, stdout, stderr


module.exports = TorConnect