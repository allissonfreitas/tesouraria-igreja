// ============================================================
// Edge Function: ocr-relatorio
// Recebe a foto do Relatório de Receitas e usa o Gemini para
// ler os campos escritos à caneta, devolvendo JSON para o app.
// A chave do Gemini fica em segredo no servidor (GEMINI_API_KEY).
// ============================================================

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const PROMPT = `Você lê fotos de um formulário de igreja chamado "RELATÓRIO DE RECEITAS", preenchido à caneta.
Extraia os campos e responda SOMENTE com JSON válido, sem markdown, neste formato:
{
  "num": "número do relatório (impresso em vermelho no topo)",
  "unidade": "nome da unidade",
  "data": "data da reunião no formato YYYY-MM-DD (ano com 20 na frente, ex.: 26 vira 2026)",
  "hora": "hora da reunião no formato HH:MM",
  "vr": total de VR / recibos pagos na localidade em número,
  "q2": quantidade de notas de R$2, "q5": quantidade de notas de R$5,
  "q10": quantidade de notas de R$10, "q20": quantidade de notas de R$20,
  "q50": quantidade de notas de R$50, "q100": quantidade de notas de R$100,
  "q200": quantidade de notas de R$200,
  "moedas": valor em moedas,
  "pix": valor de depósitos PIX/transferências,
  "cheque": total de cheque,
  "cartao": total de cartão,
  "pessoas": número de pessoas,
  "lacre": "número do lacre",
  "resp": "nomes das assinaturas por extenso, separados por vírgula"
}
Regras:
- Traços (—) ou campos vazios = null.
- Números no padrão brasileiro: "3.170,90" vira 3170.90.
- Nas linhas de notas, use a coluna QUANTIDADE (não a soma).
- Se não conseguir ler um campo com segurança, use null.`;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const { image } = await req.json();
    if (!image) throw new Error("imagem não enviada");
    const base64 = image.includes(",") ? image.split(",")[1] : image;

    const key = Deno.env.get("GEMINI_API_KEY");
    if (!key) throw new Error("GEMINI_API_KEY não configurada");

    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${key}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: PROMPT },
              { inline_data: { mime_type: "image/jpeg", data: base64 } },
            ],
          }],
          generationConfig: { response_mime_type: "application/json", temperature: 0 },
        }),
      },
    );

    const j = await r.json();
    // Se o Gemini retornou erro (chave inválida, modelo indisponível etc.), avisa o app
    if (j?.error) throw new Error(`Gemini: ${j.error.message || JSON.stringify(j.error)}`);
    const text = j?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) throw new Error("Gemini não retornou leitura: " + JSON.stringify(j).slice(0, 300));
    return new Response(text, {
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ erro: String(e) }), {
      status: 200,
      headers: { ...CORS, "Content-Type": "application/json" },
    });
  }
});
