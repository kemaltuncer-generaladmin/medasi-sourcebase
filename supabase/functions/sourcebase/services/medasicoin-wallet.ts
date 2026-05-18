import { SafeError } from "../types.ts";
import { formatMc, McPricingQuote } from "./medasicoin-pricing.ts";

export interface WalletConfig {
  supabaseUrl: string;
  serviceRoleKey: string;
}

export interface WalletBalance {
  balance_units: number;
  balance_mc: number;
}

export async function getWalletBalance(
  config: WalletConfig,
  userId: string,
): Promise<WalletBalance> {
  const rows: Array<Record<string, unknown>> = await walletSelect(
    config,
    `wallet_transactions?user_id=eq.${userId}&select=amount_units`,
  );
  const balanceUnits = rows.reduce(
    (sum: number, row: Record<string, unknown>) =>
      sum + Number(row.amount_units ?? 0),
    0,
  );
  return {
    balance_units: balanceUnits,
    balance_mc: balanceUnits / 100,
  };
}

export async function reserveMedasiCoin(input: {
  config: WalletConfig;
  userId: string;
  jobId?: string;
  quote: McPricingQuote;
  reason: string;
}) {
  const before = await getWalletBalance(input.config, input.userId);
  if (before.balance_units < input.quote.amount_units) {
    throw new SafeError(
      "INSUFFICIENT_MC",
      `Yetersiz MedasiCoin bakiyesi. Gerekli: ${
        formatMc(input.quote.amount_units)
      } MC.`,
      402,
    );
  }
  const afterUnits = before.balance_units - input.quote.amount_units;
  await walletInsert(input.config, {
    user_id: input.userId,
    job_id: input.jobId,
    amount_mc: -(input.quote.amount_units / 100),
    amount_units: -input.quote.amount_units,
    type: "reserve",
    reason: input.reason,
    balance_before: before.balance_units / 100,
    balance_after: afterUnits / 100,
    metadata: { pricing: input.quote },
  });
  return {
    balance_before: before.balance_mc,
    balance_after_reserve: afterUnits / 100,
    reserved_mc: input.quote.amount_units / 100,
  };
}

export async function captureMedasiCoin(input: {
  config: WalletConfig;
  userId: string;
  jobId?: string;
  reason: string;
  metadata?: Record<string, unknown>;
}) {
  const balance = await getWalletBalance(input.config, input.userId);
  await walletInsert(input.config, {
    user_id: input.userId,
    job_id: input.jobId,
    amount_mc: 0,
    amount_units: 0,
    type: "capture",
    reason: input.reason,
    balance_before: balance.balance_mc,
    balance_after: balance.balance_mc,
    metadata: input.metadata ?? {},
  });
}

export async function refundMedasiCoin(input: {
  config: WalletConfig;
  userId: string;
  jobId?: string;
  amountUnits: number;
  reason: string;
  metadata?: Record<string, unknown>;
}) {
  if (input.amountUnits <= 0) return;
  const before = await getWalletBalance(input.config, input.userId);
  const afterUnits = before.balance_units + input.amountUnits;
  await walletInsert(input.config, {
    user_id: input.userId,
    job_id: input.jobId,
    amount_mc: input.amountUnits / 100,
    amount_units: input.amountUnits,
    type: "refund",
    reason: input.reason,
    balance_before: before.balance_mc,
    balance_after: afterUnits / 100,
    metadata: input.metadata ?? {},
  });
}

async function walletSelect(config: WalletConfig, path: string) {
  const response = await walletFetch(config, path);
  return await response.json();
}

async function walletInsert(
  config: WalletConfig,
  body: Record<string, unknown>,
) {
  await walletFetch(config, "wallet_transactions", {
    method: "POST",
    headers: { prefer: "return=minimal" },
    body: JSON.stringify(body),
  });
}

async function walletFetch(
  config: WalletConfig,
  path: string,
  init: RequestInit = {},
) {
  const response = await fetch(`${config.supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: config.serviceRoleKey,
      authorization: `Bearer ${config.serviceRoleKey}`,
      "content-type": "application/json",
      "accept-profile": "sourcebase",
      "content-profile": "sourcebase",
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    console.error("Wallet operation failed:", response.status);
    throw new SafeError(
      "WALLET_ERROR",
      "MedasiCoin işlemi tamamlanamadı.",
      500,
    );
  }
  return response;
}
