// Secure proxy for the Google Places API (New).
// Actions: search | fetch_and_cache | get_photo_uri
// Required secret: GOOGLE_PLACES_API_KEY
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const PLACES_BASE = 'https://places.googleapis.com/v1'

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const apiKey = Deno.env.get('GOOGLE_PLACES_API_KEY')
    if (!apiKey) return _err('GOOGLE_PLACES_API_KEY secret is not set', 500)

    const rawText = await req.text()
    if (!rawText || rawText.trim() === '') return _err('Request body is empty', 400)

    let body: { action: string; query?: string; placeId?: string; restaurantId?: number; photoName?: string }
    try {
      body = JSON.parse(rawText)
    } catch {
      return _err('Invalid JSON body', 400)
    }

    // ── search ────────────────────────────────────────────────────────────────
    if (body.action === 'search') {
      if (!body.query) return _err('query is required', 400)

      const res = await fetch(`${PLACES_BASE}/places:searchText`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.rating,places.userRatingCount',
        },
        body: JSON.stringify({ textQuery: body.query }),
      })

      const resText = await res.text()
      if (!res.ok) return _err(`Google Places search error ${res.status}: ${resText}`, 502)

      const data = JSON.parse(resText) as {
        places?: Array<{
          id: string
          displayName?: { text: string }
          formattedAddress?: string
          rating?: number
          userRatingCount?: number
        }>
      }

      const candidates = (data.places ?? []).slice(0, 5).map((p) => ({
        placeId: p.id,
        name: p.displayName?.text ?? '',
        address: p.formattedAddress ?? '',
        rating: p.rating,
        userRatingCount: p.userRatingCount,
      }))

      return _json({ candidates })
    }

    // ── fetch_and_cache ───────────────────────────────────────────────────────
    if (body.action === 'fetch_and_cache') {
      if (!body.placeId) return _err('placeId is required', 400)
      if (!body.restaurantId) return _err('restaurantId is required', 400)

      const fieldMask =
        'id,displayName,formattedAddress,rating,userRatingCount,reviews,photos,googleMapsUri'

      const detailRes = await fetch(`${PLACES_BASE}/places/${body.placeId}`, {
        headers: { 'X-Goog-Api-Key': apiKey, 'X-Goog-FieldMask': fieldMask },
      })

      const detailText = await detailRes.text()
      if (!detailRes.ok) return _err(`Google Places details error ${detailRes.status}: ${detailText}`, 502)

      const place = JSON.parse(detailText) as {
        rating?: number
        userRatingCount?: number
        googleMapsUri?: string
        photos?: Array<{ name: string }>
        reviews?: Array<{
          authorAttribution?: { displayName: string; photoUri?: string }
          rating?: number
          text?: { text: string }
          relativePublishTimeDescription?: string
        }>
      }

      const googleData = {
        rating: place.rating,
        user_rating_count: place.userRatingCount,
        google_maps_uri: place.googleMapsUri,
        photo_names: (place.photos ?? []).slice(0, 5).map((p) => p.name),
        reviews: (place.reviews ?? []).slice(0, 5).map((r) => ({
          author_name: r.authorAttribution?.displayName ?? 'Anonymous',
          author_photo_uri: r.authorAttribution?.photoUri,
          rating: r.rating ?? 0,
          text: r.text?.text ?? '',
          relative_publish_time_description: r.relativePublishTimeDescription ?? '',
        })),
        last_fetched: new Date().toISOString(),
      }

      const supabaseUrl = Deno.env.get('SUPABASE_URL')!
      const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

      // Extract user ID from the JWT payload (gateway already verified the signature)
      const authHeader = req.headers.get('Authorization')
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return _err('Authorization header required', 401)
      }
      let userId: string
      try {
        // JWT uses base64url encoding — convert to standard base64 before atob()
        const b64url = authHeader.slice(7).split('.')[1]
        const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/').padEnd(
          b64url.length + (4 - b64url.length % 4) % 4, '='
        )
        const jwtPayload = JSON.parse(atob(b64))
        userId = jwtPayload.sub
        if (!userId) throw new Error('no sub in JWT')
      } catch (e) {
        return _err('Invalid JWT: ' + (e instanceof Error ? e.message : String(e)), 401)
      }

      // Use service role client to verify ownership and write
      const adminClient = createClient(supabaseUrl, serviceRoleKey)

      const { data: restaurant, error: ownerError } = await adminClient
        .from('restaurants')
        .select('id')
        .eq('id', body.restaurantId)
        .eq('restaurant_owner_uuid', userId)
        .single()
      if (ownerError || !restaurant) return _err('Restaurant not found or not owned by you', 403)

      const { error: dbError } = await adminClient
        .from('restaurants')
        .update({ google_place_id: body.placeId, google_data: googleData })
        .eq('id', body.restaurantId)

      if (dbError) return _err(dbError.message, 500)

      return _json({ ok: true, googleData })
    }

    // ── get_photo_uri ─────────────────────────────────────────────────────────
    if (body.action === 'get_photo_uri') {
      if (!body.photoName) return _err('photoName is required', 400)

      const photoRes = await fetch(
        `${PLACES_BASE}/${body.photoName}/media?maxWidthPx=800&skipHttpRedirect=true`,
        { headers: { 'X-Goog-Api-Key': apiKey } },
      )

      const photoText = await photoRes.text()
      if (!photoRes.ok) return _err(`Google Places photo error ${photoRes.status}: ${photoText}`, 502)

      const photoData = JSON.parse(photoText) as { photoUri?: string }
      return _json({ photoUri: photoData.photoUri ?? null })
    }

    return _err(`Unknown action: ${body.action}`, 400)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    console.error('[google-places-proxy] unhandled error:', message)
    return _err(message, 500)
  }
})

function _json(data: unknown): Response {
  return new Response(JSON.stringify(data), {
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

function _err(message: string, status: number): Response {
  console.error(`[google-places-proxy] ${status}:`, message)
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
