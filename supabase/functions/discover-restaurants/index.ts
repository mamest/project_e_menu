// discover-restaurants � Google Places-backed restaurant discovery.
//
// Two modes (via `action` in the request body):
//   "search"  (default) � Bulk Text Search for a postal code, upserts results.
//   "enrich"  � Reads OSM candidates with missing data for a postal code and
//               fills in google_place_id, rating, phone, website, city, street
//               by searching Google Places per candidate.
//
// Required secrets: GOOGLE_PLACES_API_KEY, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_URL

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const PLACES_BASE = "https://places.googleapis.com/v1"
const MAX_RESULTS_HARD_CAP = 60

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

function _json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

function _err(message: string, status = 400): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

interface PlaceResult {
  id: string
  displayName?: { text: string }
  formattedAddress?: string
  nationalPhoneNumber?: string
  websiteUri?: string
  rating?: number
  userRatingCount?: number
  regularOpeningHours?: Record<string, unknown>
  types?: string[]
  priceLevel?: string
  location?: { latitude: number; longitude: number }
}

interface PlacesSearchResponse {
  places?: PlaceResult[]
  nextPageToken?: string
}

const COUNTRY_META: Record<string, { name: string; south: number; west: number; north: number; east: number }> = {
  DE: { name: "Germany",        south: 47.27, west:  5.87, north: 55.06, east: 15.04 },
  AT: { name: "Austria",        south: 46.37, west:  9.53, north: 49.02, east: 17.16 },
  CH: { name: "Switzerland",    south: 45.82, west:  5.96, north: 47.81, east: 10.49 },
  FR: { name: "France",         south: 41.33, west: -5.14, north: 51.09, east:  9.56 },
  NL: { name: "Netherlands",    south: 50.75, west:  3.36, north: 53.56, east:  7.23 },
  IT: { name: "Italy",          south: 35.49, west:  6.62, north: 47.09, east: 18.52 },
  ES: { name: "Spain",          south: 27.64, west: -18.16, north: 43.79, east:  4.33 },
  PL: { name: "Poland",         south: 49.00, west: 14.12, north: 54.84, east: 24.15 },
  US: { name: "United States",  south: 24.52, west: -124.77, north: 49.38, east: -66.95 },
  GB: { name: "United Kingdom", south: 49.90, west: -8.62, north: 60.84, east:  1.77 },
}

const FIELD_MASK_FULL = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.nationalPhoneNumber",
  "places.websiteUri",
  "places.rating",
  "places.userRatingCount",
  "places.regularOpeningHours",
  "places.types",
  "places.priceLevel",
  "places.location",
].join(",")

function parseGoogleAddress(formatted: string | undefined, postalCode: string): { street: string | null; city: string | null } {
  if (!formatted) return { street: null, city: null }
  const parts = formatted.split(",").map((s) => s.trim())
  const street = parts[0] ?? null
  const pcPart = parts.find((p) => p.includes(postalCode))
  const city = pcPart ? pcPart.replace(postalCode, "").trim() || null : null
  return { street, city }
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  try {
    return await _handle(req)
  } catch (e) {
    const msg = e instanceof Error ? `${e.message}\n${e.stack ?? ""}` : String(e)
    return _err(`Unhandled exception: ${msg}`, 500)
  }
})

