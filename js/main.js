document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("contacto-form");
  const mensajeExito = document.getElementById("contacto-exito");




  const personas = document.getElementById("personas");
  const personasValue = document.getElementById("personas-value");

  personas.addEventListener("input", () => {
    if (personas.value == "101") {
      personasValue.textContent = "más de 100";
    } else {
      personasValue.textContent = personas.value;
    }
  });

  const telefonoInput = document.getElementById("telefono");
  const telefonoRegex = /^([0-9]{4})-?([0-9]{6})$/;


  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const telefonoValido = telefonoRegex.test(telefonoInput.value);
  
    if (!telefonoValido) {
      telefonoInput.setCustomValidity("Por favor ingrese un número de teléfono válido (ej. 11-12345678)");
      telefonoInput.reportValidity();
    } else {
      telefonoInput.setCustomValidity("");
      const enviado = await enviarFormulario();
  
      if (enviado) {
        form.classList.add("d-none");
        mensajeExito.classList.remove("d-none");
      }
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
