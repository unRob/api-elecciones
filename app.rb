# encoding: utf-8
require 'rubygems'
require 'bundler'
require 'open-uri'
Bundler.require

RPATITO = "http://representantes.pati.to/busqueda/geo/diputados/%s/%s"
GOOGLE = "https://maps.googleapis.com/maps/api/geocode/json?%s&api_key=AIzaSyD8qYIlRcEaYrYrAjKtE6Rz8XoMisOhiGI"

before do
  if request.request_method == 'OPTIONS'
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET"

    halt 200
  end

  content_type 'application/json'
end

def distrito coords
  url = sprintf(RPATITO, *coords);
  res = open(url).read;
  data = JSON.parse(res, symbolize_names: true)

  if data[:status] == 'error'
    return false
  end

  data[:distrito] = data[:distrito].gsub('df-', '')

  data
end


get '/casillas/?:seccion' do |seccion|

  path = "./public/data/casillas/#{seccion}.json"

  e, s = seccion.split('-')
  funcionarios = open("http://www.ine.mx/archivos3/portal/historico/recursos/Internet/Proceso_Electoral_Federal_2014-2015/funcionarios/rsc/jsFun/#{e}/#{e}-#{s}.js").read.split('=').last
  funcionarios = JSON.parse(funcionarios.squish, symbolize_names: true)

  casillas = {}

  funcionarios.each do |f|
    tipo = f[:casilla].downcase.squish

    id_casilla = f[:idDomicilio]+':'+tipo

    funcionario = {
      nombre: f[:nombre].mb_chars.titleize,
      apellidos: [f[:apellidoPaterno], f[:apellidoMaterno]].map { |c|
        c.mb_chars.squish.titleize
      }.join(' '),
      cargo: f[:cargo].mb_chars.downcase.gsub('general', '').squish
    }

    if casillas[id_casilla].nil?

      comps = f[:domicilio].split(',')
      calle, numero = comps.take(2).map {|c| c.squish.gsub('#', '').mb_chars.squish.titleize }
      cp = comps.last.squish.gsub(/\D/, '')

      begin

        query = {
          address: "#{calle} #{numero}",
          components: "countury:MX|postal_code#{cp}"
        }.map {|k,v| "#{k}=#{URI::encode v}"}.join('&')

        data = open(GOOGLE % query).read
        data = JSON.parse(data, symbolize_names: true)

        if addr = data[:results].first
          coords = addr[:geometry][:location].values
        else
          coords = nil
        end
        # coords = GOOGLE % query
      rescue => e
        coords = nil
      end

      casillas[id_casilla] = {
        nombre: f[:ubicacionCasilla].mb_chars.squish.titleize,
        coords: coords,
        direccion: {
          calle: calle,
          numero: numero,
          cp: cp
        },
        referencia: f[:referenciaCasilla],
        funcionarios: []
      }
    end

    casillas[id_casilla][:funcionarios] << funcionario
  end

  casillas = casillas.values

  File.open(path, 'w') do |f|
    f << casillas.to_json
  end

  return casillas.to_json
end