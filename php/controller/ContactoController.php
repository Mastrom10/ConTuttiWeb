<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);


require_once '../model/Contacto.php';
require_once '../database.php';

class ContactoController {
    private $db;

    public function __construct($db) {
        $this->db = $db;
    }

    public function registrarContacto($contacto) {
        $stmt = $this->db->prepare("INSERT INTO contactos (nombre, telefono, email, fecha, cantidad_invitados, zona) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("ssssis", $contacto->nombre, $contacto->telefono, $contacto->email, $contacto->fecha, $contacto->cantidad_invitados, $contacto->zona);
        $stmt->execute();
        $stmt->close();
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $db = conectarDB();
    $contactoController = new ContactoController($db);

    $data = json_decode(file_get_contents('php://input'), true);

    $contacto = new Contacto();
    $contacto->nombre = $data['nombre'];
    $contacto->telefono = $data['telefono'];
    $contacto->email = $data['email'];
    $contacto->fecha = $data['fecha'];
    $contacto->cantidad_invitados = $data['cantidad_invitados'];
    $contacto->zona = $data['zona'];

    $contactoController->registrarContacto($contacto);


    // Enviar datos al webhook
    $ch = curl_init();

    curl_setopt($ch, CURLOPT_URL, 'https://hook.us1.make.com/5i3f1rv1f2a44iqch43wqcbbha3tvz3p');
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json'));  // Establece el encabezado de contenido a "application/json"
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    $response = curl_exec($ch);

    curl_close($ch);


    header('Content-Type: application/json');
    echo json_encode(['message' => 'Contacto registrado con exito']);
}
