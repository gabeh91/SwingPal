/** Bound response memory, redirects and runtime for both vendor and storage requests. */
export async function requestJSON(
  url: string,
  options: RequestInit = {},
  maxBytes = 2_000_000,
): Promise<unknown> {
  const response = await fetch(url, {
    ...options,
    redirect: "error",
    signal: options.signal ?? AbortSignal.timeout(15_000),
  });
  if (!response.ok) {
    await response.body?.cancel();
    throw new Error(
      `Upstream HTTP ${response.status} (${new URL(url).pathname})`,
    );
  }
  const chunks: Uint8Array[] = [];
  let length = 0;
  if (response.body) {
    for await (const chunk of response.body) {
      length += chunk.length;
      if (length > maxBytes) throw new Error("Upstream JSON too large");
      chunks.push(chunk);
    }
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return length ? JSON.parse(new TextDecoder().decode(bytes)) : null;
}
