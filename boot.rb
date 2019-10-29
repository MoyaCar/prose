require "listen"
require "cuba"
require "cuba/render"
require "cuba/flash"
require "erb"
require "active_record"
require "sqlite3"
require "yaml"
require "i2c"
require "i2c/driver/i2c-dev"
require "uart"
require "rufus-scheduler"

require_relative "plugins/view_helpers"
require_relative "plugins/controller_helpers"

# Configuración de la aplicación
configuration = YAML::load(IO.read("config.yml"))

ActiveRecord::Base.establish_connection(configuration["db"])

ENV["TZ"] = "America/Argentina/Buenos_Aires"
#Time.zone = "America/Argentina/Buenos_Aires"

# Logger accesible globalmente, nivel de logueo según environment
log_level = "Logger::#{configuration["log"][ENV["RACK_ENV"]] || "DEBUG"}"

require_relative "models/log"
Log.inicializar(log_level)

# I18n
I18n.available_locales = [:es]
I18n.default_locale = :es
I18n.load_path << "locales/rails-i18n.es.yml"

# Rack Middlewares
# Crear sesión para los flashes informativos
Cuba.use Rack::Session::Cookie, secret: ENV["SED_SESSION_KEY"]
Cuba.use Cuba::Flash

# Cuba plugins
Cuba.plugin Cuba::Render
Cuba.plugin ViewHelpers
Cuba.plugin ControllerHelpers

require_relative "models/nucleo"
require_relative "models/novedad"
require_relative "models/admin"
require_relative "models/sobre"
require_relative "models/cliente"
require_relative "models/tarjeta"
require_relative "models/configuracion"
require_relative "models/exportador"
require_relative "decorators/tarjeta_decorator"

# Servir archivos estáticos desde este directorio
Cuba.use Rack::Static, root: "public",
                       urls: ["/js", "/css", "/fonts", "/img"]

# En app definimos rutas y controllers
require_relative "app"
