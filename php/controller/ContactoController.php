<?php
require_once '../model/Contacto.php';
require_once '../database.php';

class ContactoController {
    private $db;

    public function __construct($db) {
        $this->db = $db;
    }

    public function registrarContacto($contacto) {
        $stmt = $this->db->prepare("INSERT INTO contactos (nombre, telefono, email, fecha, cantidad_invitados, zona) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->bind_param("ssssis", $contacto->nombre, $contacto->telefono, $contacto->mail, $contacto->fecha, $contacto->cantidad_invitados, $contacto->zona);
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
    $contacto->mail = $data['mail'];
    $contacto->fecha = $data['fecha'];
    $contacto->cantidad_invitados = $data['cantidad_invitados'];
    $contacto->zona = $data['zona'];

    $contactoController->registrarContacto($contacto);

    header('Content-Type: application/json');
    echo json_encode(['message' => 'Contacto registrado con éxito']);
}
