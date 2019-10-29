# Cada registro o línea del archivo de novedades enviado por el banco.
#
# # Estructura del archivo de novedades
#
# Cada sobre tiene una clave asignada por el proveedor que se llama
#
#   - Nro producto proveedor (clave 1 novedades)
#
# y es lo que se usaría para ingresar un sobre a la máquina. Hay una segunda
# clave opcional que también puede ser ingresada para registrar un sobre,
# llamada
#
#   - Nro producto alternativo (clave 1 alternativa)
#
# Los siguientes campos son
#
#   - Tipo de documento (clave 2  novedades)
#   - Nro documento (clave 2 novedades)
#
# Tipo está codificado según la tabla Novedad::DOCUMENTO. El siguiente,
# `clave_digital`, es el hash generado con sha256 a partir del documento con
# padding de ceros a 13 caracteres y la clave en sí. Por ejemplo:
#
#   documento: 31065175
#   clave: 7894
#
#   sha256(00000310651757894) => 89d7d1208500260b83cad9ef68f1bc596d6dc966b7645a4a39cff74dfdb18117
#
# Los siguientes campos no se usan en la aplicación pero los guardamos igual por las dudas:
#
#   - Tipo producto SID
#   - Tipo producto Banco
#   - Nro producto SID
#   - Tipo producto SID 2
#   - Tipo producto Banco  2
#   - Nro producto SID  2
#
# Apellido y nombre "que está en el plástico":
#
#   - Apellido y Nombre
#
# Apellido y nombre del titular de la cuenta (para mensajes al cliente):
#
#   - Apellido y Nombre  titular
#
# Fecha y hora en formatos aaaa-mm-dd y hhmmss:
#
#   - Fecha informacion
#   - Hora informacion
#
# Ejemplos:
#
#   G000000000025859325
#   < vacío >
#   00
#   32813474
#   HASH567890123456789012345678901234567890123456789012345678901234
#   650
#   109
#   005165850198189589
#   < vacío >
#   < vacío >
#   < vacío >
#   LEDESMA,JORGE EDGAR
#   LEDESMA,JORGE EDGAR
#   2017-12-07
#   163000
#

require 'csv'

class Novedad < ActiveRecord::Base
  self.table_name = 'novedades'

  DOCUMENTOS = {
    '00' => 'DNI',
    '27' => 'DNI Masculino < 10MM',
    '28' => 'DNI Femenino < 10MM',
    '31' => 'DNI extranjero',
    '25' => 'Libreta Enrolamiento',
    '26' => 'Libreta Cívica',
    '30' => 'Pasaporte',
    '01' => 'Cedula identidad Policía Federal'
  }

  validates :nro_proveedor,
    presence: true
  validates :tipo_documento,
    presence: true
  validates :nro_documento,
    presence: true,
    numericality: { only_integer: true }
  validates :clave_digital,
    presence: true
  validates :nombre,
    presence: true

  # Parsear una fila del csv de novedades creando los objetos derivados (Novedad, Cliente, Sobre, Tarjeta)
  def parsear(fila)
    transaction do
      update(
        nro_proveedor: fila[0].to_s.strip.encode(Encoding::UTF_8),
        nro_alternativo: fila[1].to_s.strip.encode(Encoding::UTF_8),

        # A veces viene 0, a veces 00
        tipo_documento: fila[2].to_s.encode(Encoding::UTF_8).rjust(2, '0'),
        nro_documento: fila[3].to_s.encode(Encoding::UTF_8),
        clave_digital: fila[4].to_s.encode(Encoding::UTF_8),

        # Se exportan y tienen que ver con el sobre
        tipo_sid: fila[5].to_s.encode(Encoding::UTF_8),
        tipo_banco: fila[6].to_s.encode(Encoding::UTF_8),
        nro_sid: fila[7].to_s.encode(Encoding::UTF_8),
        tipo_sid_2: fila[8].to_s.encode(Encoding::UTF_8),
        tipo_banco_2: fila[9].to_s.encode(Encoding::UTF_8),
        nro_sid_2: fila[10].to_s.encode(Encoding::UTF_8),

        nombre: fila[11].to_s.strip.encode(Encoding::UTF_8),
        nombre_titular: fila[12].to_s.strip.encode(Encoding::UTF_8),

        fecha: fila[13].to_s.encode(Encoding::UTF_8),
        hora: Time.strptime(fila[14].to_s.encode(Encoding::UTF_8), '%H%M%S')
      )

      # Un sólo Cliente por sobre, que representa al titular de cuenta y a
      # quien pertenecen los datos de login (nombre, dni y codigo).
      # En la práctica se puede pensar que siempre retira el sobre el titular.
      begin
        cliente = Cliente.find_or_create_by!(
          tipo_documento: self.tipo_documento,
          nro_documento: self.nro_documento
        ) do |c|
          c.nombre = self.nombre
          c.clave_digital = self.clave_digital
          c.intentos_fallidos = 0
        end

        cliente.update clave_digital: self.clave_digital
        cliente.update nombre: self.nombre
        cliente.update intentos_fallidos: 0

        # El sobre al que identifica este número de proveedor (Clave 1 novedades
        # según la documentación)
        sobre = cliente.sobres.find_or_create_by!(
          nro_proveedor: self.nro_proveedor,
          nro_alternativo: self.nro_alternativo
        ) do |s|
          s.tipo_sid = self.tipo_sid
          s.tipo_banco = self.tipo_banco
          s.nro_sid = self.nro_sid
          s.tipo_sid_2 = self.tipo_sid_2
          s.tipo_banco_2 = self.tipo_banco_2
          s.nro_sid_2 = self.nro_sid_2
        end

        sobre.update tipo_sid: self.tipo_sid
        sobre.update tipo_banco: self.tipo_banco
        sobre.update nro_sid: self.nro_sid
        sobre.update tipo_sid_2: self.tipo_sid_2
        sobre.update tipo_banco_2: self.tipo_banco_2
        sobre.update nro_sid_2: self.nro_sid_2

        # Las tarjetas se usan para control visual de sobres cargados
        # (cada línea en 'index_clientes')
        sobre.tarjetas.find_or_create_by!(
          nombre: self.nombre
        )
      rescue ActiveRecord::RecordInvalid
        Log.error "Error al cargar #{self.tipo_documento} #{self.nro_documento} #{self.nombre_titular}"
      end
    end
  end

  # Parsear el csv de novedades entero
  def self.parsear(csv)
    Log.info "Parseando archivo novedades"

    CSV.foreach csv, headers: false, col_sep: ';', encoding: 'ISO-8859-1' do |f|
      Novedad.new.parsear f
    end
  end
end
