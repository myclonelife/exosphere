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
          @_check-dependency-containers!
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


  _check-dependency-containers: ~>
    for dependency of @docker-config.dependencies
      app-dependency = "#{@docker-config.app-name}-#{dependency}"
      DockerHelper.ensure-container-is-running app-dependency, dependency
      @docker-config.env[dependency.to-upper-case!] = DockerHelper.get-docker-ip app-dependency


module.exports = DockerRunner
