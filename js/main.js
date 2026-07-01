document.addEventListener("DOMContentLoaded", () => {
  const form = document.getElementById("contacto-form");
  const mensajeExito = document.getElementById("contacto-exito");
  const mensajeError = document.getElementById("contacto-error");
  const submitBtn = document.getElementById("contacto-submit");
  const personasSlider = document.getElementById("personas");
  const personasValue = document.getElementById("personas-value");
  const telefonoInput = document.getElementById("telefono");
  const telefonoRegex = /^([0-9]{2,4})-?([0-9]{6,8})$/;
  const nav = document.querySelector(".site-nav");

  personasSlider.addEventListener("input", (event) => {
    const value = event.target.value;
    personasValue.textContent = value === "101" ? "+100" : value;
  });

  window.addEventListener("scroll", () => {
    nav.classList.toggle("site-nav--scrolled", window.scrollY > 24);
  });

  document.querySelectorAll('a[href^="#"]').forEach((link) => {
    link.addEventListener("click", (event) => {
      const targetId = link.getAttribute("href");
      if (targetId.length <= 1) return;
      const target = document.querySelector(targetId);
      if (!target) return;
      event.preventDefault();
      target.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    mensajeExito.classList.add("d-none");
    mensajeError.classList.add("d-none");

    const telefonoValido = telefonoRegex.test(telefonoInput.value);
    if (!telefonoValido) {
      telefonoInput.setCustomValidity(
        "Por favor ingrese un número de teléfono válido (ej. 11-12345678)"
      );
      telefonoInput.reportValidity();
      return;
    }

    telefonoInput.setCustomValidity("");
    submitBtn.disabled = true;
    submitBtn.textContent = "Enviando...";

    const formData = new FormData(form);
    const data = Object.fromEntries(formData.entries());
    data.cantidad_invitados =
      data.cantidad_invitados === "101" ? "+100" : data.cantidad_invitados;

    try {
      const apiUrl =
        window.CONTUTTI_CONFIG?.apiUrl ||
        "https://PLACEHOLDER.execute-api.us-east-1.amazonaws.com/contact";

      const response = await fetch(apiUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(data),
      });

      const result = await response.json().catch(() => ({}));

      if (response.ok) {
        form.reset();
        personasValue.textContent = "40";
        form.classList.add("d-none");
        mensajeExito.classList.remove("d-none");
      } else {
        throw new Error(result.message || "Error al enviar la consulta");
      }
    } catch (error) {
      mensajeError.textContent =
        error.message ||
        "No pudimos enviar tu consulta. Probá de nuevo o escribinos por WhatsApp.";
      mensajeError.classList.remove("d-none");
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = "Contactar";
    }
  });
});
