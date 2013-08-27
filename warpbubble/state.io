State := Object clone do (
  load := method (
    stateKey := "wbubble:state"
    rstate := redis get(stateKey)
    if(rstate == nil,
      rstate = "{}"
      redis set(stateKey, rstate))
    rstate parseJson
  )
)
