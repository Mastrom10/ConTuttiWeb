const ALLOWED_ORIGINS = new Set([
  "https://contuttipizzaparty.com",
  "https://www.contuttipizzaparty.com",
]);

const REQUIRED_FIELDS = [
  "nombre",
  "telefono",
  "email",
  "fecha",
  "cantidad_invitados",
  "zona",
];

function corsHeaders(origin) {
  const allowedOrigin = ALLOWED_ORIGINS.has(origin)
    ? origin
    : "https://contuttipizzaparty.com";

  return {
    "Access-Control-Allow-Origin": allowedOrigin,
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "POST,OPTIONS",
    "Content-Type": "application/json",
  };
}

function jsonResponse(statusCode, body, origin) {
  return {
    statusCode,
    headers: corsHeaders(origin),
    body: JSON.stringify(body),
  };
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function validatePayload(data) {
  for (const field of REQUIRED_FIELDS) {
    if (!data[field] || String(data[field]).trim() === "") {
      return `El campo ${field} es obligatorio.`;
    }
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(data.email)) {
    return "El email no es válido.";
  }

  const telefonoRegex = /^([0-9]{2,4})-?([0-9]{6,8})$/;
  if (!telefonoRegex.test(data.telefono)) {
    return "El teléfono no es válido.";
  }

  return null;
}

function buildEmailHtml(data) {
  const rows = [
    ["Nombre", data.nombre],
    ["Teléfono", data.telefono],
    ["Email", data.email],
    ["Fecha del evento", data.fecha],
    ["Cantidad de invitados", data.cantidad_invitados],
    ["Zona", data.zona],
  ];

  const tableRows = rows
    .map(
      ([label, value]) =>
        `<tr><td style="padding:8px;border:1px solid #ddd;"><strong>${escapeHtml(label)}</strong></td><td style="padding:8px;border:1px solid #ddd;">${escapeHtml(value)}</td></tr>`
    )
    .join("");

  return `
    <div style="font-family:Arial,sans-serif;color:#111;">
      <h2 style="color:#b88600;">Nueva Consulta WEB</h2>
      <p>Recibiste una nueva consulta desde el formulario del sitio web.</p>
      <table style="border-collapse:collapse;width:100%;max-width:640px;">${tableRows}</table>
      <p style="margin-top:16px;color:#666;">Respondé al cliente lo antes posible.</p>
    </div>
  `;
}

async function sendWithResend(data) {
  const apiKey = process.env.RESEND_API_KEY;
  const fromEmail = process.env.RESEND_FROM_EMAIL;
  const toEmail = process.env.RESEND_TO_EMAIL;

  if (!apiKey || !fromEmail || !toEmail) {
    throw new Error("Faltan variables de entorno de Resend.");
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: fromEmail,
      to: [toEmail],
      reply_to: [data.email],
      subject: "Nueva Consulta WEB",
      html: buildEmailHtml(data),
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Resend error ${response.status}: ${errorBody}`);
  }

  return response.json();
}

exports.handler = async (event) => {
  const origin = event.headers?.origin || event.headers?.Origin || "";

  if (event.requestContext?.http?.method === "OPTIONS") {
    return {
      statusCode: 204,
      headers: corsHeaders(origin),
      body: "",
    };
  }

  try {
    const data = JSON.parse(event.body || "{}");
    const validationError = validatePayload(data);

    if (validationError) {
      return jsonResponse(400, { message: validationError }, origin);
    }

    await sendWithResend(data);
    return jsonResponse(200, { message: "Consulta enviada con éxito" }, origin);
  } catch (error) {
    console.error(error);
    return jsonResponse(
      500,
      { message: "No se pudo enviar la consulta. Intentá nuevamente." },
      origin
    );
  }
};
