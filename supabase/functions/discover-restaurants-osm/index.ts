// discover-restaurants-osm — Uses OpenStreetMap Overpass API for exhaustive
// restaurant discovery by postal code. Completely free, no API key required.
// Returns every named food-service amenity within the exact postal code boundary —
// far more complete than Google Places Text Search for small German postal codes.
//
// Required secrets: SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL
// Auth: open (no user auth required — table is service-role only on DB level)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const OVERPASS_MIRRORS = [
  'https://overpass-api.de/api/interpreter',
  'https://lz4.overpass-api.de/api/interpreter',
  'https://z.overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.private.coffee/api/interpreter',
]

// Overpass API requires a descriptive User-Agent; without it many instances reject requests.
const OVERPASS_USER_AGENT = 'e-menu-discovery-bot/1.0 (restaurant candidate research tool)'

// Bounding boxes per country — used as a global [bbox:] in Overpass queries so that
// identical postal codes in neighbouring countries never bleed through.
const COUNTRY_BBOX: Record<string, { south: number; west: number; north: number; east: number }> = {
  DE: { south: 47.27, west:  5.87, north: 55.06, east: 15.04 },
  AT: { south: 46.37, west:  9.53, north: 49.02, east: 17.16 },
  CH: { south: 45.82, west:  5.96, north: 47.81, east: 10.49 },
  FR: { south: 41.33, west: -5.14, north: 51.09, east:  9.56 },
  NL: { south: 50.75, west:  3.36, north: 53.56, east:  7.23 },
  IT: { south: 35.49, west:  6.62, north: 47.09, east: 18.52 },
  ES: { south: 27.64, west:-18.16, north: 43.79, east:  4.33 },
  PL: { south: 49.00, west: 14.12, north: 54.84, east: 24.15 },
  US: { south: 24.52, west:-124.77, north: 49.38, east:-66.95 },
  GB: { south: 49.90, west: -8.62, north: 60.84, east:  1.77 },
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// ── helpers ──────────────────────────────────────────────────────────────────

function _json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function _err(message: string, status = 400): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

// ── OSM tag helpers ───────────────────────────────────────────────────────────

interface StructuredAddress {
  street: string | null   // "Musterstraße 12"
  city: string | null     // "Büren"
  address: string | null  // full formatted string for display
}

function parseAddress(tags: Record<string, string>, postalCode: string): StructuredAddress {
  let street: string | null = null
  if (tags['addr:street']) {
    street = tags['addr:street']
    if (tags['addr:housenumber']) street += ' ' + tags['addr:housenumber']
  }

  const city: string | null =
    tags['addr:city'] ?? tags['addr:town'] ?? tags['addr:suburb'] ?? null

  const postcode = tags['addr:postcode'] ?? postalCode
  const parts: string[] = []
  if (street) parts.push(street)
  if (postcode || city) parts.push([postcode, city].filter(Boolean).join(' '))

  return {
    street,
    city,
    address: parts.length > 0 ? parts.join(', ') : null,
  }
}

function parseTypes(tags: Record<string, string>): string[] {
  const types: string[] = []
  if (tags['amenity']) types.push(tags['amenity'])
  if (tags['cuisine']) {
    // OSM cuisine can be semicolon-separated: "italian;pizza"
    tags['cuisine'].split(';').forEach((c) => {
      const t = c.trim()
      if (t) types.push(t)
    })
  }
  return types.length > 0 ? types : []
}

// ── types ─────────────────────────────────────────────────────────────────────

interface OsmElement {
  type: 'node' | 'way' | 'relation'
  id: number
  lat?: number
  lon?: number
  center?: { lat: number; lon: number }
  tags?: Record<string, string>
}

// ── main handler ──────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  try {
    return await _handle(req)
  } catch (e) {
    const msg = e instanceof Error ? `${e.message}\n${e.stack ?? ''}` : String(e)
    return _err(`Unhandled exception: ${msg}`, 500)
  }
})

