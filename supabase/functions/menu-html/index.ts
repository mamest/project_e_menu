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
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
} as const

interface ItemVariant {
  name: string
  price: number
}

interface MenuItem {
  name: string
  item_number?: string
  price?: number
  description?: string
  has_variants?: boolean
  variants?: ItemVariant[]
}

interface Category {
  name: string
  items: MenuItem[]
}

interface RestaurantInfo {
  name: string
  address: string
  phone?: string
  email?: string
  description?: string
  cuisine_type?: string
  delivers?: boolean
  opening_hours?: Record<string, string>
  payment_methods?: string[]
  image_url?: string
}

interface RequestBody {
  restaurant: RestaurantInfo
  categories: Category[]
  restaurantId: number
  supabaseUrl: string
  supabaseAnonKey: string
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const anthropicApiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicApiKey) {
      return new Response(
        JSON.stringify({ error: 'Anthropic API key not configured' }),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    const body = (await req.json()) as RequestBody
    const { restaurant, categories, restaurantId, supabaseUrl, supabaseAnonKey } = body

    // Build a compact text representation of the menu — used ONLY as design context for Claude
    const menuText = categories
      .map((cat) => {
        const items = cat.items
          .map((item) => {
            let line = item.item_number ? `${item.item_number}. ${item.name}` : item.name
            if (item.has_variants && item.variants?.length) {
              const variantStr = item.variants
                .map((v) => `${v.name}: €${v.price.toFixed(2)}`)
                .join(', ')
              line += ` — ${variantStr}`
            } else if (item.price != null) {
              line += ` — €${item.price.toFixed(2)}`
            }
            if (item.description) line += `\n   ${item.description}`
            return line
          })
          .join('\n')
        return `### ${cat.name}\n${items}`
      })
      .join('\n\n')

    const openingHoursText = restaurant.opening_hours
      ? Object.entries(restaurant.opening_hours)
          .map(([day, hours]) => `${day}: ${hours}`)
          .join(', ')
      : ''

    const prompt = `You are a professional menu designer. Create a beautiful, print-ready HTML menu page for the following restaurant.

RESTAURANT INFO (for design context):
Name: ${restaurant.name}
Address: ${restaurant.address}
${restaurant.phone ? `Phone: ${restaurant.phone}` : ''}
${restaurant.email ? `Email: ${restaurant.email}` : ''}
${restaurant.description ? `Description: ${restaurant.description}` : ''}
${restaurant.cuisine_type ? `Cuisine: ${restaurant.cuisine_type}` : ''}
${restaurant.delivers ? 'Delivery available' : ''}
${openingHoursText ? `Opening hours: ${openingHoursText}` : ''}
${restaurant.payment_methods?.length ? `Payment: ${restaurant.payment_methods.join(', ')}` : ''}
${restaurant.image_url ? `Restaurant image: ${restaurant.image_url}` : ''}

SAMPLE MENU STRUCTURE (for design reference only — do NOT put this data directly in the HTML):
${menuText}

━━━ MANDATORY REQUIREMENTS — READ CAREFULLY ━━━

1. RETURN FORMAT
   Return ONLY a complete self-contained HTML document (<!DOCTYPE html>…</html>). No markdown, no code fences, no explanations.

2. DYNAMIC DATA LOADING (CRITICAL)
   The HTML must NOT contain any hard-coded menu items, prices, descriptions, or category names.
   All menu content must be loaded and rendered by JavaScript at page-load time from the Supabase REST API.

   Your <script> block MUST contain EXACTLY these constants and this load function structure
   (fill in the renderMenu function body with your own DOM-building code):

   const SUPABASE_URL = 'PLACEHOLDER';
   const SUPABASE_ANON_KEY = 'PLACEHOLDER';
   const RESTAURANT_ID = 0;
   const HEADERS = { 'apikey': SUPABASE_ANON_KEY, 'Authorization': 'Bearer ' + SUPABASE_ANON_KEY };

   async function loadMenu() {
     document.getElementById('loading').style.display = 'block';
     document.getElementById('content').style.display = 'none';
     try {
       const [restRes, catRes] = await Promise.all([
         fetch(SUPABASE_URL + '/rest/v1/restaurants?id=eq.' + RESTAURANT_ID + '&select=*', { headers: HEADERS }),
         fetch(SUPABASE_URL + '/rest/v1/categories?restaurant_id=eq.' + RESTAURANT_ID + '&select=id,name,display_order,items(id,name,item_number,price,description,available,has_variants,item_variants(id,name,price,display_order))&order=display_order', { headers: HEADERS })
       ]);
       const restaurant = (await restRes.json())[0];
       const categories = (await catRes.json());
       document.getElementById('loading').style.display = 'none';
       document.getElementById('content').style.display = 'block';
       renderMenu(restaurant, categories);
     } catch(e) {
       const el = document.getElementById('loading');
       if (el) el.textContent = 'Error loading menu. Please refresh the page.';
     }
   }

   function renderMenu(restaurant, categories) {
     // YOUR IMPLEMENTATION: build DOM inside #menu-header and #menu-categories
     // Rules:
     //  - Filter out items where item.available === false
     //  - For items where has_variants === true, show item_variants (each has .name and .price)
     //  - Sort items by display_order, then item_number if present
     //  - restaurant fields: name, address, phone, email, description, image_url,
     //      cuisine_type, delivers, opening_hours (object), payment_methods (array)
   }

   loadMenu();

3. REQUIRED HTML STRUCTURE (these IDs must exist):
   - An element with id="loading" — visible while fetching, hidden while data loaded, shows a styled spinner or "Loading menu…" text
   - An element with id="content" — hidden while loading, visible once data loaded; contains:
     - An element with id="menu-header" — populated by renderMenu with restaurant name, banner image, address, contact
     - An element with id="menu-categories" — populated by renderMenu with styled category sections and items

4. STYLING
   - Use only inline CSS and a single <style> tag (no external stylesheets, no Google Fonts — system fonts only e.g. Georgia, Arial)
   - Design a professional, elegant restaurant menu layout matching the cuisine type
   - Color palette: warm, appetising tones suited to the cuisine
   - Category headings: clear with colored accent bar or decorative separator
   - Item numbers (if present): styled subtly in small grey text before the item name
   - Prices: right-aligned or separated from item name using dot leaders; use the € symbol
   - Item descriptions: italics, smaller font beneath item name
   - Items with variants: list each variant name + price (e.g. Small €8.50 / Large €12.00)
   - If restaurant has an image_url, show it as a banner image in the header
   - @media print block: hides non-print elements, ensures clean page breaks between categories
   - Subtle footer with payment methods and delivery info if available
   - Layout works well when printed as A4`

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-opus-4-5',
        max_tokens: 8192,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    const data = (await response.json()) as {
      content?: Array<{ type: string; text: string }>
      error?: { message: string }
    }

    if (!response.ok) {
      return new Response(JSON.stringify(data), {
        status: response.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    let html =
      data.content?.find((b) => b.type === 'text')?.text ?? ''

    // Strip markdown code fences if Claude wrapped the output despite instructions
    // e.g. ```html ... ``` or ``` ... ```
    html = html.trim()
    if (html.startsWith('```')) {
      html = html.replace(/^```[a-z]*\n?/i, '').replace(/\n?```\s*$/, '').trim()
    }

    // Force-inject real credentials using regex — works regardless of what Claude wrote
    // (handles 'undefined', placeholder tokens, wrong values, etc.)
    const safeUrl = (supabaseUrl ?? '').replace(/'/g, "\\'")
    const safeKey = (supabaseAnonKey ?? '').replace(/'/g, "\\'")
    const safeId = String(restaurantId ?? '0')

    html = html
      .replace(/const\s+SUPABASE_URL\s*=\s*[^;]+;/, `const SUPABASE_URL = '${safeUrl}';`)
      .replace(/const\s+SUPABASE_ANON_KEY\s*=\s*[^;]+;/, `const SUPABASE_ANON_KEY = '${safeKey}';`)
      .replace(/const\s+RESTAURANT_ID\s*=\s*[^;]+;/, `const RESTAURANT_ID = ${safeId};`)

    // Safety net: if Claude omitted the constants entirely, insert them before the first <script>
    if (!html.includes('const SUPABASE_URL')) {
      html = html.replace(
        /<script>/i,
        `<script>\n    const SUPABASE_URL = '${safeUrl}';\n    const SUPABASE_ANON_KEY = '${safeKey}';\n    const RESTAURANT_ID = ${safeId};\n    const HEADERS = { 'apikey': SUPABASE_ANON_KEY, 'Authorization': 'Bearer ' + SUPABASE_ANON_KEY };\n`
      )
    }

    return new Response(JSON.stringify({ html }), {
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
