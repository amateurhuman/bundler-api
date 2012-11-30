require 'sinatra/base'
require 'sequel'
require 'json'
require_relative '../bundler_api'
require_relative '../bundler_api/dep_calc'
require_relative '../bundler_api/metriks'
require_relative '../bundler_api/honeybadger'

class BundlerApi::Web < Sinatra::Base
  RUBYGEMS_URL = "https://www.rubygems.org"

  unless ENV['RACK_ENV'] == 'test'
    use Metriks::Middleware
    use Honeybadger::Rack
  end

  def initialize(conn = Sequel.connect(ENV["FOLLOWER_DATABASE_URL"], :max_connections => ENV['MAX_THREADS']))
    super()
    @conn = conn
  end

  error do |e|
    # Honeybadger 1.3.1 only knows how to look for rack.exception :(
    request.env['rack.exception'] = request.env['sinatra.error']
  end

  get "/api/v1/dependencies" do
    return "" unless params[:gems]
    Metriks.timer('dependencies').time do
      gems = params[:gems].split(',')
      Metriks.histogram('gems.count').update(gems.size)
      deps = BundlerApi::DepCalc.deps_for(@conn, gems)
      Metriks.histogram('dependencies.count').update(deps.size)
      Metriks.timer('dependencies.marshal').time do
        Marshal.dump(deps)
      end
    end
  end

  get "/api/v1/dependencies.json" do
    gems = params[:gems].split(',')
    DepCalc.deps_for(@conn, gems).to_json
  end

  get "/quick/Marshal.4.8/:id" do
    redirect "#{RUBYGEMS_URL}/quick/Marshal.4.8/#{params[:id]}"
  end

  get "/fetch/actual/gem/:id" do
    redirect "#{RUBYGEMS_URL}/fetch/actual/gem/#{params[:id]}"
  end

  get "/gems/:id" do
    redirect "#{RUBYGEMS_URL}/gems/#{params[:id]}"
  end

  get "/specs.4.8.gz" do
    redirect "#{RUBYGEMS_URL}/specs.4.8.gz"
  end

end
