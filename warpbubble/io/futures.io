
o := Object clone
o work := method(name,
  ("working " .. name) println
  yield
  wait(2)
  ("done " .. name) println
)

o1 := o clone
o2 := o clone

o1 asyncSend(work("one"))
o2 asyncSend(work("two"))
"fired" println

while(Scheduler yieldingCoros size > 1, yield)

