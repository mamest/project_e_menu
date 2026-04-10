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
  restaurantId: number
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
    const { restaurant, restaurantId } = body

    // Supabase injects these automatically into every edge function.
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

    // Ask Claude ONLY for a CSS <style> block (~50 lines).
    // The complete HTML template and ALL JavaScript logic is assembled below in
    // buildMenuHtml() — Claude no longer writes any JS, preventing truncation.
    const cssPrompt = `Generate a CSS <style>...</style> block for a restaurant menu webpage.

Restaurant: ${restaurant.name}
Cuisine: ${restaurant.cuisine_type || 'General'}${restaurant.description ? '\nDescription: ' + restaurant.description : ''}

Use EXACTLY these class/id selectors (do not rename or add new selectors):
body, #loading, #content,
.banner (hero header 220px tall; display:flex; align-items:flex-end; solid cuisine background-color fallback; background-size:cover when image set via inline style),
.banner-overlay (text container inside banner; padding 1.5rem; dark gradient or semi-opaque background),
.restaurant-name (h1 in banner; large; light color),
.restaurant-tagline (p subtitle in banner; muted light color),
.restaurant-info (address/phone/email bar; flex; flex-wrap:wrap; gap:1.5rem; padding:.8rem 2rem; contrasting background),
.info-section (opening hours + payments grid; 2 cols desktop / 1 col mobile; padding:1.5rem 2rem; cuisine-tinted background; border-top+bottom),
.hours-block, .payments-block (grid columns),
.info-section h3 (section headings; cuisine accent color; text-transform:uppercase; font-size:.95rem),
.hours-list (ul; list-style:none; padding:0), .hours-list li (display:flex; justify-content:space-between; padding:.3rem 0; border-bottom:1px dotted #ccc),
.day (day name span), .hours (hours value span),
.payment-tags (display:flex; flex-wrap:wrap; gap:.5rem; margin-top:.5rem), .payment-tag (pill chip; cuisine accent background; color:white; padding:.3rem .8rem; border-radius:1rem; font-size:.85rem),
.delivery-badge (display:inline-flex; align-items:center; gap:.4rem; background:green-ish; color:white; padding:.4rem 1rem; border-radius:1rem; margin-top:.75rem; font-size:.9rem),
.menu-categories (padding:1.5rem 2rem),
.category (margin-bottom:2.5rem),
.category-name (h2; cuisine accent color; border-left or border-bottom accent; padding-left or padding-bottom; letter-spacing),
.menu-item (display:flex; align-items:flex-start; padding:.6rem 0; border-bottom:1px solid #eee),
.item-main (flex:1; min-width:0),
.item-number (font-size:.75rem; color:#999; font-style:italic; margin-right:.35rem),
.item-name (font-weight:bold; font-size:1rem),
.item-description (display:block; font-style:italic; font-size:.88rem; color:#666; margin-top:.2rem),
.item-price (font-weight:bold; white-space:nowrap; padding-left:1.2rem; cuisine accent color; font-size:1rem),
.item-variants (width:100%; padding-left:1.2rem; margin-top:.5rem),
.variant (display:flex; justify-content:space-between; padding:.2rem 0; font-size:.93rem),
.variant-name (font-style:italic; color:#555), .variant-price (font-weight:bold; cuisine accent color),
.menu-footer (text-align:center; color:#aaa; padding:2rem; font-size:.85rem; border-top:1px solid #eee)

Design a professional, elegant look matching the cuisine type. System fonts only (Georgia, Arial, sans-serif). No external resources.
Max 60 CSS rules. Include @media print (page-break-inside:avoid on .category) and @media (max-width:600px).
Return ONLY the <style>...</style> block. No other HTML, no explanations.`

    // ── Claude is now asked only for CSS; the HTML+JS template is in buildMenuHtml() below ──

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-opus-4-5',
        max_tokens: 2048,
        messages: [{ role: 'user', content: cssPrompt }],
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

    let styleBlock = data.content?.find((b) => b.type === 'text')?.text ?? ''
    styleBlock = styleBlock.trim()
    styleBlock = styleBlock.replace(/^```[a-z]*\n?/i, '').replace(/\n?```\s*$/,'').trim()
    if (!styleBlock.startsWith('<style')) {
      styleBlock = '<style>\n' + styleBlock + '\n</style>'
    }
    // Escape backticks so the style block is safe inside a TypeScript template literal
    styleBlock = styleBlock.replace(/`/g, "'")

    const safeTitle = (restaurant.name ?? 'Menu').replace(/&/g, '&amp;').replace(/</g, '&lt;')
    const safeUrl = (supabaseUrl ?? '').replace(/\\/g, '\\\\').replace(/'/g, "\\'")
    const safeKey = (supabaseAnonKey ?? '').replace(/\\/g, '\\\\').replace(/'/g, "\\'")
    const safeId = String(restaurantId ?? '0')

    const html = buildMenuHtml(safeTitle, styleBlock, safeUrl, safeKey, safeId)

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

function buildMenuHtml(
  title: string,
  styleBlock: string,
  supabaseUrl: string,
  supabaseAnonKey: string,
  restaurantId: string,
): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title} - Menu</title>
  ${styleBlock}
</head>
<body>
  <div id="loading"></div>
  <div id="content">
    <div id="menu-header"></div>
    <div id="menu-categories"></div>
  </div>
  <script>
    var T = {
      en: { loading: 'Loading menu\u2026', loadError: 'Error loading menu. Please refresh.', openingHours: 'Opening Hours', paymentMethods: 'Payment Methods', delivery: 'Delivery available', priceOnRequest: 'Price on request', closed: 'Closed', monday: 'Monday', tuesday: 'Tuesday', wednesday: 'Wednesday', thursday: 'Thursday', friday: 'Friday', saturday: 'Saturday', sunday: 'Sunday' },
      de: { loading: 'Speisekarte wird geladen\u2026', loadError: 'Fehler beim Laden. Bitte neu laden.', openingHours: '\u00d6ffnungszeiten', paymentMethods: 'Zahlungsmethoden', delivery: 'Lieferung verf\u00fcgbar', priceOnRequest: 'Preis auf Anfrage', closed: 'Geschlossen', monday: 'Montag', tuesday: 'Dienstag', wednesday: 'Mittwoch', thursday: 'Donnerstag', friday: 'Freitag', saturday: 'Samstag', sunday: 'Sonntag' },
      fr: { loading: 'Chargement du menu\u2026', loadError: 'Erreur de chargement. Veuillez actualiser.', openingHours: "Heures d'ouverture", paymentMethods: 'Modes de paiement', delivery: 'Livraison disponible', priceOnRequest: 'Prix sur demande', closed: 'Ferm\u00e9', monday: 'Lundi', tuesday: 'Mardi', wednesday: 'Mercredi', thursday: 'Jeudi', friday: 'Vendredi', saturday: 'Samedi', sunday: 'Dimanche' },
      es: { loading: 'Cargando men\u00fa\u2026', loadError: 'Error al cargar. Por favor recargue.', openingHours: 'Horario', paymentMethods: 'M\u00e9todos de pago', delivery: 'Entrega disponible', priceOnRequest: 'Precio a consultar', closed: 'Cerrado', monday: 'Lunes', tuesday: 'Martes', wednesday: 'Mi\u00e9rcoles', thursday: 'Jueves', friday: 'Viernes', saturday: 'S\u00e1bado', sunday: 'Domingo' },
      it: { loading: 'Caricamento menu\u2026', loadError: 'Errore di caricamento. Aggiorna la pagina.', openingHours: 'Orari', paymentMethods: 'Pagamento', delivery: 'Consegna disponibile', priceOnRequest: 'Prezzo su richiesta', closed: 'Chiuso', monday: 'Luned\u00ec', tuesday: 'Marted\u00ec', wednesday: 'Mercoled\u00ec', thursday: 'Gioved\u00ec', friday: 'Venerd\u00ec', saturday: 'Sabato', sunday: 'Domenica' },
      nl: { loading: 'Menu wordt geladen\u2026', loadError: 'Fout bij laden. Ververs de pagina.', openingHours: 'Openingstijden', paymentMethods: 'Betaalmethoden', delivery: 'Bezorging beschikbaar', priceOnRequest: 'Prijs op aanvraag', closed: 'Gesloten', monday: 'Maandag', tuesday: 'Dinsdag', wednesday: 'Woensdag', thursday: 'Donderdag', friday: 'Vrijdag', saturday: 'Zaterdag', sunday: 'Zondag' },
      tr: { loading: 'Men\u00fc y\u00fckleniyor\u2026', loadError: 'Y\u00fckleme hatas\u0131. L\u00fctfen yenileyin.', openingHours: '\u00c7al\u0131\u015fma Saatleri', paymentMethods: '\u00d6deme Y\u00f6ntemleri', delivery: 'Teslimat mevcut', priceOnRequest: 'Fiyat talep \u00fczerine', closed: 'Kapal\u0131', monday: 'Pazartesi', tuesday: 'Sal\u0131', wednesday: '\u00c7ar\u015famba', thursday: 'Per\u015fembe', friday: 'Cuma', saturday: 'Cumartesi', sunday: 'Pazar' }
    };
    var lang = (navigator.language || 'en').slice(0, 2).toLowerCase();
    var t = T[lang] || T['en'];
    function loc(o, f) { return (o.translations && o.translations[lang] && o.translations[lang][f]) || o[f]; }
    function esc(s) { if (!s) return ''; return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
    var SUPABASE_URL = '${supabaseUrl}';
    var SUPABASE_ANON_KEY = '${supabaseAnonKey}';
    var RESTAURANT_ID = ${restaurantId};
    var HEADERS = { 'apikey': SUPABASE_ANON_KEY, 'Authorization': 'Bearer ' + SUPABASE_ANON_KEY };
    function loadMenu() {
      var le = document.getElementById('loading'), ce = document.getElementById('content');
      if (le) { le.style.display = 'flex'; le.textContent = t.loading; }
      if (ce) ce.style.display = 'none';
      Promise.all([
        fetch(SUPABASE_URL + '/rest/v1/restaurants?id=eq.' + RESTAURANT_ID + '&select=*', { headers: HEADERS }),
        fetch(SUPABASE_URL + '/rest/v1/categories?restaurant_id=eq.' + RESTAURANT_ID + '&select=id,name,display_order,translations,items(id,name,item_number,price,description,available,has_variants,translations,item_variants(id,name,price,display_order))&order=display_order', { headers: HEADERS })
      ]).then(function(res) {
        if (!res[0].ok || !res[1].ok) { return (res[res[0].ok ? 1 : 0]).text().then(function(e) { throw new Error('API: ' + e); }); }
        return Promise.all([res[0].json(), res[1].json()]);
      }).then(function(data) {
        var restaurant = data[0][0];
        var categories = data[1].map(function(c) {
          return Object.assign({}, c, { name: loc(c, 'name'), items: (c.items || []).map(function(i) { return Object.assign({}, i, { name: loc(i, 'name'), description: loc(i, 'description') }); }) });
        });
        if (le) le.style.display = 'none';
        if (ce) ce.style.display = 'block';
        renderMenu(restaurant, categories);
      }).catch(function(e) {
        if (le) { le.style.display = 'flex'; le.style.color = 'red'; le.textContent = t.loadError + ' (' + e.message + ')'; }
      });
    }
    function renderMenu(r, cats) {
      var he = document.getElementById('menu-header'), catEl = document.getElementById('menu-categories');
      var h = '';
      var bStyle = r.image_url ? 'background-image:url(' + esc(r.image_url) + ')' : '';
      h += '<div class="banner" style="' + bStyle + '"><div class="banner-overlay">';
      h += '<h1 class="restaurant-name">' + esc(r.name) + '</h1>';
      if (r.description) h += '<p class="restaurant-tagline">' + esc(r.description) + '</p>';
      h += '</div></div>';
      h += '<div class="restaurant-info">';
      if (r.address) h += '<span>' + esc(r.address) + '</span>';
      if (r.phone) h += '<span>' + esc(r.phone) + '</span>';
      if (r.email) h += '<span>' + esc(r.email) + '</span>';
      h += '</div>';
      var hasH = r.opening_hours && Object.keys(r.opening_hours).length > 0;
      var hasP = r.payment_methods && r.payment_methods.length > 0;
      if (hasH || hasP) {
        h += '<div class="info-section">';
        if (hasH) {
          h += '<div class="hours-block"><h3>' + t.openingHours + '</h3><ul class="hours-list">';
          ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'].forEach(function(d) {
            var v = r.opening_hours[d];
            h += '<li><span class="day">' + (t[d] || d) + '</span><span class="hours">' + esc(v || t.closed) + '</span></li>';
          });
          h += '</ul></div>';
        }
        if (hasP) {
          h += '<div class="payments-block"><h3>' + t.paymentMethods + '</h3><div class="payment-tags">';
          r.payment_methods.forEach(function(m) { h += '<span class="payment-tag">' + esc(m) + '</span>'; });
          h += '</div>';
          if (r.delivers) h += '<div class="delivery-badge">' + t.delivery + '</div>';
          h += '</div>';
        }
        h += '</div>';
      }
      he.innerHTML = h;
      var c = '';
      cats.forEach(function(cat) {
        var items = (cat.items || []).filter(function(i) { return i.available !== false; });
        if (!items.length) return;
        items.sort(function(a, b) { return (a.display_order || 0) - (b.display_order || 0); });
        c += '<div class="category"><h2 class="category-name">' + esc(cat.name) + '</h2>';
        items.forEach(function(item) {
          c += '<div class="menu-item"><div class="item-main"><div class="item-name">';
          if (item.item_number) c += '<span class="item-number">' + esc(item.item_number) + '</span> ';
          c += esc(item.name) + '</div>';
          if (item.description) c += '<span class="item-description">' + esc(item.description) + '</span>';
          c += '</div>';
          if (item.has_variants && item.item_variants && item.item_variants.length) {
            var vs = item.item_variants.slice().sort(function(a,b){return(a.display_order||0)-(b.display_order||0);});
            c += '<div class="item-variants">';
            vs.forEach(function(v) {
              var vp = v.price != null ? '\u20ac' + parseFloat(v.price).toFixed(2) : t.priceOnRequest;
              c += '<div class="variant"><span class="variant-name">' + esc(v.name) + '</span><span class="variant-price">' + vp + '</span></div>';
            });
            c += '</div>';
          } else if (item.price != null) {
            c += '<div class="item-price">\u20ac' + parseFloat(item.price).toFixed(2) + '</div>';
          } else {
            c += '<div class="item-price">' + t.priceOnRequest + '</div>';
          }
          c += '</div>';
        });
        c += '</div>';
      });
      c += '<div class="menu-footer"><p>' + esc(r.name) + '</p></div>';
      catEl.innerHTML = c;
    }
    loadMenu();
  </script>
</body>
</html>`
}
