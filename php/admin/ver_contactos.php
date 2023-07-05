<?php

// Conexión a la base de datos usando database.php
require_once '../database.php';
$conn = conectarDB();

$sql = "SELECT * FROM contactos ORDER BY id DESC LIMIT 50";
$result = $conn->query($sql);

if ($result->num_rows > 0) {
    echo "<table border='1'>
            <tr>
                <th>ID</th>
                <th>Nombre</th>
                <th>Teléfono</th>
                <th>Email</th>
                <th>Fecha</th>
                <th>Cantidad de Invitados</th>
                <th>Zona</th>
                <th>FechaContacto</th>
            </tr>";
    while ($row = $result->fetch_assoc()) {
        echo "<tr>
                <td>{$row['id']}</td>
                <td>{$row['nombre']}</td>
                <td>{$row['telefono']}</td>
                <td>{$row['email']}</td>
                <td>{$row['fecha']}</td>
                <td>{$row['cantidad_invitados']}</td>
                <td>{$row['zona']}</td>
                <td>{$row['FechaConsulta']}</td>
            </tr>";
    }
    echo "</table>";
} else {
    echo "No se encontraron resultados.";
}

$conn->close();
?>
