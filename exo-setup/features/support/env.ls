require! {
  '../../../exosphere-shared' : {kill-child-processes}
}


module.exports = ->

  @set-default-timeout 2000


  @After (scenario, done) ->
    kill-child-processes done

