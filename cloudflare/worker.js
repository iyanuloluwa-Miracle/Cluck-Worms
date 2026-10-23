/**
 * Cluck & Worms web host for Lagos Life / Cloudflare.
 * - Serves Brotli-precompressed index.wasm under the 25 MiB upload limit
 * - Allows framing by Lagos Life / Vatar worlds
 * - Verifies IAP claims with the Vatar Games API (VATAR_SECRET)
 */

const VATAR_API = "https://lagoslife.app/api/games/v1";
const FRAME_ANCESTORS =
	"frame-ancestors https://lagoslife.app https://www.lagoslife.app https://naijalife.app https://www.naijalife.app https://lagoslife.eliysites.com";

export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		if (request.method === "OPTIONS" && url.pathname === "/claim") {
			return new Response(null, { status: 204, headers: corsHeaders(request) });
		}

		if (request.method === "POST" && url.pathname === "/claim") {
			return handleClaim(request, env);
		}

		let path = url.pathname;
		if (path === "/" || path === "") {
			url.pathname = "/index.html";
			request = new Request(url.toString(), request);
			path = "/index.html";
		}

		const isWasm = path === "/index.wasm" || path.endsWith("/index.wasm");
		const assetResponse = await env.ASSETS.fetch(request);
		if (!assetResponse.ok) {
			return withSecurityHeaders(assetResponse);
		}

		if (isWasm) {
			const headers = new Headers(assetResponse.headers);
			headers.set("Content-Type", "application/wasm");
			headers.set("Content-Encoding", "br");
			headers.set("Cache-Control", "public, max-age=3600");
			headers.set("Content-Security-Policy", FRAME_ANCESTORS);
			return new Response(assetResponse.body, {
				status: assetResponse.status,
				statusText: assetResponse.statusText,
				headers,
				encodeBody: "manual",
			});
		}

		if (path === "/index.html" || path === "/index.pck") {
			const headers = new Headers(assetResponse.headers);
			headers.set("Cache-Control", "no-cache, must-revalidate");
			headers.set("Content-Security-Policy", FRAME_ANCESTORS);
			return new Response(assetResponse.body, {
				status: assetResponse.status,
				statusText: assetResponse.statusText,
				headers,
			});
		}

		return withSecurityHeaders(assetResponse);
	},
};

function withSecurityHeaders(response) {
	const headers = new Headers(response.headers);
	headers.set("Content-Security-Policy", FRAME_ANCESTORS);
	// Do not send X-Frame-Options — it would block Lagos Life's iframe.
	headers.delete("X-Frame-Options");
	return new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers,
	});
}

function corsHeaders(request) {
	const origin = request.headers.get("Origin") || "*";
	return {
		"Access-Control-Allow-Origin": origin,
		"Access-Control-Allow-Methods": "POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type",
		"Content-Security-Policy": FRAME_ANCESTORS,
	};
}

async function handleClaim(request, env) {
	const headers = {
		...corsHeaders(request),
		"Content-Type": "application/json",
	};
	const secret = env.VATAR_SECRET;
	if (!secret) {
		return new Response(JSON.stringify({ error: "server_misconfigured" }), {
			status: 500,
			headers,
		});
	}

	let body;
	try {
		body = await request.json();
	} catch {
		return new Response(JSON.stringify({ error: "bad_request" }), { status: 400, headers });
	}

	const session = body && body.session;
	const purchaseId = body && body.purchaseId;
	if (!session || !purchaseId) {
		return new Response(JSON.stringify({ error: "bad_request" }), { status: 400, headers });
	}

	const me = await vatar(secret, "/session/verify", { session });
	if (!me.ok) {
		return new Response(JSON.stringify({ error: me.error || "forbidden" }), {
			status: me.http || 403,
			headers,
		});
	}

	const purchase = await vatar(secret, `/purchases/${encodeURIComponent(purchaseId)}`);
	if (!purchase.ok) {
		return new Response(JSON.stringify({ error: purchase.error || "not_found" }), {
			status: purchase.http || 404,
			headers,
		});
	}

	if (purchase.playerId !== me.playerId) {
		return new Response(JSON.stringify({ error: "forbidden" }), { status: 403, headers });
	}
	if (purchase.status === "refunded") {
		return new Response(JSON.stringify({ error: "refunded" }), { status: 409, headers });
	}

	if (purchase.status === "paid") {
		const delivered = await vatar(
			secret,
			`/purchases/${encodeURIComponent(purchaseId)}/deliver`,
			{}
		);
		if (!delivered.ok && delivered.http !== 200) {
			return new Response(JSON.stringify({ error: delivered.error || "deliver_failed" }), {
				status: delivered.http || 500,
				headers,
			});
		}
	}

	return new Response(
		JSON.stringify({
			ok: true,
			purchaseId,
			productId: purchase.productId,
			playerId: purchase.playerId,
		}),
		{ status: 200, headers }
	);
}

async function vatar(secret, path, body) {
	const r = await fetch(VATAR_API + path, {
		method: body !== undefined ? "POST" : "GET",
		headers: {
			Authorization: `Bearer ${secret}`,
			"Content-Type": "application/json",
		},
		body: body !== undefined ? JSON.stringify(body) : undefined,
	});
	const json = await r.json().catch(() => ({}));
	return { ok: r.ok, http: r.status, error: json.error, ...json };
}
