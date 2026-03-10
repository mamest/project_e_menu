/**
 * stripe-webhook Edge Function
 *
 * Listens for Stripe subscription events and keeps the `profiles` table in sync.
 *
 * Required environment variables:
 *   STRIPE_SECRET_KEY        – your Stripe secret key
 *   STRIPE_WEBHOOK_SECRET    – from Stripe Dashboard → Webhooks → signing secret
 *
 * Events to enable in the Stripe Dashboard:
 *   customer.subscription.created
 *   customer.subscription.updated
 *   customer.subscription.deleted
 *   invoice.payment_succeeded
 *   invoice.payment_failed
 *
 * Deploy:  supabase functions deploy stripe-webhook
 */

// deno-lint-ignore-file no-explicit-any
export {}

import Stripe from "stripe";
import { createClient } from "@supabase/supabase-js";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2023-10-16",
});

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
);

Deno.serve(async (req) => {
  const signature = req.headers.get("stripe-signature");
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");

  if (!signature || !webhookSecret) {
    return new Response("Missing stripe-signature or webhook secret", {
      status: 400,
    });
  }

  const body = await req.text();

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      webhookSecret
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return new Response(`Webhook Error: ${String(err)}`, { status: 400 });
  }

  const sub = (event.data.object as Stripe.Subscription);

  switch (event.type) {
    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const customerId =
        typeof sub.customer === "string" ? sub.customer : sub.customer.id;

      await supabase
        .from("profiles")
        .update({
          role: "restaurant_owner",
          subscription_id: sub.id,
          subscription_status: sub.status,
          subscription_current_period_end: new Date(
            sub.current_period_end * 1000
          ).toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("stripe_customer_id", customerId);
      break;
    }

    case "customer.subscription.deleted": {
      const customerId =
        typeof sub.customer === "string" ? sub.customer : sub.customer.id;

      await supabase
        .from("profiles")
        .update({
          subscription_status: "canceled",
          updated_at: new Date().toISOString(),
        })
        .eq("stripe_customer_id", customerId);
      break;
    }

    case "invoice.payment_failed": {
      const invoice = event.data.object as Stripe.Invoice;
      const customerId =
        typeof invoice.customer === "string"
          ? invoice.customer
          : invoice.customer?.id;

      if (customerId) {
        await supabase
          .from("profiles")
          .update({
            subscription_status: "past_due",
            updated_at: new Date().toISOString(),
          })
          .eq("stripe_customer_id", customerId);
      }
      break;
    }

    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
