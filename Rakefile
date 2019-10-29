require_relative 'boot'

task :default => :migrate

desc 'Correr migraciones'
task :migrate do
  ActiveRecord::Migrator.migrate('db/migrate', ENV['VERSION'] ? ENV['VERSION'].to_i : nil)
end

desc 'Cargar superadmin inicial'
task :superadmin do
  if ENV['dni'].nil? || ENV['pass'].nil? || ENV['nombre'].nil?
    puts
    puts 'Uso: '
    puts '  rake superadmin dni=12345678 pass=1234 nombre="Juan Salvo"'
    puts
  else
    nombre = ENV['nombre']
    password = ENV['pass']
    nro_documento = ENV['dni']

    # Borrar todos los superadmins
    Admin.where(super: true).destroy_all

    # Crear un superadmin con estos datos si no existe
    Admin.find_or_create_by!(nro_documento: nro_documento) do |admin|
      admin.super = true
      admin.password = password
      admin.nombre = nombre
    end
  end
end

desc 'Generar hashes de usuario con código 1234'
task :password_de_prueba do
  Cliente.find_each do |c|
    c.update_attribute :clave_digital, c.generar_clave_digital('1234')
  end
end

desc 'Parsea un csv de novedades'
task :novedades do
  if ENV['csv'].nil?
    puts
    puts 'Uso: '
    puts '  rake novedades csv=test/novedades.csv'
    puts
  else
    Novedad.parsear ENV['csv']
  end
end
