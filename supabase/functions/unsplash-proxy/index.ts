// Make this file a module so its declarations don't clash with other edge functions.
export {}

declare const Deno: {
  env: { get(key: string): string | undefined }
  serve(handler: (req: Request) => Response | Promise<Response>): void
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const unsplashApiKey = Deno.env.get('UNSPLASH_ACCESS_KEY')
    if (!unsplashApiKey) {
      return new Response(JSON.stringify({ error: 'Unsplash API key not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const url = new URL(req.url)
    const action = url.searchParams.get('action') ?? 'random'
    const query = url.searchParams.get('query') ?? 'food restaurant'
    const count = url.searchParams.get('count') ?? '12'

    let unsplashUrl: string

    if (action === 'search') {
      const encodedQuery = encodeURIComponent(query)
      unsplashUrl = `https://api.unsplash.com/search/photos?query=${encodedQuery}&per_page=${count}&orientation=landscape`
    } else {
      // random
      const encodedQuery = encodeURIComponent(query)
      unsplashUrl = `https://api.unsplash.com/photos/random?query=${encodedQuery}&orientation=landscape`
    }

    const response = await fetch(unsplashUrl, {
      headers: {
        Authorization: `Client-ID ${unsplashApiKey}`,
      },
    })

    const data = await response.json()

    if (!response.ok) {
      return new Response(JSON.stringify(data), {
        status: response.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error: unknown) {
    const message = error instanceof Error ? error.message : String(error)
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
