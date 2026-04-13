// Backfills a single new language into all existing categories and items that
// don't yet have a translation for it.
//
// The native text in items.name / items.description is the ground truth used
// as the translation source. Call this after inserting a new row into
// supported_languages.
//
// Request body: { "languageCode": "fr" }
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

// How many items to send to Anthropic in a single call (to stay within token limits)
const BATCH_SIZE = 100

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

    const body = (await req.json()) as { languageCode?: string }
    const languageCode = body.languageCode?.trim().toLowerCase()

    if (!languageCode) {
      return new Response(
        JSON.stringify({ error: 'languageCode is required' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    const { createClient } = await import('@supabase/supabase-js')
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    // Verify the language is registered in supported_languages
    const { data: langRow, error: langError } = await supabase
      .from('supported_languages')
      .select('code, name')
      .eq('code', languageCode)
      .maybeSingle()

    if (langError) throw langError
    if (!langRow) {
      return new Response(
        JSON.stringify({
          error: `Language "${languageCode}" is not in supported_languages. Add it first.`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        },
      )
    }

    // ── Gather categories missing the new language ──────────────────────────
    const { data: allCategories, error: catErr } = await supabase
      .from('categories')
      .select('id, name, translations')

    if (catErr) throw catErr

    const categoriesToTranslate = (
      (allCategories ?? []) as Array<{
        id: number
        name: string
        translations: Record<string, unknown> | null
      }>
    ).filter((c) => {
      const t = c.translations ?? {}
      return !t[languageCode]
    })

    // ── Gather items missing the new language ───────────────────────────────
    const { data: allItems, error: itemErr } = await supabase
      .from('items')
      .select('id, name, description, translations')

    if (itemErr) throw itemErr

    const itemsToTranslate = (
      (allItems ?? []) as Array<{
        id: number
        name: string
        description: string | null
        translations: Record<string, unknown> | null
      }>
    ).filter((i) => {
      const t = i.translations ?? {}
      return !t[languageCode]
    })

    if (categoriesToTranslate.length === 0 && itemsToTranslate.length === 0) {
      return new Response(
        JSON.stringify({ ok: true, translated: 0, message: 'Nothing to backfill' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      )
    }

    // Build flat entry list
    const allEntries: TranslationEntry[] = []
    for (const cat of categoriesToTranslate) {
      allEntries.push({ id: `cat_${cat.id}`, name: cat.name })
    }
    for (const item of itemsToTranslate) {
      const entry: TranslationEntry = { id: `item_${item.id}`, name: item.name }
      if (item.description) entry.description = item.description
      allEntries.push(entry)
    }

    // ── Translate in batches ────────────────────────────────────────────────
    const allResults: TranslationResult[] = []
    for (let i = 0; i < allEntries.length; i += BATCH_SIZE) {
      const batch = allEntries.slice(i, i + BATCH_SIZE)

      const prompt =
        `Translate these restaurant menu texts to ${langRow.name} (${languageCode}).\n` +
        `The source texts may be in any language — the native language is the ground truth.\n` +
        `Return ONLY a JSON array with exactly one object per input item.\n` +
        `Each output object must have: "id" (same as input) and "${languageCode}".\n` +
        `Each locale object must have "name" and optionally "description".\n\n` +
        `Input:\n${JSON.stringify(batch)}\n\n` +
        `Output format example:\n` +
        `[{"id":"cat_1","${languageCode}":{"name":"..."}},` +
        `{"id":"item_42","${languageCode}":{"name":"...","description":"..."}}]`

      const anthropicResp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': anthropicApiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-sonnet-4-5',
          max_tokens: 16384,
          messages: [{ role: 'user', content: [{ type: 'text', text: prompt }] }],
        }),
      })

      if (!anthropicResp.ok) {
        const errBody = (await anthropicResp.json()) as JsonValue
        throw new Error(
          `Anthropic error ${anthropicResp.status}: ${JSON.stringify(errBody)}`,
        )
      }

      const anthropicData = (await anthropicResp.json()) as {
        content: Array<{ type: string; text: string }>
      }

      let rawText = anthropicData.content?.[0]?.text ?? ''
      rawText = rawText
        .replace(/^```(?:json)?\s*/i, '')
        .replace(/\s*```$/i, '')
        .trim()

      const batchResults: TranslationResult[] = JSON.parse(rawText)
      allResults.push(...batchResults)
    }

    const byId = new Map(allResults.map((r) => [r.id, r]))

    // ── Persist the new language into existing translations JSONB ───────────
    // Only the new language key is added; all existing keys are preserved.
    let translated = 0

    for (const cat of categoriesToTranslate) {
      const result = byId.get(`cat_${cat.id}`)
      if (!result?.[languageCode]) continue

      const existing = cat.translations ?? {}
      const updated = { ...existing, [languageCode]: result[languageCode] }

      await supabase
        .from('categories')
        .update({ translations: updated })
        .eq('id', cat.id)

      translated++
    }

    for (const item of itemsToTranslate) {
      const result = byId.get(`item_${item.id}`)
      if (!result?.[languageCode]) continue

      const existing = item.translations ?? {}
      const updated = { ...existing, [languageCode]: result[languageCode] }

      await supabase
        .from('items')
        .update({ translations: updated })
        .eq('id', item.id)

      translated++
    }

    return new Response(
      JSON.stringify({ ok: true, translated }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    )
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('backfill-language error:', message)
    return new Response(
      JSON.stringify({ error: message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    )
  }
})
