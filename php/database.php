<?php
function conectarDB() {
    $servername = "localhost";
    $username = "ContuttiUser";
    $password = "Merluza23";
    $dbname = "Contutti";

    $conn = new mysqli($servername, $username, $password, $dbname);

    if ($conn->connect_error) {
        die("Error al conectar a la base de datos: " . $conn->connect_error);
    }

    return $conn;
}
