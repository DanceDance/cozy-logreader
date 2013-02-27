connect = require "connect"
app = connect.createServer(connect.static('public')).listen(9099)

io = require("socket.io").listen(app)
io.set 'log level', 2 # disable heartbeat debug output

fs = require "fs"
config = require './config'
spawn = require('child_process').spawn

commands = []

sendData = (socket, data, fileName, fileSlug, channel) ->
    socket.emit 'new-data',
        'fileSlug': fileSlug
        'fileName': fileName
        'channel': channel
        'value': "#{data}"

startProcess = (socket, fileName) ->

    args = ['-f', "#{config.logPath}/#{fileName}"]
    command = spawn "tail", args

    # replace . by - to avoid conflicts in the frontend
    fileSlug = fileName.replace /\./g, '-'

    command.stdout.on 'data', (data) ->
        sendData(socket, data, fileName, fileSlug, 'stdout')
    command.stderr.on 'data', (data) ->
        sendData(socket, data, fileName, fileSlug, 'stderr')

    commands[fileName] = command

io.sockets.on "connection", (socket) ->

    fs.readdir config.logPath, (err, files) ->

        if !err
            for fileName in files
                startProcess(socket, fileName)

        else
            console.log err

    socket.on "disconnect", () ->
        console.log "Client has disconnected, closing the processes..."

        for fileName, command of commands

            console.log "Killing process for #{fileName}..."
            command.kill 'SIGTERM'
