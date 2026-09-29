export function createHandler(secret: string, run: () => Promise<unknown>) {
  return async (request: Request): Promise<Response> => {
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }
    const supplied = request.headers.get("x-catalog-secret") ?? "";
    const digest = async (s: string) =>
      new Uint8Array(
        await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)),
      );
    const [expected, actual] = await Promise.all([
      digest(secret),
      digest(supplied),
    ]);
    let difference = 0;
    for (let i = 0; i < expected.length; i++) {
      difference |= expected[i] ^ actual[i];
    }
    if (secret.length < 32 || difference !== 0) {
      return new Response("Unauthorized", { status: 401 });
    }
    try {
      return Response.json(await run());
    } catch (error) {
      console.error(
        "Catalog refresh failed:",
        error instanceof Error ? error.message : "unknown error",
      );
      return Response.json({
        error: "Catalog refresh failed. See run log and published revision.",
      }, { status: 500 });
    }
  };
}
