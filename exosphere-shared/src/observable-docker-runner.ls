require! {
  'async'
  'child_process' : {spawn}
  'events' : {EventEmitter}
  'dockerode' : Docker
  'merge-stream'
  'stream'
  'text-stream-search' : TextStreamSearch
}


# Runs a docker image
class ObservableDockerRunner extends EventEmitter

  ({@image-name, @container-name, @stdout, @stderr}) ->
    @docker = new Docker
    @killed = no
    @stdout ?= process.stdout
    @stderr ?= process.stderr
    @stdout-stream = new stream.PassThrough
    @stderr-stream = new stream.PassThrough

    @text-stream-search = new TextStreamSearch merge-stream(@stdout-stream, @stderr-stream)

    if @stdout
      @stdout-stream.on 'data', (data) ~> @stdout.write data.to-string!
    if @stderr
      @stderr-stream.on 'data', (data) ~> @stderr.write data.to-string!


  # The equivalent of 'docker run image'
  # Creates a Docker container and starts it
  run-image: ({create-options}) ->
    @killed = no
    create-options.Image = @image-name
    create-options.Name = @container-name
    create-options.Tty = false # must be false in order to demux stdout and stderr stream
    @docker.create-container create-options, (err, @container) ->
      | err => @emit 'error', err, @killed
      @start-container!


  ensure-container-is-running: ({create-options}) ->
    | @container-is-running! => return
    | @container-exists      => @start-container!
    | otherwise              => @run-image create-options



  container-is-running: ->
    @_containers-exits filters: JSON.stringify {status: 'running'}


  # checks if container exists
  # takes in optional filter parameters for contaienrs that are running, stopped, etc.
  _containers-exits: ({filters=null}) ->
    @docker.list-containers filters, (err, containers) ->
      for container in containers
        async.detect container.names, ((name, cb) ~> cb(null, name is @container-name)), (err, result) ->
          | err => @emit 'error', err, @killed = no
          if result then return true
      false


  start-container: ->
    @killed = no
    @container?.attach {stream: true, stdout: true, stderr: true}, (err, stream) ~>
      | err => @emit 'ended', err, @killed
      @container.modem.demuxStream stream, @stdout-stream, @stderr-stream

    @container?.start (err, data) ~>
      | err => @emit 'ended', err, @killed


  stop-container: ->
    @container?.stop!
    @killed = yes
    @emit 'ended', null, @killed


  wait: (text, handler) ->
    @text-stream-search.wait text, handler


module.exports = ObservableDockerRunner
