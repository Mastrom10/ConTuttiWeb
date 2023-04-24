document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("contacto-form");
  const mensajeExito = document.getElementById("contacto-exito");

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const enviado = await enviarFormulario();

    if (enviado) {
      form.classList.add("d-none");
      mensajeExito.classList.remove("d-none");
    }
  });
});

async function enviarFormulario() {
  const form = document.getElementById("contacto-form");
  const formData = new FormData(form);
  const data = Object.fromEntries(formData.entries());

  try {
    const response = await fetch("php/controller/ContactoController.php", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    });

    if (response.ok) {
      const result = await response.json();
      alert(result.message);
      return true;
    } else {
      alert("Error al registrar el contacto");
      return false;
    }
  } catch (error) {
    alert("Error al enviar el formulario");
    return false;
  }
}
