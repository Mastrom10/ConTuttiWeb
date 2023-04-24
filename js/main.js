document.addEventListener("DOMContentLoaded", () => {
    const form = document.getElementById("contacto-form");
  
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      enviarFormulario();
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
      } else {
        alert("Error al registrar el contacto");
      }
    } catch (error) {
      alert("Error al enviar el formulario");
    }
  }
  