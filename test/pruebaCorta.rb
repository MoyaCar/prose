require_relative '../boot'

m = Motor.new 0,0
m.posicionar!

a0 = Arduino.new 0
a0.test_on!

a1 = Arduino.new 1
a1.test_off!

sleep 1

a0.cargar!
sleep 1
a0.extraer!

for i in 1..3
  m = Motor.new 0,i
  m.posicionar!
  sleep 1
  a0.cargar!
  sleep 1
  a0.extraer!
  sleep 1
end


sleep 1
a0.test_off!
a1.test_off!
