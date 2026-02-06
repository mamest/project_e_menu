declare const Deno: {
  env: {
    get(key: string): string | undefined
  }
  serve(handler: (req: Request) => Response | Promise<Response>): void
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

interface RequestBody {
  pdfBase64?: string
}

interface AnthropicContentText {
  type: 'text'
  text: string
}

interface AnthropicContentDocument {
  type: 'document'
  source: {
    type: 'base64'
    media_type: 'application/pdf'
    data: string
  }
}

type AnthropicContent = AnthropicContentText | AnthropicContentDocument

interface AnthropicMessage {
  role: 'user'
  content: AnthropicContent[]
}

interface AnthropicRequestBody {
  model: string
  max_tokens: number
  messages: AnthropicMessage[]
}

type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue }

Deno.serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = (await req.json()) as RequestBody
    const pdfBase64 = body.pdfBase64
    if (!pdfBase64) {
      return new Response(
        JSON.stringify({ error: 'pdfBase64 is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    const anthropicApiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicApiKey) {
      throw new Error('ANTHROPIC_API_KEY not set')
    }

    // Call Anthropic API
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicApiKey,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 4096,
        messages: [{
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Analyze this restaurant menu PDF and extract all information into a structured JSON format. ' +
                    'Respond with ONLY valid JSON in this exact structure:\n' +
                    '{\n' +
                    '  "restaurantName": "string",\n' +
                    '  "categories": [\n' +
                    '    {\n' +
                    '      "name": "string",\n' +
                    '      "items": [\n' +
                    '        {\n' +
                    '          "name": "string",\n' +
                    '          "description": "string (optional)",\n' +
                    '          "basePrice": number,\n' +
                    '          "variants": [\n' +
                    '            {\n' +
                    '              "name": "string",\n' +
                    '              "price": number\n' +
                    '            }\n' +
                    '          ]\n' +
                    '        }\n' +
                    '      ]\n' +
                    '    }\n' +
                    '  ]\n' +
                    '}\n' +
                    'Extract menu categories, items, prices, and variants. ' +
                    'If an item has no variants, use an empty array. ' +
                    'Do not include any explanatory text, only the JSON.'
            },
            {
              type: 'document',
              source: {
                type: 'base64',
                media_type: 'application/pdf',
                data: pdfBase64
              }
            }
          ]
        }]
      } as AnthropicRequestBody)
    })

    const data = (await response.json()) as JsonValue

    if (!response.ok) {
      return new Response(
        JSON.stringify(data),
        { status: response.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify(data),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error)
    return new Response(
      JSON.stringify({ error: message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})
