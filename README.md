# Elecciones 2015

```
info = http("http://representantes.pati.to/busqueda/geo/diputados/19.405718013742895/-99.16584509872088")

candidatoas = http("/candidatoas/" + info.distrito + ".json")

casillas = http("/casilla/" + info.seccion.id)

casillas = [{
    nombre: "String"
    direccion: {
        nombre: "String",
        coords: ["lat <Float>", "lng <Float>"],
        direccion: {
            calle: "String",
            numero: "String",
            cp: "String"
        },
        referencia: "String",
        funcionarios: [
            {
                nombre: "String", 
                apellidos: "String",
                cargo: "String"
            }
        ]
    }
}]

```