async function _handle(req: Request): Promise<Response> {

  // ── validate secrets ──────────────────────────────────────────────────────
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!serviceRoleKey) return _err('SUPABASE_SERVICE_ROLE_KEY is not configured', 500)

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  if (!supabaseUrl) return _err('SUPABASE_URL is not set', 500)

  // ── parse request body ────────────────────────────────────────────────────
  let body: {
    postalCode?: string
    country?: string
    // Overpass amenity values to include. Defaults cover the most common
    // food-service types relevant for an e-menu app.
    amenities?: string[]
  }
  try {
    const raw = await req.text()
    body = raw ? JSON.parse(raw) : {}
  } catch {
    return _err('Invalid JSON body', 400)
  }

  const postalCode = (body.postalCode ?? '').trim()
  if (!postalCode) return _err('postalCode is required', 400)

  const countryCode = (body.country ?? 'DE').trim().toUpperCase()

  const amenities = body.amenities ?? [
    'restaurant',
    'fast_food',
    'cafe',
    'bar',
    'pub',
    'bistro',
    'food_court',
  ]
  const amenityRegex = amenities.join('|')

  // ── build Overpass QL query ───────────────────────────────────────────────
  // Uses the postal_code boundary area so results are geographically exact —
  // no bleed-over from neighbouring postal codes.
  // We pin the postal code area to the correct country using the ISO3166-1 relation
  // so that identical postal codes in different countries don't produce wrong results.
  const bbox = COUNTRY_BBOX[countryCode]
  // [bbox:south,west,north,east] is a global Overpass filter — every element in the
  // result set must lie within this rectangle.  This prevents French/Polish/etc.
  // restaurants from appearing when a postal code number happens to exist in two
  // countries (e.g. 59590 exists in both DE and FR).
  const bboxHeader = bbox
    ? `[bbox:${bbox.south},${bbox.west},${bbox.north},${bbox.east}]`
    : ''

  const query = [
    `[out:json][timeout:30]${bboxHeader};`,
    `area["ISO3166-1"="${countryCode}"]["admin_level"="2"]->.country;`,
    `area["postal_code"="${postalCode}"]["boundary"="postal_code"](area.country)->.a;`,
    `nwr["amenity"~"^(${amenityRegex})$"](area.a);`,
    'out center tags;',
  ].join('\n')

  // ── call Overpass API (GET, try mirrors in order) ─────────────────────────
  // Using GET avoids POST content-negotiation (406) issues on some mirrors.
  // [out:json] in the query string ensures JSON output regardless of Accept header.
  let overpassRes: Response | null = null
  const mirrorErrors: string[] = []
  for (const mirror of OVERPASS_MIRRORS) {
    try {
      const url = `${mirror}?data=${encodeURIComponent(query)}`
      const res = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'User-Agent': OVERPASS_USER_AGENT,
        },
      })
      if (res.status === 429 || res.status === 406) {
        mirrorErrors.push(`${mirror}: ${res.status}`)
        continue // try next mirror
      }
      if (res.ok) {
        overpassRes = res
        break
      }
      mirrorErrors.push(`${mirror}: ${res.status}`)
    } catch (e) {
      mirrorErrors.push(`${mirror}: ${e}`)
    }
  }
  if (!overpassRes) {
    return _err(`All Overpass mirrors failed: ${mirrorErrors.join(' | ')}`, 502)
  }

  let overpassData: { elements: OsmElement[] }
  try {
    const text = await overpassRes.text()
    console.log('[osm] overpass raw length:', text.length, 'starts:', text.slice(0, 40))
    // Guard against HTML/XML error pages returned with 200 status
    if (!text.trimStart().startsWith('{')) {
      return _err(`Overpass returned non-JSON response: ${text.slice(0, 300)}`, 502)
    }
    overpassData = JSON.parse(text) as { elements: OsmElement[] }
  } catch (e) {
    return _err(`Overpass response parse error: ${e}`, 502)
  }
  const elements = overpassData.elements ?? []
  console.log('[osm] elements count:', elements.length)

  // ── map OSM elements to candidate rows ───────────────────────────────────
  const candidates = elements
    .filter((e) => !!e.tags?.name) // skip unnamed amenities
    .map((e) => {
      const tags = e.tags as Record<string, string>
      const lat = e.lat ?? e.center?.lat ?? null
      const lon = e.lon ?? e.center?.lon ?? null
      const osmId = `${e.type}/${e.id}`
      const { street, city, address } = parseAddress(tags, postalCode)

      return {
        osm_id: osmId,
        google_place_id: null as string | null,
        source: 'osm',
        name: tags.name,
        address,
        street,
        city,
        country_code: countryCode,
        phone: tags.phone ?? tags['contact:phone'] ?? null,
        website: tags.website ?? tags['contact:website'] ?? null,
        rating: null as number | null,
        user_rating_count: null as number | null,
        // Store raw OSM opening_hours string so it isn't lost
        opening_hours: tags.opening_hours
          ? ({ raw: tags.opening_hours } as Record<string, unknown>)
          : null,
        types: parseTypes(tags),
        price_level: null as string | null,
        latitude: lat,
        longitude: lon,
        postal_code: postalCode,
        // Store all OSM tags in google_data column for now (re-used as generic raw data)
        google_data: tags as unknown as Record<string, unknown>,
      }
    })

  if (candidates.length === 0) {
    return _json({
      postalCode,
      total: 0,
      inserted: 0,
      updated: 0,
      source: 'osm',
      message: 'No named amenities found for this postal code in OpenStreetMap. '
        + 'The postal code boundary may not be tagged in OSM, or there are no matching amenities.',
    })
  }
  console.log('[osm] mapped candidates:', candidates.length)

  // ── upsert into restaurant_candidates via direct PostgREST call ──────────
  // We bypass the Supabase JS client here because supabase-js@2 has an issue
  // with upsert responses in some Deno edge function environments.
  const restUrl = `${supabaseUrl}/rest/v1/restaurant_candidates?on_conflict=osm_id`
  console.log('[osm] posting to:', restUrl)

  let pgRes: Response
  try {
    pgRes = await fetch(restUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'apikey': serviceRoleKey,
        'Authorization': `Bearer ${serviceRoleKey}`,
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      },
      body: JSON.stringify(candidates),
    })
  } catch (fetchErr) {
    const msg = fetchErr instanceof Error ? fetchErr.message : String(fetchErr)
    console.error('[osm] PostgREST fetch threw:', msg)
    return _err(`Database fetch threw: ${msg}`, 500)
  }

  if (!pgRes.ok) {
    const errText = await pgRes.text()
    console.error('[osm] PostgREST error', pgRes.status, errText)
    return _err(`Database upsert failed (${pgRes.status}): ${errText}`, 500)
  }
  console.log('[osm] upsert OK, status:', pgRes.status)

  return _json({
    postalCode,
    source: 'osm',
    total: candidates.length,
    upserted: candidates.length,
    amenitiesSearched: amenities,
  })
}
