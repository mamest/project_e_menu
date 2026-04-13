// Background translation worker for restaurant menu items.
// Called fire-and-forget after a menu is saved; translates all categories and
// items for the given restaurant into all languages listed in supported_languages
// (always including English) and writes the results back to the database using
// the service-role key (bypasses RLS).
//
// The native text in items.name / items.description is the ground truth.
// Translations are stored as JSONB on the row; the native text is NOT altered.
export {}

declare const Deno: {
  env: { get(key: string): string | undefined }
  serve(handler: (req: Request) => Response | Promise<Response>): void
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

interface TranslationEntry {
  id: string
  name: string
  description?: string
}

interface LocaleTranslation {
  name: string
  description?: string
}

interface TranslationResult {
  id: string
  [locale: string]: LocaleTranslation | string | undefined
}

type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue }

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const anthropicApiKey = Deno.env.get('ANTHROPIC_API_KEY')

    if (!supabaseUrl || !serviceRoleKey || !anthropicApiKey) {
      throw new Error('Missing required environment variables')
    }

    const body = (await req.json()) as { restaurantId?: number }
    const restaurantId = body.restaurantId

    if (!restaurantId) {
      return new Response(
        JSON.stringify({ error: 'restaurantId is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    // Use service-role key to bypass RLS for reads and writes
    const { createClient } = await import('@supabase/supabase-js')
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // Load all supported languages — English is always the required baseline
    const { data: langRows, error: langError } = await supabase
      .from('supported_languages')
      .select('code')
    if (langError) throw langError
    const languages: string[] = (
      (langRows ?? []) as Array<{ code: string }>
    ).map((l) => l.code)
    // Guarantee English is always present even if missing from the table
    if (!languages.includes('en')) languages.unshift('en')

    // Load all categories for this restaurant
    const { data: categories, error: catError } = await supabase
      .from('categories')
      .select('id, name')
      .eq('restaurant_id', restaurantId)

    if (catError) throw catError
    if (!categories || categories.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, translated: 0 }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    const categoryIds = (
      categories as Array<{ id: number; name: string }>
    ).map((c) => c.id)

    // Load all items for those categories
    const { data: items, error: itemError } = await supabase
      .from('items')
      .select('id, name, description, category_id')
      .in('category_id', categoryIds)

    if (itemError) throw itemError

    const safeItems = (
      items ?? []
    ) as Array<{
      id: number
      name: string
      description: string | null
      category_id: number
    }>

    // Build a flat batch of entries to translate
    const entries: TranslationEntry[] = []

    for (const cat of categories as Array<{ id: number; name: string }>) {
      entries.push({ id: `cat_${cat.id}`, name: cat.name })
    }
    for (const item of safeItems) {
      const entry: TranslationEntry = {
        id: `item_${item.id}`,
        name: item.name,
      }
      if (item.description) entry.description = item.description
      entries.push(entry)
    }

    // Translate via Anthropic.
    // English is mandatory as the common ground regardless of source language.
    // Languages come from the supported_languages table.
    const langList = languages.join(', ')
    const exampleObj = Object.fromEntries(
      languages.map((l) => [l, { name: '...', description: '...' }]),
    )
    const prompt =
      `Translate these restaurant menu texts into the following languages: ${langList}.\n` +
      `Return ONLY a JSON array with exactly one object per input item.\n` +
      `Each output object must have: "id" (same as input) and one key per language code.\n` +
      `Each locale object must have "name" and optionally "description".\n` +
      `If the source text is already in a target language, copy it verbatim for that language.\n` +
      `IMPORTANT: "en" (English) must always be present — it is the required common ground.\n\n` +
      `Input:\n${JSON.stringify(entries)}\n\n` +
      `Output format example (for one item):\n` +
      `[{"id":"item_42",${JSON.stringify(exampleObj).slice(1, -1)}}]`

    const anthropicResponse = await fetch(
      'https://api.anthropic.com/v1/messages',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': anthropicApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-sonnet-4-5',
          max_tokens: 16384,
          messages: [
            {
              role: 'user',
              content: [{ type: 'text', text: prompt }],
            },
          ],
        }),
      },
    )

    if (!anthropicResponse.ok) {
      const errBody = (await anthropicResponse.json()) as JsonValue
      throw new Error(
        `Anthropic error ${anthropicResponse.status}: ${JSON.stringify(errBody)}`,
      )
    }

    const anthropicData = (await anthropicResponse.json()) as {
      content: Array<{ type: string; text: string }>
    }

    let rawText = anthropicData.content?.[0]?.text ?? ''
    // Strip markdown fences that the model may add
    rawText = rawText
      .replace(/^```(?:json)?\s*/i, '')
      .replace(/\s*```$/i, '')
      .trim()

    const results: TranslationResult[] = JSON.parse(rawText)
    const byId = new Map(results.map((r) => [r.id, r]))

    // Persist translations back to the database.
    // The native name/description columns are untouched — they are the ground truth.
    let translated = 0

    for (const cat of categories as Array<{ id: number; name: string }>) {
      const result = byId.get(`cat_${cat.id}`)
      if (!result) continue
      // English is mandatory — skip this row if the model didn't return it
      if (!result['en']) continue

      const translations: Record<string, unknown> = {
        _source: { name: cat.name },
      }
      for (const lang of languages) {
        if (result[lang]) translations[lang] = result[lang]
      }

      await supabase
        .from('categories')
        .update({ translations })
        .eq('id', cat.id)

      translated++
    }

    for (const item of safeItems) {
      const result = byId.get(`item_${item.id}`)
      if (!result) continue
      // English is mandatory — skip this row if the model didn't return it
      if (!result['en']) continue

      const translations: Record<string, unknown> = {
        _source: {
          name: item.name,
          ...(item.description ? { desc: item.description } : {}),
        },
      }
      for (const lang of languages) {
        if (result[lang]) translations[lang] = result[lang]
      }

      await supabase
        .from('items')
        .update({ translations })
        .eq('id', item.id)

      translated++
    }

    return new Response(
      JSON.stringify({ ok: true, translated }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('translate-menu error:', message)
    return new Response(
      JSON.stringify({ error: message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})
