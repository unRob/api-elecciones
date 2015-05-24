#!/usr/bin/env ruby
# encoding: utf-8

require 'httparty'
require 'json'
require 'active_support/all'

lista = "https://pef-gpo3.ine.mx/precandidatos-servicio-rest/rest/candidatos/obtenerListaDeCandidatosPorFiltrosPre"
url_actor = 'https://pef-gpo3.ine.mx/precandidatos-servicio-rest/rest/candidatos/obtenerCandidatoPorId'
q = "id:%s"
headers = {"Content-type" => 'text/plain'}

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

distritos = {}
ids = []

if File.exists?('./ids.json')
  ids = JSON.parse(File.read('./ids.json'))
else
  (1..32).each do |edo|
    puts "Crawling: #{edo}"
    res = JSON.parse(HTTParty.post(lista, body: "tc:1,ie:#{edo}", headers: headers).body, symbolize_names: true)
    ids += res.map {|r| r[:idPropietario]}
  end

  File.open('./ids.json', 'w') do |f|
    f << ids.to_json
  end
end

def formatoTelefono digitos, sinLD = false
  formatted = case digitos.length
    when 13, digitos.match(/^044/)
       # 044 55 5555 5555
      if digitos.match(/^044(55|33|81)/)
        digitos.scan(/^(\d{3})(\d{2})(\d{4})(\d{4})$/)
      else
        # 044 777 777 777
        digitos.scan(/^(\d{3})(\d{3})(\d{3})(\d{3})$/)
      end
    when 12
       # 01 55 5555 5555
      if digitos.match(/^01(55|33|81)/)
        digitos.scan(/^(\d{2})(\d{2})(\d{4})(\d{4})$/)
      else
        # 01 777 777 7777
        digitos.scan(/^(\d{2})(\d{3})(\d{3})(\d{4})$/)
      end
    # 777 777 7777
    when 10 then digitos.scan(/^(\d{3})(\d{3})(\d{4})$/)
    # 5555 5555
    when 8 then digitos.scan(/^(\d{4})(\d{4})$/)
    # 777 7777
    when 7 then digitos.scan(/^(\d{3})(\d{4})$/)
    else
      raise "No se que hacer con #{digitos.length} dígitos <#{digitos.match(/^044/)}>"
  end.flatten.join(' ')

  formatted = formatted.gsub(/^01\s?/, '') if sinLD
  formatted
end

def partidos args
  args.map do |arg|
    arg = arg.mb_chars.downcase
    case arg
      when /independiente/ then :independiente
      when 'partido revolucionario institucional' then :pri
      when 'partido de la revolución democrática' then :prd
      when 'partido del trabajo' then :pt
      when 'coalición de izquierda progresista' then [:prd, :pt]
      when 'partido verde ecologista de méxico' then [:pvem]
      when 'partido acción nacional' then :pan
      else arg
    end
  end.flatten
end


ids.each do |i|
  body = q % i
  c = JSON.parse(HTTParty.post(url_actor, body: body, headers: headers).body, symbolize_names: true)

  next unless c[:idDistritoCan]
  dto = "df-#{c[:idEstadoCan]}-#{c[:idDistritoCan]}"


  telefono = formatoTelefono(c[:telefono]) if c[:telefono]
  if c[:fotografia]
    foto = "http://www.ine.mx/portal/Elecciones/Proceso_Electoral_Federal_2014-2015/CandidatasyCandidatos/imagencandidato.html?k=#{c[:fotografia]}&s=#{c[:sexo]}"
  else
    foto = "http://www.ine.mx/portal/Elecciones/Proceso_Electoral_Federal_2014-2015/CandidatasyCandidatos/img/Candidatos/Candidat#{c[:sexo] == 'Hombre' ? 'o' : 'a'}Avtr1.png"
  end

  nombre = c[:nombrePropietario].mb_chars.squish.titleize
  suplente = c[:nombreSuplente].mb_chars.squish.titleize

  actor = {
    nombre: nombre,
    suplente: suplente,
    partidos: partidos(c[:nombreAsociacion].split('-')),
    sexo: c[:sexo] == "Hombre",
    edad: c[:edad],
    telefono: telefono,
    correo: c[:correoElectronicoPub],
    casa_campana: c[:domicilioPub],
    foto: foto,
    mentiras: {
      laborales: c[:historiaProfesional],
      trayectoria: c[:trayectoriaPol],
      templete: c[:razonPolitica]
    },
    social: []
  }

  actor[:social] << {red: :facebook, url: "https://#{c[:redFacebook].gsub(/^https?:\/\//, '')}"} if c[:redFacebook]
  actor[:social] << {red: :twitter, url: "https://twitter.com/"+c[:redTwitter].gsub('@', '')} if c[:redTwitter]
  actor[:social] << {red: :youtube, url: c[:redYoutube]} if c[:redYoutube]

  distritos[dto] ||= []
  distritos[dto] << actor
  puts "#{dto} / #{body} / #{actor[:partidos].join(',')}"

end

puts "\n\n\n";

distritos.each do |dto, actores|

  puts "#{dto} - #{actores.count} candidatos"
  File.open("../public/data/candidatoas/#{dto}.json", 'w') do |f|
    f << actores.to_json
  end

end