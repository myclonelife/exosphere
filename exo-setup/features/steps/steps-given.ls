require! {
  'path'
}


module.exports = ->

  @Given /^a freshly checked out "([^"]*)" application$/, (@app-name) ->
    @checkout-app @app-name
    @current-dir = path.join process.cwd!, 'tmp', @app-name
