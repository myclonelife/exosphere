require! {
  'chalk' : {red}
  'child_process'
  'events' : {EventEmitter}
  '../../exosphere-shared' : {DockerHelper, ObservableDockerRunner}
  'fs'
  'js-yaml' : yaml
  'nitroglycerin' : N
  'observable-process' : ObservableProcess
  'path'
  'port-reservation'
  'prelude-ls' : {last}
  'wait' : {wait-until}
}


# Runs a dockerized service
class DockerRunner extends EventEmitter

  ({@name, @docker-config, @logger}) ->


  start-service: ->
    unless DockerHelper.image-exists author: @docker-config.author, name: @docker-config.image
      return @emit 'error', "No Docker image exists for service '#{@name}'. Please run exo-setup."
    DockerHelper.remove-container @name

    switch @name
      | \exocom    => @_run-container!
      | otherwise  =>
        console.log @docker-config
        wait-until (~> DockerHelper.get-docker-ip 'exocom'), 10, ~>
          @docker-config.env.EXOCOM_HOST = DockerHelper.get-docker-ip 'exocom'
          @_start-dependency-containers ~>
            @_run-container!


  write: (text) ~>
    @logger.log {@name, text, trim: yes}


  _generate-container-options: ->
    Env = for name, val of @docker-config.env
      "#{name}=#{val}"
    ExposedPorts = for name, port of @docker-config.publish
      "#{port}/tcp": {}
    Cmd = @docker-config.start-command |> (.split ' ')
    {
      Env
      ExposedPorts
      Cmd
    }


  _generate-dependency-container-options: (dependency-config) ->
    # TODO: compile dependency options from service.yml


  _on-container-error: ~>
    @emit 'error', "Service '#{@name}' crashed, shutting down application"


  _run-container: ~>
    @running-service = new ObservableDockerRunner do
      image-name: "#{@docker-config.author}/#{@docker-config.image}"
      container-name: @docker-config.env.SERVICE_NAME
      stdout: {@write}
      stderr: {@write}
    @running-service
      ..run-image create-options: @_generate-container-options!
      ..on 'ended', (err, killed) ~>
        | err and not killed   =>  @_on-container-error!
      ..wait @docker-config.start-text, ~>
        @logger.log name: 'exo-run', text: "'#{@name}' is running"
        @emit 'online'


  _start-dependency-containers: (done) ~>
    dependency-containers = for dependency-name, dependency-config of @docker-config.dependencies
      dependency-runner = new ObservableDockerRunner do
        image-name: dependency-name
        container-name: "#{@docker-config.app-name}-#{dependency-name}"
      (cb) ~> dependency-runner.ensure-container-is-running @_generate-container-options dependency-config
        ..wait dependency-config.dev['online-text'], cb!

    async.series dependency-containers, (err) ->
      for dependency-name of @docker-config.dependencies
        @docker-config.env[dependency-name.to-upper-case!] = DockerHelper.get-docker-ip "#{@docker-config.app-name}-#{dependency-name}"
      done err



module.exports = DockerRunner
