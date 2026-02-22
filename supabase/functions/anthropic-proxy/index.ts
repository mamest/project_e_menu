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

interface ImageInput {
  base64: string
  mediaType: string
}

interface RequestBody {
  pdfBase64?: string
  images?: ImageInput[]
  prompt?: string
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

interface AnthropicContentImage {
  type: 'image'
  source: {
    type: 'base64'
    media_type: string
    data: string
  }
}

type AnthropicContent = AnthropicContentText | AnthropicContentDocument | AnthropicContentImage

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

const DEFAULT_PROMPT = 'Analyze this restaurant menu PDF and extract all information into a structured JSON format.\n\n' +
  'CRITICAL: Return ONLY valid JSON. No markdown, no code blocks, no explanations. Start with { and end with }.\n\n' +
  'Use this EXACT structure:\n' +
  '{\n' +
  '  "restaurant": {\n' +
  '    "name": "Restaurant Name",\n' +
  '    "address": "Full Address",\n' +
  '    "phone": "+49 123 456789",\n' +
  '    "email": "email@example.com",\n' +
  '    "description": "Brief description",\n' +
  '    "cuisine_type": "Italian",\n' +
  '    "delivers": true,\n' +
  '    "opening_hours": {"monday": "11:00-22:00"},\n' +
  '    "payment_methods": ["Cash", "Card"]\n' +
  '  },\n' +
  '  "categories": [\n' +
  '    {\n' +
  '      "name": "Category Name",\n' +
  '      "display_order": 0,\n' +
  '      "items": [\n' +
  '        {\n' +
  '          "name": "Item Name",\n' +
  '          "item_number": "1",\n' +
  '          "price": 9.99,\n' +
  '          "description": "Description",\n' +
  '          "has_variants": false\n' +
  '        },\n' +
  '        {\n' +
  '          "name": "Item with number",\n' +
  '          "item_number": "2a",\n' +
  '          "price": 12.50,\n' +
  '          "description": "Description",\n' +
  '          "has_variants": false\n' +
  '        },\n' +
  '        {\n' +
  '          "name": "Item with variants",\n' +
  '          "item_number": "3",\n' +
  '          "description": "Description",\n' +
  '          "has_variants": true,\n' +
  '          "variants": [\n' +
  '            {"name": "Small", "price": 7.50, "display_order": 0},\n' +
  '            {"name": "Large", "price": 9.50, "display_order": 1}\n' +
  '          ]\n' +
  '        }\n' +
  '      ]\n' +
  '    }\n' +
  '  ]\n' +
  '}\n\n' +
  'Rules:\n' +
  '- IMPORTANT: If menu items have numbers (like "1", "2", "3a", "12b"), extract them as "item_number"\n' +
  '- Look for numbered lists or item identifiers anywhere on the menu\n' +
  '- Item numbers can be numeric ("1", "10") or alphanumeric ("1a", "2b", "3c")\n' +
  '- All prices as numbers (9.99 not "9,99 €")\n' +
  '- If item has variants, omit "price" field and set "has_variants": true\n' +
  '- If item has no variants, include "price" and set "has_variants": false\n' +
  '- Omit fields if not found (except required ones)\n' +
  '- Return ONLY the JSON object, nothing else'

Deno.serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body = (await req.json()) as RequestBody
    const pdfBase64 = body.pdfBase64
    const images = body.images

    if (!pdfBase64 && (!images || images.length === 0)) {
      return new Response(
        JSON.stringify({ error: 'pdfBase64 or images array is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    const anthropicApiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicApiKey) {
      throw new Error('ANTHROPIC_API_KEY not set')
    }

    // Use custom prompt if provided, otherwise use default
    const promptText = body.prompt || DEFAULT_PROMPT

    // Build content blocks depending on file type
    const isPdf = !!pdfBase64
    const fileContentBlocks: AnthropicContent[] = isPdf
      ? [
          {
            type: 'document',
            source: {
              type: 'base64',
              media_type: 'application/pdf',
              data: pdfBase64!
            }
          } as AnthropicContentDocument
        ]
      : (images ?? []).map(
          (img): AnthropicContentImage => ({
            type: 'image',
            source: {
              type: 'base64',
              media_type: img.mediaType || 'image/jpeg',
              data: img.base64
            }
          })
        )

    // Call Anthropic API
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicApiKey,
        'anthropic-version': '2023-06-01',
        ...(isPdf ? { 'anthropic-beta': 'pdfs-2024-09-25' } : {})
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 16384,
        messages: [{
          role: 'user',
          content: [
            {
              type: 'text',
              text: promptText
            },
            ...fileContentBlocks
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
