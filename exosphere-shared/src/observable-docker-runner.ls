require! {
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
    console.log "running image"
    console.log @image-name
    console.log @container-name
    @killed = no
    create-options =
      Image: 'ubuntu'
      Tty: true
      Cmd: ['/bin/bash']
    # create-options.Image = @image-name
    # create-options.Name = @container-name
    # create-options.Tty = false # must be false in order to demux stdout and stderr stream
    # console.log create-options
    @docker.create-container {Image: 'ubuntu', Tty: true, Cmd: ['/bin/bash']}, (err, container) ~>
      | err => @emit 'ended', err, @killed
      console.log err
      console.log "container created"
      console.log container
    #   container.start {}, (err, data) -> console.log "started"


  start-container: ->
    console.log "start container called"
    @killed = no
    @container?.attach {stream: true, stdout: true, stderr: true}, (err, stream) ~>
      | err => @emit 'ended', err, @killed
      @container.modem.demuxStream stream, @stdout-stream, @stderr-stream

    @container?.start (err, data) ~>
      | err => @emit 'ended', err, @killed

    # @docker.run @image-name, [], [@stdout-stream, @stderr-stream], {Tty:false}, create-options, (err, data, @container) ~>
    #   | err => @emit 'ended', err, @killed
    #   console.log "container:"
    #   console.log @container
    #   console.log data



  stop-container: ->
    @container?.stop!
    @killed = yes
    @emit 'ended', null, @killed


  wait: (text, handler) ->
    @text-stream-search.wait text, handler


module.exports = ObservableDockerRunner
