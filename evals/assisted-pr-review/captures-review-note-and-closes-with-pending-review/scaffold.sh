#!/usr/bin/env bash
# Builds a local repo with base branch "main" and PR branch "pr-142" (webhook idempotency fix).
set -euo pipefail
git init -q -b main . && git config user.email eval@example.com && git config user.name eval
mkdir -p src test
cat > src/WebhookService.ts <<'EOF'
import { EventBus } from "./EventBus";

export class WebhookService {
  constructor(private readonly bus: EventBus) {}

  async handle(eventId: string, payload: unknown): Promise<void> {
    await this.bus.publishEvent(eventId, payload);
  }
}
EOF
cat > src/WebhookController.ts <<'EOF'
import { WebhookService } from "./WebhookService";

export class WebhookController {
  constructor(private readonly service: WebhookService) {}

  async post(req: { headers: Record<string, string>; body: unknown }) {
    await this.service.handle(req.headers["x-event-id"], req.body);
    return { status: 202 };
  }
}
EOF
cat > src/EventBus.ts <<'EOF'
export interface EventBus {
  publishEvent(eventId: string, payload: unknown): Promise<void>;
}
EOF
cat > src/Redis.ts <<'EOF'
export interface Redis {
  set(key: string, value: string, mode: "NX", expiry: "EX", seconds: number): Promise<"OK" | null>;
}
EOF
cat > test/FakeRedis.ts <<'EOF'
import { Redis } from "../src/Redis";

// In-memory Redis stand-in that honors NX (set only if absent). Expiry is not simulated.
export class FakeRedis implements Redis {
  private readonly keys = new Set<string>();

  async set(key: string): Promise<"OK" | null> {
    if (this.keys.has(key)) {
      return null;
    }
    this.keys.add(key);
    return "OK";
  }
}
EOF
git add -A && git commit -qm "base"
git checkout -qb pr-142
cat > src/IdempotencyStore.ts <<'EOF'
import { Redis } from "./Redis";

export class IdempotencyStore {
  constructor(private readonly redis: Redis) {}

  async claimKey(key: string, ttlSeconds = 86400): Promise<boolean> {
    const result = await this.redis.set(key, "1", "NX", "EX", ttlSeconds);
    return result === "OK";
  }
}
EOF
cat > src/WebhookService.ts <<'EOF'
import { EventBus } from "./EventBus";
import { IdempotencyStore } from "./IdempotencyStore";

export class WebhookService {
  constructor(
    private readonly bus: EventBus,
    private readonly store: IdempotencyStore,
  ) {}

  async handle(eventId: string, payload: unknown): Promise<"published" | "duplicate"> {
    const claimed = await this.store.claimKey(`webhook:${eventId}`);
    if (!claimed) {
      return "duplicate";
    }
    await this.bus.publishEvent(eventId, payload);
    return "published";
  }
}
EOF
cat > src/WebhookController.ts <<'EOF'
import { WebhookService } from "./WebhookService";

export class WebhookController {
  constructor(private readonly service: WebhookService) {}

  async post(req: { headers: Record<string, string>; body: unknown }) {
    const result = await this.service.handle(req.headers["x-event-id"], req.body);
    return { status: result === "duplicate" ? 200 : 202 };
  }
}
EOF
cat > test/WebhookService.test.ts <<'EOF'
import { IdempotencyStore } from "../src/IdempotencyStore";
import { FakeRedis } from "./FakeRedis";

test("second claim of the same key returns false", async () => {
  const store = new IdempotencyStore(new FakeRedis());
  expect(await store.claimKey("webhook:evt_1")).toBe(true);
  expect(await store.claimKey("webhook:evt_1")).toBe(false);
});
EOF
git add -A && git commit -qm "Fix duplicate webhook delivery with idempotency key check (#142)"
