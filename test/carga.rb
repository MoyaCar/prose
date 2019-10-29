require_relative '../boot'

pos_totales = 119
pos_ini = 113


puts "variables creadas"

while pos_ini != pos_totales
  ActiveRecord::Base.connection_pool.with_connection do |c|
    puts "adentro del while"

    m = Motor.new 0, pos_ini
    m.posicionar!

    puts "Posicionar inicial:#{pos_ini}"
    puts "Posicion inicial: cargar sobre"

    arduino = Arduino.new 0
    respuesta = arduino.cargar!
    Log.logger.info "Respuesta del arduino: #{respuesta}"

    pos_ini = pos_ini + 1
  end
end
