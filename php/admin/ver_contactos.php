<?php
$username = 'admin';
$password = 'admin';
$valid_passwords = array($username => $password);
$valid_users = array_keys($valid_passwords);

$user = $_SERVER['PHP_AUTH_USER'];
$pass = $_SERVER['PHP_AUTH_PW'];

$validated = (in_array($user, $valid_users)) && ($pass == $valid_passwords[$user]);

if (!$validated) {
    header('WWW-Authenticate: Basic realm="My Realm"');
    header('HTTP/1.0 401 Unauthorized');
    echo "No estás autorizado para ver esta página.";
    exit;
}

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
            </tr>";
    }
    echo "</table>";
} else {
    echo "No se encontraron resultados.";
}

$conn->close();
?>
