State := Object clone do (
  rstate := nil
  stateKey := "wbubble:state"

  setup := method(
    new := self clone
    new load
    new
  )

  load := method (
    rstate = redis get(stateKey)
    if(rstate == nil,
      rstate = "{}"
      redis set(stateKey, rstate))
    rstate parseJson
  )
)
