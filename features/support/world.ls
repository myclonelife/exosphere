require! {
  'dim-console'
  'fs-extra' : fs
  'observable-process' : ObservableProcess
  'path'
  'tmp'
}


World = !->

  @checkout-app = (app-name) ->
    app-dir = path.join process.cwd!, 'tmp', app-name
    fs.empty-dir-sync app-dir
    fs.copy-sync path.join(process.cwd!, 'example-apps', app-name), app-dir


  @setup-app = (app-name, done) ->
    @process = new ObservableProcess(path.join(process.cwd!, 'bin', 'exo setup'),
                                     cwd: path.join(process.cwd!, 'tmp', app-name),
                                     console: dim-console.console)
      ..on 'ended', done


  @start-app = (app-name, done) ->
    @process = new ObservableProcess(path.join('..', 'bin', 'exo run'),
                                     cwd: path.join(process.cwd!, 'tmp'),
                                     console: dim-console.console)
      ..wait "application ready", done



module.exports = ->
  @World = World
