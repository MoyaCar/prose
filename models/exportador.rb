# Exporta a CSV los movimientos registrados en el sistema sobre los sobres
#
# Formato de las columnas en el archivo (tienen que ir con padding)
#
#   Tipo producto SID           AN (03)
#   Tipo producto Banco         AN (03)
#   Nro producto SID            AN (18)
#   Tipo producto SID 2         AN (03)
#   Tipo producto Banco 2       AN (03)
#   Nro producto SID 2          AN (18)
#   Tipo documento              AN (02)
#   Nro documento               AN (13)
#   Estado en máquina           AN (20)       (descripción del estado: ej: montado, entregado, etc)
#   Fecha de estado             AN (10)   aaaa-mm-dd
#   Nro producto proveedor      AN (50)
#   Fecha información           AN (10)     aaaa-mm-dd
#   Hora información            AN (06)    hhmmss

class Exportador
  attr_reader :sobres, :fecha

  def initialize(sobres = Sobre.all)
    @sobres = sobres
    @fecha = Time.now
  end

  def exportar!
    Log.info "Exportando movimientos"

    CSV.open(archivo_csv, "w", headers: false, force_quotes: true) do |csv|
      sobres.each do |sobre|
        csv << generar_fila(sobre)
      end
      csv.fsync()
    end
  end

  def nombre_archivo
    "movimientosADM-#{fecha.strftime("%Y%m%d")}.csv"
  end

  def archivo_csv
    File.join Configuracion.path_base_archivos, "movimientos", nombre_archivo
  end

  def generar_fila(sobre)
    [
      sobre.tipo_sid.to_s.rjust(3, " "),
      sobre.tipo_banco.to_s.rjust(3, " "),
      sobre.nro_sid.to_s.rjust(18, " "),
      sobre.tipo_sid_2.to_s.rjust(3, " "),
      sobre.tipo_banco_2.to_s.rjust(3, " "),
      sobre.nro_sid_2.to_s.rjust(18, " "),

      sobre.cliente.tipo_documento,
      sobre.cliente.nro_documento.rjust(13, "0"),

      sobre.estado.rjust(20, " "),
      sobre.updated_at.strftime("%Y-%m-%d"),

      sobre.nro_proveedor.rjust(50, " "),
      sobre.novedad.fecha.strftime("%Y-%m-%d"),
      sobre.novedad.hora.strftime("%H%M%S"),
    ]
  end
end