async function _handle(req: Request): Promise<Response> {
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
  if (!serviceRoleKey) return _err("SUPABASE_SERVICE_ROLE_KEY is not configured", 500)
  const apiKey = Deno.env.get("GOOGLE_PLACES_API_KEY")
  if (!apiKey) return _err("GOOGLE_PLACES_API_KEY secret is not set", 500)
  const supabaseUrl = Deno.env.get("SUPABASE_URL")
  if (!supabaseUrl) return _err("SUPABASE_URL is not set", 500)

  let body: { action?: string; postalCode?: string; country?: string; maxResults?: number }
  try {
    const raw = await req.text()
    body = raw ? JSON.parse(raw) : {}
  } catch {
    return _err("Invalid JSON body", 400)
  }

  const postalCode = (body.postalCode ?? "").trim()
  if (!postalCode) return _err("postalCode is required", 400)

  const action = (body.action ?? "search").trim()
  const country = (body.country ?? "DE").trim().toUpperCase()

  const supabase = createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } })

  // -- ENRICH: fill missing data on OSM candidates via Google Places ---------
  if (action === "enrich") {
    const { data: candidates, error: fetchError } = await supabase
      .from("restaurant_candidates")
      .select("id, name, street, city, postal_code, google_place_id, phone, website, rating")
      .eq("postal_code", postalCode)
      .is("google_place_id", null)

    if (fetchError) return _err(`DB fetch failed: ${fetchError.message}`, 500)
    if (!candidates || candidates.length === 0) {
      return _json({ postalCode, action: "enrich", enriched: 0, message: "No candidates need enrichment." })
    }

    let enriched = 0
    let skipped = 0

    for (const candidate of candidates) {
      try {
        // Always anchor on name + postal code from OSM; add street for precision when available.
        const candidatePostalCode = candidate.postal_code ?? postalCode
        const query = candidate.street
          ? `${candidate.name} ${candidate.street} ${candidatePostalCode}`
          : `${candidate.name} ${candidatePostalCode}`

        const meta = COUNTRY_META[country]
        const requestBody: Record<string, unknown> = { textQuery: query, pageSize: 1, regionCode: country.toLowerCase() }
        if (meta) {
          requestBody.locationRestriction = {
            rectangle: {
              low:  { latitude: meta.south, longitude: meta.west },
              high: { latitude: meta.north, longitude: meta.east },
            },
          }
        }

        const res = await fetch(`${PLACES_BASE}/places:searchText`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask": FIELD_MASK_FULL,
          },
          body: JSON.stringify(requestBody),
        })

        if (!res.ok) { skipped++; continue }
        const data = JSON.parse(await res.text()) as PlacesSearchResponse
        const p = (data.places ?? [])[0]
        if (!p) { skipped++; continue }

        // Sanity check: result must mention the candidate's postal code
        if (!(p.formattedAddress ?? "").includes(candidatePostalCode)) { skipped++; continue }

        const { street, city } = parseGoogleAddress(p.formattedAddress, candidatePostalCode)
        const update: Record<string, unknown> = {
          google_place_id: p.id,
          google_data: p,
          address: p.formattedAddress ?? null,
        }
        if (!candidate.phone && p.nationalPhoneNumber)  update.phone = p.nationalPhoneNumber
        if (!candidate.website && p.websiteUri)         update.website = p.websiteUri
        if (!candidate.rating && p.rating)              update.rating = p.rating
        if (street)                                     update.street = street
        if (city)                                       update.city = city
        if (p.location?.latitude)                       update.latitude = p.location.latitude
        if (p.location?.longitude)                      update.longitude = p.location.longitude
        if (p.userRatingCount)                          update.user_rating_count = p.userRatingCount
        if (p.regularOpeningHours)                      update.opening_hours = p.regularOpeningHours
        if (p.types)                                    update.types = p.types
        if (p.priceLevel)                               update.price_level = p.priceLevel

        await supabase.from("restaurant_candidates").update(update).eq("id", candidate.id)
        enriched++
      } catch {
        skipped++
      }
    }

    return _json({ postalCode, action: "enrich", total: candidates.length, enriched, skipped })
  }

  // -- SEARCH: bulk Google Places Text Search ? upsert -----------------------
  const maxResults = Math.min(body.maxResults ?? MAX_RESULTS_HARD_CAP, MAX_RESULTS_HARD_CAP)
  const meta = COUNTRY_META[country]
  const countryName = meta?.name ?? country
  const allPlaces: PlaceResult[] = []
  let pageToken: string | undefined = undefined

  do {
    const requestBody: Record<string, unknown> = {
      textQuery: `restaurants in ${postalCode} ${countryName}`,
      pageSize: 20,
      regionCode: country.toLowerCase(),
    }
    if (meta) {
      requestBody.locationRestriction = {
        rectangle: {
          low:  { latitude: meta.south, longitude: meta.west },
          high: { latitude: meta.north, longitude: meta.east },
        },
      }
    }
    if (pageToken) requestBody.pageToken = pageToken

    const res = await fetch(`${PLACES_BASE}/places:searchText`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": FIELD_MASK_FULL,
      },
      body: JSON.stringify(requestBody),
    })

    const resText = await res.text()
    if (!res.ok) return _err(`Google Places API error ${res.status}: ${resText}`, 502)
    const data = JSON.parse(resText) as PlacesSearchResponse
    allPlaces.push(...(data.places ?? []))
    pageToken = data.nextPageToken
  } while (pageToken && allPlaces.length < maxResults)

  const places = allPlaces
    .filter((p) => (p.formattedAddress ?? "").includes(postalCode))
    .slice(0, maxResults)

  if (places.length === 0) {
    return _json({ action: "search", total: 0, postalCode, message: "No places found for this postal code." })
  }

  const candidates = places.map((p) => {
    const { street, city } = parseGoogleAddress(p.formattedAddress, postalCode)
    return {
      google_place_id: p.id,
      source: "google",
      name: p.displayName?.text ?? p.id,
      address: p.formattedAddress ?? null,
      street,
      city,
      country_code: country,
      phone: p.nationalPhoneNumber ?? null,
      website: p.websiteUri ?? null,
      rating: p.rating ?? null,
      user_rating_count: p.userRatingCount ?? null,
      opening_hours: p.regularOpeningHours ?? null,
      types: p.types ?? null,
      price_level: p.priceLevel ?? null,
      latitude: p.location?.latitude ?? null,
      longitude: p.location?.longitude ?? null,
      postal_code: postalCode,
      google_data: p as unknown as Record<string, unknown>,
    }
  })

  const { error: upsertError, count } = await supabase
    .from("restaurant_candidates")
    .upsert(candidates, { onConflict: "google_place_id", count: "exact" })

  if (upsertError) return _err(`Database upsert failed: ${upsertError.message}`, 500)

  return _json({ action: "search", postalCode, country, total: candidates.length, upserted: count ?? candidates.length })
}
