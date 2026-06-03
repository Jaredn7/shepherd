/** Returns true when clientVersion >= minVersion (semver, numeric segments). */
export function isVersionCompatible(
  clientVersion: string,
  minVersion: string,
): boolean {
  const client = parseVersion(clientVersion);
  const min = parseVersion(minVersion);
  for (let i = 0; i < 3; i++) {
    if (client[i] > min[i]) return true;
    if (client[i] < min[i]) return false;
  }
  return true;
}

function parseVersion(version: string): [number, number, number] {
  const parts = version.split(".").map((p) => parseInt(p, 10) || 0);
  return [parts[0] ?? 0, parts[1] ?? 0, parts[2] ?? 0];
}
