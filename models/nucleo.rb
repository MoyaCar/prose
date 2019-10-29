require_relative "log"
require 'pry'

class Nucleo
  class CriticalError < RuntimeError
    def codigo
      "0x00. Error crítico 0"
    end
  end

  class CommFailure < RuntimeError
    def codigo
      "0x01. Falla de comunicación"
    end
  end

  class ZeroNotFound < RuntimeError
    def initialize(resp)
      @resp = resp
    end

    def codigo
      "1x01. Cero no encontrado. Resp: #{@resp}"
    end
  end

  class LoadError < RuntimeError
    def initialize(resp)
      @resp = resp
    end

    def codigo
      "2x01. Falla en la carga. Resp: #{@resp}"
    end
  end

  class LoadPresenterLoaded < RuntimeError
    def initialize(resp)
      @resp = resp
    end

    def codigo
      "2x02. Presentador cargado. Resp: #{@resp}"
    end
  end

  class LoadError2 < RuntimeError
    def initialize(resp)
      @resp = resp
    end

    def codigo
      "2x03. Falla en la carga. Resp: #{@resp}"
    end
  end

  class ExtractionError < RuntimeError
    def initialize(resp)
      @resp = resp
    end

    def codigo
      "3x01. Falla en la extracción. Resp: #{@resp}"
    end
  end

  class ExtractionPresenterLoaded < RuntimeError
    def initialize(resp)
      @resp = resp
    end

    def codigo
      "3x02. Presentador cargado. Resp: #{@resp}"
    end
  end

  class ExtractionError2 < RuntimeError
    def initialize(resp)
      @resp = resp
    end

    def codigo
      "3x03. Falla en la extracción. Resp: #{@resp}"
    end
  end

  INICIADOR = ":"
  TERMINADOR = ";"
  POSICIONES = 800
  DIRECCION = "/dev/ttyACM0"

  COMANDOS = {
    estado: "0",
    cero: "1",
    posicionar: "4",
    carga: "C",
    extraccion: "E",
    manual: "3",
  }

  ESTADOS = {
    "1" => :estado_inicial,
    "2" => :emergencia,
    "3" => :emergencia_superable,
    "4" => :homming,
    "5" => :en_espera,
    "6" => :modo_manual,
    "7" => :en_proceso_extraccion,
    "8" => :en_proceso_carga,
  }

  SUB_ESTADOS = {
    :carga => {
      "1" => :carga_correcta,
      "4" => :sobre_no_introducido,
      "5" => :posicion_ocupada,
      "6" => :dispenser_lleno,
      "7" => :sobre_fuera_de_medida
    },
    :extraccion => {
      "1" => :extraccion_correcta,
      "2" => :no_hay_sobre_en_rodete,
      "3" => :sobre_no_retirado,
    },
  }

  SENSORES = [
    :s_PuA,
    :s_CoC,
    :s_CoA,
    :s_SRA,
    :s_SCE,
    :s_SRO,
    :s_0E,
    :s_0Z,
    :s_0H,
    :p_RA,
    :p_RO,
    :p_B1,
  ]

  def self.get_uart
    retries = 0

    begin
      UART.open(DIRECCION, 115200) do |uart|
        yield uart
      end
    rescue Exception => e
      Log.error "No se pudo abrir comunicación UART #{e}"

      if retries < 2
        retries += 1
        sleep 0.5
        retry
      end
      
      #raise CommFailure

      # Mock de UART por si no estamos corriendo la aplicación en la Raspberry
      unless Struct::const_defined? "Mock"
        Struct.new("Mock") do
          attr_reader :data

          @@count = 0

          def write(data)
            @data = data
          end

          def read(bytes=nil)
            @@count += 1
            if @@count == 2
              @@count = 0
              return ":54154CD501;"
            end

            return ":51154CD501;"
          end
        end
      end

      yield Struct::Mock.new
    end
  end

  def self.write_uart(data)
    resp = nil
    data_get_estado = (data == [INICIADOR, COMANDOS[:estado], TERMINADOR].join)
    3.times do
      do_break = !data_get_estado
      get_uart do |uart|
       
        uart.write(data)
        break if do_break
        sleep 0.5
        resp = uart.read
        do_break = (resp && resp[0] == INICIADOR && resp[11] == TERMINADOR)
        break if do_break
        Log.error "Reintentando comunicar (reenviando mensaje) #{resp}"
        sleep 0.5
      end

      break if do_break
    end

    raise CriticalError if data_get_estado && (!resp || resp[0] != INICIADOR || resp[11] != TERMINADOR) 

    resp
  end

  def self.get_estado
    data = [INICIADOR, COMANDOS[:estado], TERMINADOR].join
    resp = nil

    resp = write_uart(data)

    estado = resp[1]
    sub_estado = resp[2]
    flags = resp[3..6].hex.to_s(2).rjust(16, "0").split("").reverse
    sensores = resp[7..10].hex.to_s(2).rjust(16, "0").split("").reverse

    if estado == ESTADOS.invert[:estado_inicial]
      Log.info "Inicializando presentador resp #{resp}"
      estado, sub_estado, sensores, flags, resp = cero!.values_at(:estado, :sub_estado, :sensores, :flags, :resp)
    end

    {
      estado: estado,
      sub_estado: sub_estado,
      sensores: sensores,
      flags: flags,
      resp: resp,
    }
  end

  def self.posicion_libre
    ((0...POSICIONES).to_a - Sobre.pluck(:posicion)).first
  end

  def self.cargar!(posicion)
    Log.info "Inicio de proceso de carga de sobre en posicion #{posicion}"

    estados_invert = ESTADOS.invert
    estado, sub_estado, flags, resp = nil

    4.times do
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)

      raise LoadError.new(resp) if estado == estados_invert[:emergencia]

      return {
        estado: ESTADOS[estado],
        sub_estado: SUB_ESTADOS[:carga][sub_estado],
        flags: flags,
        resp: resp,
      } if flags[10] == "1"

      if estado == estados_invert[:homming]
        sleep 7
      elsif estado == estados_invert[:emergencia_superable]
        sleep 2
      else
        break
      end
    end

    raise LoadError.new(resp) if estado == estados_invert[:emergencia_superable]

    return {
             estado: ESTADOS[estado],
             sub_estado: SUB_ESTADOS[:carga][sub_estado],
             flags: flags,
             resp: resp,
           } if estado != estados_invert[:en_espera]

    data = [INICIADOR, COMANDOS[:carga], posicion.to_s.rjust(3, "0"), TERMINADOR].compact.join

    3.times do
      write_uart(data)
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)
      break if [estados_invert[:emergencia_superable], estados_invert[:en_proceso_carga]].include?(estado)
      Log.error("Cargar: estado no coincide. Reintentando")
      sleep 1
    end

    raise CriticalError if ![estados_invert[:emergencia_superable], estados_invert[:en_proceso_carga]].include?(estado)
    
    secs = 0

    while [estados_invert[:en_proceso_carga], estados_invert[:emergencia_superable], estados_invert[:homming]].include?(estado) && secs < 40
      sleep 1
      secs += 1
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)
    end

    #Log.info "Respuesta de carga: Estado: #{ESTADOS[estado]} SubEstado: #{SUB_ESTADOS[:carga][sub_estado]}"

    while [estados_invert[:en_proceso_extraccion], estados_invert[:homming]].include?(estado)
      sleep 1
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)
    end

    Log.info "Respuesta de carga: #{resp}"

    raise LoadError2.new(resp) if estado == [
      estados_invert[:en_proceso_carga],
      estados_invert[:emergencia_superable],
      estados_invert[:emergencia],
    ].include?(estado)

    {
      estado: ESTADOS[estado],
      sub_estado: SUB_ESTADOS[:carga][sub_estado],
      flags: flags,
      resp: resp,
    }
  end

  def self.extraer!(posicion, client = false)
    Log.info "Inicio de proceso de extracción de sobre en #{posicion}"

    estados_invert = ESTADOS.invert
    estado, sub_estado, flags, resp = nil

    4.times do
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)

      raise ExtractionError.new(resp) if estado == estados_invert[:emergencia]

      if flags[10] == "1"
        raise ExtractionPresenterLoaded.new(resp) if client

        return {
                 estado: ESTADOS[estado],
                 sub_estado: SUB_ESTADOS[:carga][sub_estado],
                 flags: flags,
                 resp: resp,
               }
      end

      if estado == estados_invert[:homming]
        sleep 7
      elsif estado == estados_invert[:emergencia_superable]
        sleep 2
      else
        break
      end
    end

    raise ExtractionError.new(resp) if estado == estados_invert[:emergencia_superable]

    return {
             estado: ESTADOS[estado],
             sub_estado: SUB_ESTADOS[:extraccion][sub_estado],
             flags: flags,
             resp: resp,
           } if estado != estados_invert[:en_espera]

    data = [INICIADOR, COMANDOS[:extraccion], posicion.to_s.rjust(3, "0"), TERMINADOR].compact.join

    3.times do
      write_uart(data)
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)
      break if [estados_invert[:emergencia_superable], estados_invert[:en_proceso_extraccion]].include?(estado)
      Log.error("Extraccion: estado no coincide. Reintentando")
      sleep 1
    end

    raise CriticalError if ![estados_invert[:emergencia_superable], estados_invert[:en_proceso_extraccion]].include?(estado)
    
    secs = 0

    while [estados_invert[:en_proceso_extraccion], estados_invert[:en_proceso_carga], estados_invert[:emergencia_superable], estados_invert[:homming]].include?(estado) && secs < 40
      sleep 1
      secs += 1
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)
    end

    Log.info "Respuesta de extraccion: Estado: #{ESTADOS[estado]} SubEstado: #{SUB_ESTADOS[:extraccion][sub_estado]}"

    raise ExtractionError2.new(resp) if estado == estados_invert[:emergencia]

    {
      estado: ESTADOS[estado],
      sub_estado: SUB_ESTADOS[:extraccion][sub_estado],
      flags: flags,
      resp: resp,
    }
  end

  def self.extraccion_directa!
    Log.info "Inicio de proceso de extracción directa"

    estados_invert = ESTADOS.invert
    estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)

    return if estado != estados_invert[:en_espera] || flags[10] != "1"

    data = [INICIADOR, COMANDOS[:extraccion], "000", TERMINADOR].compact.join

    write_uart(data)

    estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)

    while [estados_invert[:en_proceso_extraccion], estados_invert[:emergencia_superable], estados_invert[:homming]].include?(estado)
      sleep 1
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)
    end

    Log.info "Respuesta de extraccion: Estado: #{ESTADOS[estado]} SubEstado: #{SUB_ESTADOS[:extraccion][sub_estado]}"

    raise ExtractionError2.new(resp) if estado == estados_invert[:emergencia]

    {
      estado: ESTADOS[estado],
      sub_estado: SUB_ESTADOS[:extraccion][sub_estado],
      flags: flags,
      resp: resp,
    }
  end

  def self.posicionar!(posicion)
    Log.info "Posicionando presentador en posicion #{posicion}"

    data = [INICIADOR, COMANDOS[:posicionar], posicion.to_s.rjust(3, "0"), TERMINADOR].compact.join

    write_uart(data)

    estados_invert = ESTADOS.invert
    estado, _ = get_estado.values_at(:estado)
    secs = 0
    while estado != estados_invert[:en_espera] && secs < 30
      sleep 1
      secs += 1
      estado, _ = get_estado.values_at(:estado)
    end

    Log.info "Respuesta de posicionar: Estado: #{ESTADOS[estado]}"

    {
      estado: ESTADOS[estado],
    }
  end

  def self.cero!
    Log.info "Llevando presentador a cero"

    data = [INICIADOR, COMANDOS[:cero], TERMINADOR].compact.join

    write_uart(data)

    estados_invert = ESTADOS.invert
    estado, sub_estado, sensores, flags, resp = get_estado.values_at(:estado, :sub_estado, :sensores, :flags, :resp)
    secs = 0
    while estado == estados_invert[:homming] && secs < 80
      sleep 1
      secs += 1
      estado, resp, _ = get_estado.values_at(:estado, :resp)
    end

    Log.info "Respuesta de cero: Estado: #{ESTADOS[estado]}"

    raise ZeroNotFound.new(resp) if [estados_invert[:homming], estados_invert[:emergencia]].include?(estado)

    {
      estado: estado,
      sub_estados: sub_estado,
      sensores: sensores,
      flags: flags,
      resp: resp,
    }
  end

 # def self.setup!
 #   estado, _ = get_estado.values_at :estado
 #   return if estado != ESTADOS.invert[:estado_inicial]
 #
 #   Log.info "Inicializando presentador"
 #   cero!
 # end

  def self.manual!
    Log.info "Modo manual"

    data = [INICIADOR, COMANDOS[:manual], TERMINADOR].compact.join

    write_uart(data)
  end

  def self.enviar_uart(data)
    data = [INICIADOR, data, TERMINADOR].compact.join
    resp = nil

    get_uart do |uart|
      uart.write(data)
      sleep 0.5
      resp = uart.read
    end

    {
      resp: resp,
    }
  end

  def self.testUart!
    e = 0
    resp = nil
    data = [INICIADOR, COMANDOS[:extraccion], "000", TERMINADOR].compact.join

    while 1
      e = e + 1
      estado, sub_estado, flags, resp, _ = get_estado.values_at(:estado, :sub_estado, :flags, :resp)
      Log.info "test #{e}: #{resp}"
      write_uart(data)
      sleep 0.1
    end
  end
  
end



